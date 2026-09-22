extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("GLOBAL PASS: ", label)
	else:
		failures += 1
		push_error("GLOBAL FAIL: " + label)
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.ui.volume_slider.value = .23
	check(is_equal_approx(game.front.get_node("%Volume").value, .23), "Race settings volume synchronizes with home settings")
	game.ui.reduced_motion.button_pressed = true
	check(game.front.get_node("%Motion").button_pressed, "Race motion setting synchronizes with home settings")
	game.front.get_node("%Volume").value = .67
	check(is_equal_approx(game.ui.volume_slider.value, .67), "Home volume synchronizes with race settings")
	game.front.get_node("%Motion").button_pressed = false
	check(not game.ui.reduced_motion.button_pressed, "Home motion synchronizes with race settings")
	game.start_race()
	game.countdown = 1.75
	game.pause_race()
	for i in 10: game._physics_process(1.0/60)
	check(is_equal_approx(game.countdown, 1.75), "Pause freezes pre-race countdown")
	game.resume_race()
	check(game.state == game.State.COUNTDOWN, "Resume restores countdown instead of skipping start")
	game.state = game.State.RACING
	game.camera_mode = 0
	var aim: Vector3 = game.car.position + Vector3.UP
	var blocker := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12, 8, .5)
	collider.shape = shape
	blocker.add_child(collider)
	root.add_child(blocker)
	blocker.global_transform = game.car.global_transform
	blocker.position += game.car.global_basis * Vector3(0, 3, -3.5)
	await physics_frame
	await physics_frame
	game._update_camera(1, true)
	var query := PhysicsRayQueryParameters3D.create(aim, game.camera.position)
	query.exclude = [game.car.get_rid()]
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	check(hit.is_empty(), "Chase camera stays in front of obstructing geometry")
	blocker.queue_free()
	game._set_weather("rain")
	game.weather._process(2)
	game._process(0)
	check(game.audio.rain_amount > .9, "Rain is audible during race")
	game.pause_race()
	game._process(0)
	check(game.audio.rain_amount == 0 and not game.audio.active, "Pause silences rain and engine")
	game.show_home()
	game._process(0)
	check(game.front.visible and not game.ui.modal.visible and (game.rear_display == null or not game.rear_display.visible), "Home hides race modal and mirror")
	game.queue_free()
	await process_frame
	print("GLOBAL REVIEW: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
