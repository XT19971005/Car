extends Node3D
const Track = preload("res://scripts/track_world.gd")
const Car = preload("res://scripts/arcade_car.gd")
const Session = preload("res://scripts/race_session.gd")
const Interface = preload("res://scripts/race_ui.gd")
const Audio = preload("res://scripts/engine_audio.gd")
const Catalog = preload("res://scripts/track_catalog.gd")
enum State { MENU, COUNTDOWN, RACING, PAUSED, RESULTS }
var state := State.MENU
var before_pause := State.RACING
var tracks: Dictionary
var track: Node3D
var car: CharacterBody3D
var ui: CanvasLayer
var audio: AudioStreamPlayer
var camera: Camera3D
var session := Session.new()
var selected_track := "monza"
var countdown := 3.0
var go_timer := 0.0
var camera_mode := 0
var camera_yaw := 0.0
var orbit := 0.0
var mouse_drag := false
var offroad_time := 0.0
var message := ""
var message_time := 0.0
var last_sample: Dictionary
var records: Dictionary = {}
var volume := 0.7
var fullscreen := false
var preferences := ConfigFile.new()
var test_mode := false
var record_this_race := false
var gate_marker: Node3D

func _ready() -> void:
	test_mode = "--test-mode" in OS.get_cmdline_user_args()
	tracks = Catalog.new().TRACKS
	_load_preferences()
	_configure_input()
	_build_environment()
	car = Car.new()
	add_child(car)
	camera = Camera3D.new()
	camera.fov = 65
	camera.near = 0.08
	camera.far = 3500
	add_child(camera)
	camera.current = true
	ui = Interface.new()
	add_child(ui)
	ui.populate_tracks(tracks)
	ui.start_requested.connect(start_race)
	ui.restart_requested.connect(start_race)
	ui.track_selected.connect(select_track)
	ui.pause_requested.connect(pause_race)
	ui.resume_requested.connect(resume_race)
	ui.menu_requested.connect(show_menu)
	ui.camera_requested.connect(switch_camera)
	ui.volume_changed.connect(_set_volume)
	ui.fullscreen_changed.connect(_set_fullscreen)
	ui.volume_slider.set_value_no_signal(volume)
	ui.fullscreen_toggle.set_pressed_no_signal(fullscreen)
	_set_volume(volume)
	_set_fullscreen(fullscreen)
	audio = Audio.new()
	add_child(audio)
	select_track(selected_track)
	show_menu()
	get_tree().auto_accept_quit = false

