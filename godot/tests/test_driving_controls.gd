extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CONTROL FAIL: " + title)
	else: print("CONTROL PASS: " + title)
func press(game: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_race()
	game.state = game.State.RACING
	var car = game.car
	car.position = Vector3(0, 1000, 0)
	car.heading = 0
	car.rotation = Vector3.ZERO
	car.body_visual.rotation = Vector3.ZERO
	for mode in game.CAMERA_NAMES.size():
		game.camera_mode = mode
		car.speed = 0
		game._update_camera(1.0, true)
		var relative: Vector3 = game.camera.position - car.position
		var fov: float = game.camera.fov
		car.speed = 80
		car.position += Vector3(0, 0, 10)
		game._update_camera(1.0/60)
		check(is_equal_approx(fov, game.camera.fov) and relative.distance_to(game.camera.position-car.position)<.002, "Fixed position and FOV at 288km/h view=" + str(mode))
	check(car.automatic_gears, "Default transmission is automatic")
	car.speed = 0
	car.gear = 1
	car.shift_timer = 0
	for i in 8: press(game, KEY_E)
	check(car.gear == 1 and car.automatic_gears, "E cannot stack gears at launch")
	press(game, KEY_Q)
	check(car.gear == 1, "Q does not select neutral at launch")
	car.speed = 30
	car.gear = 4
	car.shift_timer = 0
	press(game, KEY_Q)
	check(car.gear == 3 and car.automatic_gears and car.downshift_hold > 0, "Q downshifts without disabling automatic")
	press(game, KEY_Q)
	check(car.gear == 2, "Repeated Q forces consecutive downshifts")
	car.speed = 70
	car.gear = 4
	car.shift_timer = 0
	press(game, KEY_Q)
	check(car.gear == 3, "Q accepts forced high-rpm downshift")
	press(game, KEY_M)
	check(car.automatic_gears, "Legacy M cannot disable automatic")
	var loaded_id: int = game.track.get_instance_id()
	var began := Time.get_ticks_msec()
	for key in game.tracks: game.preview_track(key)
	check(game.track.get_instance_id() == loaded_id, "Nine preview selections never instantiate a circuit")
	print("NINE PREVIEWS MS: ",Time.get_ticks_msec()-began)
	game.preview_track("spa")
	await game._request_race()
	check(game.track.circuit_key == "spa" and game.state == game.State.COUNTDOWN, "Start loads selected circuit then starts countdown")
	# Large dedicated floor isolates handling from track layout and obstacles.
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000, 1, 2000)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position = Vector3(10000, -.5, 10000)
	root.add_child(floor_body)
	await physics_frame
	for key in ["v8", "r6", "v6"]:
		car.configure_vehicle(key)
		car.automatic_gears = true
		car.reset_at(Vector3(10000, 0, 10000), Vector3.FORWARD * -1)
		for i in 30:
			await physics_frame
			car.drive(1.0/60,0,0,0,false,false)
		car.velocity = Vector3(0,0,35)
		car.speed = 35
		var peak_slip := 0.0
		for i in 120:
			await physics_frame
			car.drive(1.0/60,.45,0,.35,false,false)
			peak_slip = maxf(peak_slip, car.slip)
		check(peak_slip < 1.2, "Controlled dry corner sideslip " + key + " = " + str(peak_slip))
		for i in 40:
			await physics_frame
			car.drive(1.0/60,0,0,0,false,false)
		check(absf(car.yaw_rate)<.015 and car.slip<.10, "Release steering settles without sustained drift " + key)
	car.automatic_gears = false
	car.reset_at(Vector3(10000,0,10000),Vector3(0,0,1))
	car.gear = 2
	for i in 180:
		await physics_frame
		car.drive(1.0/60,1,0,0,false,false)
	check(car.gear == 2 and car.speed>4, "Manual gear persists under acceleration")
	car.reset_at(Vector3(10000,0,10000),Vector3(0,0,1))
	car.gear = 0
	for i in 60:
		await physics_frame
		car.drive(1.0/60,1,0,0,false,false)
	check(absf(car.speed)<.1, "Neutral does not drive wheels")
	car.gear = -1
	for i in 60:
		await physics_frame
		car.drive(1.0/60,1,0,0,false,false)
	check(car.speed < -2, "Manual reverse drives backwards")
	for i in 120:
		await physics_frame
		car.drive(1.0/60,0,1,0,false,false)
	check(absf(car.speed)<.1, "Manual brake stops reverse without reaccelerating")
	var coast_speeds: Array[float] = []
	for force_down in [false, true]:
		car.automatic_gears = true
		car.reset_at(Vector3(10000,0,10000),Vector3(0,0,1))
		car.velocity = Vector3(0,0,60)
		car.speed = 60
		car.gear = 5
		if force_down:
			car.request_downshift()
			car.request_downshift()
		for i in 60:
			await physics_frame
			car.drive(1.0/60,0,0,0,false,false)
		coast_speeds.append(car.speed)
		if force_down: check(car.gear == 3, "Forced low gear remains engaged despite high rpm")
	check(coast_speeds[1] < coast_speeds[0] - 7, "Forced downshift produces meaningful engine braking")
	print("COAST / DOWNSHIFT SPEED: ",coast_speeds)
	for key in ["v8", "r6", "v6"]:
		car.configure_vehicle(key)
		car.reset_at(Vector3(10000,0,10000),Vector3(0,0,1))
		for i in 8:
			await physics_frame
			car.drive(1.0/60,0,0,1,false,false)
		check(car.steering > .99, "Full keyboard steering within 134ms " + key)
		check(not car.steering_wheel.basis.is_equal_approx(car.steering_wheel_rest), "Steering wheel visibly rotates " + key)
		for i in 16:
			await physics_frame
			car.drive(1.0/60,0,0,-1,false,false)
		check(car.steering < -.99, "Direction reversal within 267ms " + key)
		car.reset_at(Vector3(10000,0,10000),Vector3(0,0,1))
		check(car.steering_wheel.basis.is_equal_approx(car.steering_wheel_rest), "Reset recentres wheel " + key)
	var launch_speeds: Array[float] = []
	for launch_gear in [1, 6]:
		car.automatic_gears = false
		car.reset_at(Vector3(10000,0,10000),Vector3(0,0,1))
		car.gear = launch_gear
		for i in 180:
			await physics_frame
			car.drive(1.0/60,1,0,0,false,false)
		launch_speeds.append(car.speed)
	check(launch_speeds[1] < launch_speeds[0] * .3, "Sixth gear launch has much lower wheel torque than first")
	print("LAUNCH SPEED first/sixth: ",launch_speeds)
	car.automatic_gears = true
	car.reset_at(Vector3(10000,0,10000),Vector3(0,0,1))
	for i in 1200:
		await physics_frame
		car.drive(1.0/60,1,0,0,false,false)
	check(car.gear >= 3 and car.speed > 30, "Automatic transmission accelerates through multiple gears")
	game.queue_free()
	floor_body.queue_free()
	await process_frame
	print("CONTROL RESULT: ",checks," checks, ", failures," failures")
	quit(1 if failures else 0)
