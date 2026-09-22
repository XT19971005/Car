extends Node3D
const Track = preload("res://scripts/track_world.gd")
const Car = preload("res://scripts/arcade_car.gd")
const Session = preload("res://scripts/race_session.gd")
const Interface = preload("res://scripts/race_ui.gd")
const Audio = preload("res://scripts/engine_audio.gd")
const Catalog = preload("res://scripts/real_track_catalog.gd")
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
var camera_mode := 2
var selected_vehicle := "v8"
var reduced_motion := false
var camera_time := 0.0
var rear_viewport: SubViewport
var rear_camera: Camera3D
var rear_display: TextureRect
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
var front: Control
var showroom: Node3D
var showroom_car: Node3D
var weather: Node
var weather_mode := "clear"

func _ready() -> void:
	test_mode = "--test-mode" in OS.get_cmdline_user_args()
	tracks = Catalog.new().get_tracks()
	_load_preferences()
	_configure_input()
	_build_environment()
	car = Car.new()
	add_child(car)
	car.configure_vehicle(selected_vehicle)
	camera = Camera3D.new()
	camera.fov = 65
	camera.near = 0.025
	camera.far = 3500
	add_child(camera)
	camera.current = true
	ui = $RaceInterface
	ui.populate_tracks(tracks)
	ui.start_requested.connect(start_race)
	ui.weather_selected.connect(_set_weather)
	ui.find_child("WeatherChoice", true, false).select(["clear", "overcast", "rain"].find(weather_mode))
	ui.restart_requested.connect(start_race)
	ui.track_selected.connect(select_track)
	ui.pause_requested.connect(pause_race)
	ui.resume_requested.connect(resume_race)
	ui.menu_requested.connect(show_home)
	ui.camera_requested.connect(switch_camera)
	ui.volume_changed.connect(_set_volume)
	ui.fullscreen_changed.connect(_set_fullscreen)
	ui.vehicle_selected.connect(select_vehicle)
	ui.cockpit_selected.connect(func(enabled: bool): camera_mode = 2 if enabled else 0; _update_camera(1, true))
	ui.reduced_motion_changed.connect(_set_reduced_motion)
	ui.cockpit_choice.set_pressed_no_signal(camera_mode == 2)
	ui.reduced_motion.set_pressed_no_signal(reduced_motion)
	for i in ui.vehicle_choice.item_count:
		if ui.vehicle_choice.get_item_metadata(i) == selected_vehicle:
			ui.vehicle_choice.select(i)
	ui.volume_slider.set_value_no_signal(volume)
	ui.fullscreen_toggle.set_pressed_no_signal(fullscreen)
	_set_volume(volume)
	_set_fullscreen(fullscreen)
	audio = Audio.new()
	add_child(audio)
	_build_rear_view()
	select_track(selected_track)
	_build_front_end()
	show_home()
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
	weather = $Weather
	weather.set_weather(weather_mode)

func select_track(key: String) -> void:
	if not tracks.has(key):
		return
	selected_track = key
	if track:
		remove_child(track)
		track.queue_free()
	track = load("res://scenes/circuits/" + key + ".tscn").instantiate()
	add_child(track)
	_build_gate_marker()
	car.reset_at(track.points[0], track.tangent(0))
	last_sample = track.sample(car.position)
	ui.select_track(key, tracks[key], track, best_time())
	_update_camera(1.0, true)

func _record_key() -> String:
	return selected_track + ":" + selected_vehicle + ":" + weather_mode

func _set_weather(key: String) -> void:
	if key not in ["clear", "overcast", "rain"]: return
	weather_mode = key
	weather.set_weather(key)
	ui.select_track(selected_track, tracks[selected_track], track, best_time())
	_save_preferences()

func best_time() -> float:
	return float(records.get(_record_key(), 0.0))

