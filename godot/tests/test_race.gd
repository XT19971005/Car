extends SceneTree
const Session = preload("res://scripts/race_session.gd")
const Track = preload("res://scripts/track_world.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func lap(session: RefCounted, offroad := false, reverse := false) -> void:
	for step in range(1, 1002):
		session.tick(0.1, fposmod(float(step) / 1000.0, 1.0), not offroad, not reverse)

func _run() -> void:
	var race := Session.new()
	race.reset(1)
	lap(race)
	check(race.finished and race.laps.size() == 1 and race.best > 0, "Ordered forward lap finishes and records a best")
	check(race.laps[0].sectors.size() == 3, "Three sector times recorded")
	race.reset(1)
	lap(race, true)
	check(not race.finished and race.next_gate == 1, "Off-road lap cannot earn gates")
	race.reset(1)
	lap(race, false, true)
	check(not race.finished, "Reverse crossings cannot finish")
	race.reset(1)
	race.tick(1.0, 0.9, true, true)
	race.tick(1.0, 0.001, true, true)
	check(not race.finished, "Start-line shortcut does not finish")
	race.reset(1)
	race.relocate(0.0)
	lap(race)
	check(race.finished and race.best == 0 and not race.laps[0].valid, "Reset lap completes without recording a best")
	race.reset(3)
	for i in 3:
		lap(race)
	check(race.finished and race.laps.size() == 3, "Three-lap race finishes exactly once")
	check(Session.time_text(59.9996) == "01:00.000", "Time rounding carries into next minute")
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	check(game.state == game.State.MENU, "Game boots into menu")
	var world = game.track
	var a: Vector3 = world.points[10]
	var b: Vector3 = world.points[11]
	check(float(world.sample(a.lerp(b, 0.5)).distance) < 0.01, "Road segment midpoint is on-road")
	game.start_race()
	game._physics_process(1.0)
	game.pause_race()
	var before: float = game.countdown
	game._physics_process(10.0)
	check(game.countdown == before, "Pause freezes countdown")
	game.resume_race()
	game._physics_process(2.1)
	check(game.state == game.State.RACING, "Countdown resumes and starts racing")
	game.pause_race()
	game._physics_process(5)
	check(game.session.elapsed == 0, "Pause freezes race timer")
	game.resume_race()
	var car = game.car
	check(car.wheel_nodes.size() == 4, "GT import exposes four animated axles, excluding fixed wheel arches")
	for i in 240:
		await physics_frame
		car.drive(1.0 / 60, 1, 0, 0, false, false)
	check(car.speed > 25 and car.is_on_floor(), "Car accelerates and stays on road collision")
	var heading: float = car.heading
	for i in 20:
		await physics_frame
		car.drive(1.0 / 60, 0, 0, 1, false, false)
	check(car.heading < heading, "Right input steers toward driver's right")
	var fast: float = absf(car.speed)
	for i in 60:
		await physics_frame
		car.drive(1.0 / 60, 0, 1, 0, false, false)
	check(absf(car.speed) < fast - 8, "Brake materially reduces speed")
	game.session.next_gate = 4
	var nearest_before: Dictionary = game.track.sample(game.car.position)
	game.reset_car()
	check(not game.session.valid and game.car.speed == 0, "Reset stops car and invalidates current lap")
	var restored: Dictionary = game.track.sample(game.car.position)
	check(game.car.position.distance_to(nearest_before.point + Vector3.UP * .14) < .01, "Reset projects to nearest road rather than checkpoint")
	game.start_race()
	check(game.session.valid and game.session.elapsed == 0 and not game.record_this_race, "Restart clears lap state")
	for key: String in game.tracks:
		game.select_track(key)
		check(game.track.length > 1000 and game.track.points.size() > 100, "Build track: " + key)
		await process_frame
	for key: String in preload("res://scripts/car_catalog.gd").CARS:
		game.select_vehicle(key)
		check(game.car.wheel_nodes.size() == 4 and game.car.cockpit_anchor != null, "Vehicle axles and cockpit import: " + key)
		var bounds := AABB()
		var first := true
		for node: MeshInstance3D in game.car.body_visual.find_children("*", "MeshInstance3D", true, false):
			var transform: Transform3D = game.car.body_visual.global_transform.affine_inverse() * node.global_transform
			var box: AABB = transform * node.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		check(absf(bounds.size.z - float(game.car.profile.length)) < .035, "Vehicle imported at catalogue metre length: " + key)
		game.camera_mode = 2
		game._update_camera(1, true)
		check(game.camera.global_position.distance_to(game.car.cockpit_anchor.global_position) < .025 and (-game.camera.global_basis.z).dot(game.car.global_basis.z) > .98, "Cockpit sits at driver eye position facing forward: " + key)
	game.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