func _configure_input() -> void:
	var keys := {"accelerate": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "handbrake": [KEY_SPACE], "reset_car": [KEY_R], "camera": [KEY_C], "pause_race": [KEY_ESCAPE]}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.15)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for binding in [["accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0], ["brake", JOY_AXIS_TRIGGER_LEFT, 1.0], ["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis = binding[1]
		event.axis_value = binding[2]
		InputMap.action_add_event(binding[0], event)
	for binding in [["handbrake", JOY_BUTTON_A], ["camera", JOY_BUTTON_Y], ["reset_car", JOY_BUTTON_BACK], ["pause_race", JOY_BUTTON_START]]:
		var event := InputEventJoypadButton.new()
		event.button_index = binding[1]
		InputMap.action_add_event(binding[0], event)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("526b78")
	sky_material.sky_horizon_color = Color("d2bca1")
	sky_material.ground_horizon_color = Color("a1afa3")
	sky_material.ground_bottom_color = Color("354f4b")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a5bdc2")
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color("a6b6ae")
	environment.fog_density = 0.0008
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-26, -32, 0)
	sun.light_color = Color("f3cca0")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	add_child(sun)

func select_track(key: String) -> void:
	if not tracks.has(key):
		return
	selected_track = key
	if track:
		remove_child(track)
		track.queue_free()
	track = Track.new()
	add_child(track)
	track.build(tracks[key].points)
	_build_gate_marker()
	car.reset_at(track.points[0], track.tangent(0))
	last_sample = track.sample(car.position)
	ui.select_track(key, tracks[key], track, best_time())
	_update_camera(1.0, true)

func best_time() -> float:
	return float(records.get(selected_track, 0.0))

func start_race() -> void:
	session.reset(ui.lap_choice.get_selected_id())
	record_this_race = false
	car.reset_at(track.points[0], track.tangent(0))
	last_sample = track.sample(car.position)
	session.previous_progress = float(last_sample.progress)
	state = State.COUNTDOWN
	countdown = 3.0
	offroad_time = 0.0
	message_time = 0.0
	go_timer = 0.0
	orbit = 0.0
	mouse_drag = false
	ui.show_race()
	ui.countdown_label.text = "3"
	_update_camera(1.0, true)
	_update_hud()

func show_menu() -> void:
	state = State.MENU
	car.velocity = Vector3.ZERO
	audio.active = false
	ui.select_track(selected_track, tracks[selected_track], track, best_time())
	ui.show_menu()
	_save_preferences()

func pause_race() -> void:
	if state != State.RACING and state != State.COUNTDOWN:
		return
	before_pause = state
	state = State.PAUSED
	mouse_drag = false
	audio.active = false
	ui.show_pause()

func resume_race() -> void:
	if state != State.PAUSED:
		return
	state = before_pause
	ui.show_race()

func switch_camera() -> void:
	camera_mode = (camera_mode + 1) % 3
	orbit = 0.0
	_update_camera(1.0, true)

func reset_car() -> void:
	if state != State.RACING:
		return
	# Reset to the last earned gate, never beyond a missed checkpoint.
	var safe_progress := float(session.next_gate - 1) / Session.GATES
	var safe: Dictionary = track.at_progress(safe_progress + 0.0004)
	car.reset_at(safe.point, safe.tangent)
	session.relocate(safe_progress + 0.0004)
	offroad_time = 0.0
	message = "已返回检查点 · 本圈为练习圈"
	message_time = 3.0
	_update_camera(1.0, true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_race"):
		if state == State.PAUSED:
			resume_race()
		else:
			pause_race()
		get_viewport().set_input_as_handled()
	if state != State.RACING and state != State.COUNTDOWN:
		return
	if event.is_action_pressed("camera") and not event.is_echo():
		switch_camera()
	if event.is_action_pressed("reset_car") and not event.is_echo():
		reset_car()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_drag = event.pressed
	if event is InputEventMouseMotion and mouse_drag and camera_mode < 2:
		orbit = clampf(orbit - event.relative.x * 0.004, -1.5, 1.5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause_race()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_preferences()
		get_tree().quit()

func _physics_process(dt: float) -> void:
	if state == State.COUNTDOWN:
		countdown -= dt
		ui.countdown_label.text = str(maxi(1, ceili(countdown)))
		if countdown <= 0:
			state = State.RACING
			go_timer = 0.7
			ui.countdown_label.text = "GO"
	elif state == State.RACING:
		last_sample = track.sample(car.position)
		var offroad: bool = float(last_sample.distance) > Track.HALF_WIDTH + 0.85
		car.drive(dt, Input.get_action_strength("accelerate"), Input.get_action_strength("brake"), Input.get_axis("left", "right"), Input.is_action_pressed("handbrake"), offroad)
		last_sample = track.sample(car.position)
		if float(last_sample.distance) > Track.HALF_WIDTH + 1.7:
			offroad_time += dt
			if offroad_time > 0.7:
				session.valid = false
		else:
			offroad_time = 0.0
		var moving_forward: bool = car.velocity.dot(last_sample.tangent) > 0.1
		var event: String = session.tick(dt, float(last_sample.progress), float(last_sample.distance) <= Track.HALF_WIDTH + 1.0, moving_forward)
		if event == "lap" or event == "finish":
			_save_record()
			message = "完成一圈  " + Session.time_text(session.laps.back().time)
			message_time = 3.0
		if event == "sector":
			message = "分段成绩  " + Session.time_text(session.last_sector)
			message_time = 2.0
		if event == "finish":
			_finish()
		if car.position.y < -15 or float(last_sample.distance) > 100:
			reset_car()
		message_time = maxf(0, message_time - dt)
		go_timer = maxf(0, go_timer - dt)
		if go_timer == 0:
			ui.countdown_label.text = ""
		_update_hud()
	if audio:
		audio.active = state == State.RACING or state == State.COUNTDOWN
		audio.rpm = car.rpm
		audio.throttle = car.throttle
		audio.speed = car.speed
		audio.slip = car.slip

func _save_record() -> void:
	var entry: Dictionary = session.laps.back()
	if entry.valid and (best_time() <= 0 or float(entry.time) < best_time()):
		records[selected_track] = entry.time
		record_this_race = true
		_save_preferences()

func _finish() -> void:
	state = State.RESULTS
	car.velocity = Vector3.ZERO
	audio.active = false
	ui.show_results(session, record_this_race)

func _update_hud() -> void:
	var gate: Dictionary = track.at_progress(float(session.next_gate % Session.GATES) / Session.GATES)
	gate_marker.position = gate.point
	gate_marker.rotation.y = atan2(gate.tangent.x, gate.tangent.z)
	var status := "检查点 %02d / %02d   ·   %.0f m" % [session.next_gate, Session.GATES, car.position.distance_to(gate.point)]
	if car.velocity.dot(last_sample.tangent) < -2:
		status = "逆向行驶 · 请沿赛道方向前进"
	elif float(last_sample.distance) > Track.HALF_WIDTH + 0.85:
		status = "驶离赛道 · 松开油门并回到路面"
	elif not session.valid:
		status = "练习圈 · 下一圈可重新挑战纪录"
	if message_time > 0:
		status = message
	ui.update_hud(car, session, float(last_sample.progress), best_time(), status)

func _process(dt: float) -> void:
	if car and camera and state != State.PAUSED:
		_update_camera(dt)

func _update_camera(dt: float, snap := false) -> void:
	if not mouse_drag:
		orbit = lerpf(orbit, 0, 1 - exp(-dt * 5))
	var blend := 1.0 if snap else 1 - exp(-dt * 10)
	camera_yaw = lerp_angle(camera_yaw, car.heading, blend)
	var basis_yaw := Basis(Vector3.UP, camera_yaw + orbit)
	var offset := Vector3(0, 3.2, -7.5) if camera_mode == 0 else Vector3(0, 5.0, -12.0)
	car.body_visual.visible = true
	if camera_mode == 2:
		camera.position = car.to_global(Vector3(0, 1.08, 1.05))
		camera.look_at(car.to_global(Vector3(0, 1.1, 30.0)))
	else:
		var desired: Vector3 = car.position + basis_yaw * offset
		camera.position = desired if snap else camera.position.lerp(desired, blend)
		camera.look_at(car.position + Vector3.UP * 0.9 + Vector3(sin(camera_yaw), 0, cos(camera_yaw)) * 3.0)
	camera.fov = 65

func _load_preferences() -> void:
	if test_mode:
		return
	if preferences.load("user://driver.cfg") == OK:
		volume = clampf(float(preferences.get_value("settings", "volume", 0.7)), 0, 1)
		fullscreen = bool(preferences.get_value("settings", "fullscreen", false))
		var saved: Variant = preferences.get_value("records", "arcade_v1", {})
		if saved is Dictionary:
			records = saved

func _save_preferences() -> void:
	if test_mode:
		return
	preferences.set_value("settings", "volume", volume)
	preferences.set_value("settings", "fullscreen", fullscreen)
	preferences.set_value("records", "arcade_v1", records)
	var error := preferences.save("user://driver.cfg")
	if error != OK:
		push_warning("Could not save driver preferences: %s" % error_string(error))

func _set_volume(value: float) -> void:
	volume = value
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(0, value <= 0.001)
	_save_preferences()

func _set_fullscreen(value: bool) -> void:
	fullscreen = value
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_preferences()

func _build_gate_marker() -> void:
	gate_marker = Node3D.new()
	track.add_child(gate_marker)
	for side in [-1, 1]:
		var post := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.25, 4, 0.25)
		post.mesh = mesh
		post.material_override = Track.material(Color("ecab65"))
		post.position = Vector3(side * 9, 2, 0)
		gate_marker.add_child(post)
	var flag := Label3D.new()
	flag.text = "检查点"
	flag.font_size = 64
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei"])
	flag.font = font
	flag.pixel_size = 0.025
	flag.position.y = 4
	flag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flag.modulate = Color("ffd19b")
	gate_marker.add_child(flag)
	var gate: Dictionary = track.at_progress(1.0 / Session.GATES)
	gate_marker.position = gate.point
	gate_marker.rotation.y = atan2(gate.tangent.x, gate.tangent.z)