func select_vehicle(key: String) -> void:
	selected_vehicle = key
	car.configure_vehicle(key)
	car.reset_at(track.points[0], track.tangent(0))
	ui.vehicle_detail.text = "%s  /  %.3f m × %.3f m" % [car.profile.description, car.profile.length, car.profile.width]
	ui.select_track(selected_track, tracks[selected_track], track, best_time())
	_update_camera(1, true)

func _build_rear_view() -> void:
	if DisplayServer.get_name() == "headless":
		return
	rear_viewport = SubViewport.new()
	rear_viewport.size = Vector2i(384, 112)
	rear_viewport.world_3d = get_world_3d()
	rear_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(rear_viewport)
	rear_camera = Camera3D.new()
	rear_camera.fov = 70
	rear_camera.far = 500
	rear_viewport.add_child(rear_camera)
	rear_camera.current = true
	rear_display = TextureRect.new()
	ui.hud.add_child(rear_display)
	rear_display.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	rear_display.offset_left = -192
	rear_display.offset_right = 192
	rear_display.offset_top = 20
	rear_display.offset_bottom = 132
	rear_display.texture = rear_viewport.get_texture()
	rear_display.flip_h = true
	rear_display.mouse_filter = Control.MOUSE_FILTER_IGNORE

func start_race() -> void:
	if front:
		front.hide()
	if showroom:
		showroom.hide()
	track.show()
	if audio:
		audio.play_cue(700, .10)
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
	if front:
		front.hide()
	if showroom:
		showroom.hide()
	track.show()
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
	ui.cockpit_choice.set_pressed_no_signal(camera_mode == 2)
	orbit = 0.0
	_update_camera(1.0, true)

