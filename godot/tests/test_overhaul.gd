extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	if value: print("OVERHAUL PASS: ", label)
	else:
		failures += 1
		push_error("OVERHAUL FAIL: " + label)
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.front.visible and not game.ui.menu.visible, "Main menu is separate from race setup")
	game.front.get_node("%Garage").pressed.emit()
	check(game.front.get_node("%GaragePanel").visible, "Garage navigation opens vehicle selection")
	game.front.get_node("%Rally").pressed.emit()
	check(game.selected_vehicle == "r6" and game.car.profile.asset == "VEH_Rally_Hatch", "Garage changes the real vehicle asset")
	game.front.get_node("%Continue").pressed.emit()
	check(game.ui.menu.visible and not game.front.visible and game.ui.track_buttons.size() == 9, "Garage continues to nine-circuit setup")
	var choice = game.ui.find_child("WeatherChoice", true, false)
	choice.select(2)
	choice.item_selected.emit(2)
	check(game.weather.mode == "rain" and game.weather.rain.emitting, "Weather selector activates rain, not just a label")
	game.records[game._record_key()] = 123.0
	game._set_weather("clear")
	check(game.best_time() == 0, "Dry records are separate from wet records")
	game._set_weather("rain")
	check(game.best_time() == 123.0, "Changing weather restores its own record")
	choice.select(3)
	choice.item_selected.emit(3)
	check(game.weather.mode == "sunset" and not game.weather.rain.emitting and game.weather.sun.rotation_degrees.x > -15, "Sunset selection changes sky and light without wet physics")
	choice.select(2)
	choice.item_selected.emit(2)
	check(game.weather.sun.rotation_degrees.x < -20, "Leaving sunset restores weather sun angle")
	game.ui.start_button.pressed.emit()
	game.state = game.State.RACING
	var route: Dictionary = game.track.at_progress(.42)
	var right := Vector3(route.tangent.z, 0, -route.tangent.x).normalized()
	game.car.position = route.point + right * 28 + Vector3.UP * 3
	var nearest: Dictionary = game.track.sample(game.car.position)
	game.session.next_gate = 2
	game.reset_car()
	check(game.car.position.distance_to(nearest.point + Vector3.UP * .14) < .01, "R recovers to nearest road, even far from earned checkpoint")
	check(not game.session.valid and game.session.next_gate > 2, "Recovery invalidates lap and advances practice checkpoint cursor")
	game.weather.set_weather("clear")
	var distances: Array[float] = []
	for wet in [0.0, 1.0]:
		game.car.reset_at(game.track.points[0], game.track.tangent(0))
		game.car.surface_wetness = wet
		for tick in 30:
			await physics_frame
			game.car.drive(1.0/60, 0, 0, 0, false, false)
		var initial: Vector3 = game.car.position
		game.car.velocity = game.car.global_basis.z * 35
		game.car.speed = 35
		for tick in 120:
			await physics_frame
			game.car.drive(1.0/60, 0, 1, 0, false, false)
		distances.append(game.car.position.distance_to(initial))
	check(distances[1] > distances[0] + 3, "Wet braking distance increases under actual physics")
	print("BRAKING DISTANCE dry=", distances[0], " wet=", distances[1])
	game.show_home()
	check(game.front.visible and not game.ui.hud.visible, "Return from race restores main menu")
	game.queue_free()
	await process_frame
	print("OVERHAUL COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
