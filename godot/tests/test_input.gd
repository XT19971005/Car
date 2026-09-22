extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error("INPUT FAIL: " + description)
	else:
		print("INPUT PASS: " + description)
func _run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame
	check(game.front.visible and not game.ui.menu.visible, "Boot shows main menu")
	await key(KEY_ENTER, true)
	await key(KEY_ENTER, false)
	check(game.ui.menu.visible and not game.front.visible, "Main menu enters race setup")
	game.ui.start_button.grab_focus()
	await key(KEY_ENTER, true)
	await key(KEY_ENTER, false)
	while game.loading_race: await process_frame
	check(game.state == game.State.COUNTDOWN, "Enter starts race from focused menu button")
	for i in 200:
		await physics_frame
	check(game.state == game.State.RACING, "Countdown reaches racing without manual state changes")
	await key(KEY_W, true)
	for i in 150:
		await physics_frame
	await key(KEY_W, false)
	check(game.car.speed > 15, "W input drives the actual game controller")
	var fast: float = game.car.speed
	await key(KEY_S, true)
	for i in 40:
		await physics_frame
	await key(KEY_S, false)
	check(game.car.speed < fast - 5, "S input brakes")
	var before: int = game.camera_mode
	await key(KEY_C, true)
	await key(KEY_C, false)
	check(game.camera_mode != before, "C changes camera")
	await key(KEY_ESCAPE, true)
	await key(KEY_ESCAPE, false)
	check(game.state == game.State.PAUSED, "Escape pauses")
	var elapsed: float = game.session.elapsed
	var position: Vector3 = game.car.position
	for i in 30:
		await physics_frame
	check(is_equal_approx(elapsed, game.session.elapsed) and position.is_equal_approx(game.car.position), "Pause freezes clock and car")
	await key(KEY_ESCAPE, true)
	await key(KEY_ESCAPE, false)
	check(game.state == game.State.RACING, "Escape resumes")
	await key(KEY_R, true)
	await key(KEY_R, false)
	check(not game.session.valid and absf(game.car.speed) < 1, "R returns to nearest road and invalidates lap")
	game.queue_free()
	await process_frame
	print("INPUT COMPLETE: %d failures" % failures)
	quit(1 if failures else 0)