func reset_car() -> void:
	if state != State.RACING:
		return
	var safe: Dictionary = track.sample(car.position)
	car.reset_at(safe.point, safe.tangent)
	session.relocate(float(safe.progress))
	session.next_gate = clampi(floori(float(safe.progress) * Session.GATES) + 1, 1, Session.GATES)
	offroad_time = 0.0
	message = "已返回最近路面 · 本圈为练习圈"
	message_time = 3.0
	_update_camera(1.0, true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_race"):
		if state == State.MENU:
			show_home()
		elif state == State.PAUSED:
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not test_mode:
		pause_race()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_preferences()
		get_tree().quit()

func _physics_process(dt: float) -> void:
	if state == State.COUNTDOWN:
		var previous_count := ceili(countdown)
		countdown -= dt
		if ceili(countdown) != previous_count:
			audio.play_cue(1300 if countdown <= 0 else 700, .22 if countdown <= 0 else .10)
		ui.countdown_label.text = str(maxi(1, ceili(countdown)))
		if countdown <= 0:
			state = State.RACING
			go_timer = 0.7
			ui.countdown_label.text = "GO"
	elif state == State.RACING:
		last_sample = track.sample(car.position)
		var offroad: bool = float(last_sample.distance) > track.half_width + 0.85
		car.surface_wetness = weather.rain_amount
		car.drive(dt, Input.get_action_strength("accelerate"), Input.get_action_strength("brake"), Input.get_axis("left", "right"), Input.is_action_pressed("handbrake"), offroad)
		last_sample = track.sample(car.position)
		if float(last_sample.distance) > track.half_width + 1.7:
			offroad_time += dt
			if offroad_time > 0.7:
				session.valid = false
		else:
			offroad_time = 0.0
		var moving_forward: bool = car.velocity.dot(last_sample.tangent) > 0.1
		var event: String = session.tick(dt, float(last_sample.progress), float(last_sample.distance) <= track.half_width + 1.0, moving_forward)
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
		audio.cylinders = int(car.profile.cylinders)
		audio.engine_type = selected_vehicle
		audio.shift = car.shift_feedback
		audio.impact = car.impact_feedback
		audio.cockpit = camera_mode == 2
		audio.rumble = 1.0 if last_sample and float(last_sample.distance) > track.half_width - .25 else 0.0

func _save_record() -> void:
	var entry: Dictionary = session.laps.back()
	if entry.valid and (best_time() <= 0 or float(entry.time) < best_time()):
		records[_record_key()] = entry.time
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
	elif float(last_sample.distance) > track.half_width + 0.85:
		status = "驶离赛道 · 松开油门并回到路面"
	elif not session.valid:
		status = "练习圈 · 下一圈可重新挑战纪录"
	if message_time > 0:
		status = message
	ui.update_hud(car, session, float(last_sample.progress), best_time(), status)

func _process(dt: float) -> void:
	if weather and camera:
		weather.camera_position = camera.position
		if audio: audio.rain_amount = weather.rain_amount if state in [State.COUNTDOWN, State.RACING] else 0.0
	if car and camera and state != State.PAUSED:
		_update_camera(dt)

func _update_camera(dt: float, snap := false) -> void:
	if front and front.visible:
		showroom_car.rotation.y += dt * .12
		camera.position = Vector3(10007.5, 2.6, 7.5)
		camera.look_at(Vector3(10000.7, .6, 0))
		camera.fov = 48
		if rear_display: rear_display.hide()
		return
	camera_time += dt
	if not mouse_drag:
		orbit = lerpf(orbit, 0, 1 - exp(-dt * 5))
	var blend := 1.0 if snap else 1 - exp(-dt * 10)
	camera_yaw = lerp_angle(camera_yaw, car.heading, blend)
	var basis_yaw := Basis(Vector3.UP, camera_yaw + orbit)
	var offset := Vector3(0, 3.2, -7.5) if camera_mode == 0 else Vector3(0, 5.0, -12.0)
	car.body_visual.visible = true
	if camera_mode == 2:
		camera.position = car.cockpit_anchor.global_position
		var curb := 1.0 if last_sample and float(last_sample.distance) > track.half_width - .25 else .12
		var feedback := 0.0 if reduced_motion else 1.0
		camera.position.y += sin(camera_time * 31) * minf(absf(car.speed) / 60, 1.0) * .009 * curb * feedback
		camera.position += car.global_basis.z * car.acceleration_feedback * .0008 * feedback
		camera.look_at(camera.position + car.body_visual.global_basis.z * 50, Vector3.UP)
		camera.rotation.z += (-car.yaw_rate * .012 + sin(camera_time * 42) * car.impact_feedback * .015) * feedback
		camera.rotation.x += car.shift_feedback * .008 * feedback
	else:
		var desired: Vector3 = car.position + basis_yaw * offset
		var candidate: Vector3 = desired if snap else camera.position.lerp(desired, blend)
		# Keep the chase view on the vehicle side of walls, terrain and bridges.
		var anchor := car.position + Vector3.UP
		var query := PhysicsRayQueryParameters3D.create(anchor, candidate)
		query.exclude = [car.get_rid()]
		var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty():
			candidate = obstruction.position + (anchor - candidate).normalized() * .28
		camera.position = candidate
		camera.look_at(car.position + Vector3.UP * 0.9 + Vector3(sin(camera_yaw), 0, cos(camera_yaw)) * 3.0)
	camera.fov = 72 if camera_mode == 2 else 65 + minf(absf(car.speed) * .065, 5.0)
	if rear_camera:
		rear_display.visible = camera_mode == 2
		rear_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if camera_mode == 2 and state in [State.COUNTDOWN, State.RACING] else SubViewport.UPDATE_DISABLED
		rear_camera.position = car.to_global(Vector3(0, 1.2, -2.7))
		rear_camera.look_at(car.to_global(Vector3(0, 1.15, -40)))

func _load_preferences() -> void:
	if test_mode:
		return
	if preferences.load("user://driver.cfg") == OK:
		volume = clampf(float(preferences.get_value("settings", "volume", 0.7)), 0, 1)
		fullscreen = bool(preferences.get_value("settings", "fullscreen", false))
		selected_vehicle = str(preferences.get_value("settings", "vehicle", "v8"))
		if not preload("res://scripts/car_catalog.gd").CARS.has(selected_vehicle):
			selected_vehicle = "v8"
		camera_mode = clampi(int(preferences.get_value("settings", "camera", 2)), 0, 2)
		reduced_motion = bool(preferences.get_value("settings", "reduced_motion", false))
		weather_mode = str(preferences.get_value("settings", "weather", "clear"))
		if weather_mode not in ["clear", "overcast", "rain"]: weather_mode = "clear"
		var saved: Variant = preferences.get_value("records", "static_v3_weather", {})
		if saved is Dictionary:
			records = saved

func _save_preferences() -> void:
	if test_mode:
		return
	preferences.set_value("settings", "weather", weather_mode)
	preferences.set_value("settings", "volume", volume)
	preferences.set_value("settings", "fullscreen", fullscreen)
	preferences.set_value("settings", "vehicle", selected_vehicle)
	preferences.set_value("settings", "camera", camera_mode)
	preferences.set_value("settings", "reduced_motion", reduced_motion)
	preferences.set_value("records", "static_v3_weather", records)
	var error := preferences.save("user://driver.cfg")
	if error != OK:
		push_warning("Could not save driver preferences: %s" % error_string(error))

func _set_volume(value: float) -> void:
	volume = value
	if ui: ui.volume_slider.set_value_no_signal(value)
	if front: front.get_node("%Volume").set_value_no_signal(value)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(0, value <= 0.001)
	_save_preferences()

func _set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if ui: ui.reduced_motion.set_pressed_no_signal(value)
	if front: front.get_node("%Motion").set_pressed_no_signal(value)
	_save_preferences()

func _set_fullscreen(value: bool) -> void:
	fullscreen = value
	if ui: ui.fullscreen_toggle.set_pressed_no_signal(value)
	if front: front.get_node("%Fullscreen").set_pressed_no_signal(value)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_preferences()

func _build_gate_marker() -> void:
	# Checkpoints remain logical; a racing circuit has no floating arcade gate props.
	gate_marker = Node3D.new()
	track.add_child(gate_marker)
func _build_front_end() -> void:
	showroom = $Showroom
	showroom_car = showroom.get_node("CarDisplay")
	front = $RaceInterface/Root/FrontEnd
	front.race_requested.connect(show_menu)
	front.car_selected.connect(_choose_showroom_car)
	front.volume_changed.connect(_set_volume)
	front.motion_changed.connect(_set_reduced_motion)
	front.fullscreen_changed.connect(_set_fullscreen)
	front.exit_requested.connect(func(): _save_preferences(); get_tree().quit())
	front.get_node("Margin/Stack/SettingsPanel/Volume").set_value_no_signal(volume)
	front.get_node("Margin/Stack/SettingsPanel/Motion").set_pressed_no_signal(reduced_motion)
	front.get_node("Margin/Stack/SettingsPanel/Fullscreen").set_pressed_no_signal(fullscreen)
	front.select_car(selected_vehicle)
	ui.home_requested.connect(show_home)

func _choose_showroom_car(key: String) -> void:
	select_vehicle(key)
	for child in showroom_car.get_children():
		showroom_car.remove_child(child)
		child.queue_free()
	var model = load("res://assets/cars/" + str(car.profile.asset) + ".glb").instantiate()
	showroom_car.add_child(model)
	showroom_car.rotation.y = -.4
	for i in ui.vehicle_choice.item_count:
		if ui.vehicle_choice.get_item_metadata(i) == key: ui.vehicle_choice.select(i)

func show_home() -> void:
	state = State.MENU
	car.velocity = Vector3.ZERO
	audio.active = false
	ui.menu.hide()
	ui.hud.hide()
	ui.modal.hide()
	track.hide()
	showroom.show()
	front.show()
	front.open_page("home")
	front.select_car(selected_vehicle)
	_save_preferences()
