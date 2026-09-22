extends SceneTree
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
	for i in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/previews/" + name + ".png"))
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await shot("HOME_MainMenu")
	game.front.open_page("garage")
	for key in ["v8", "r6", "v6"]:
		game.front.select_car(key)
		print("FRONT LABEL ", game.front.get_node("Margin/Stack/Title").text, " visible=",game.front.get_node("Margin/Stack/Title").is_visible_in_tree())
		await shot("GARAGE_" + key)
	game.show_menu()
	await shot("MENU_NineCircuits")
	for key in ["clear", "overcast", "rain"]:
		game.weather.set_weather(key)
		game.start_race()
		game.state = game.State.RACING
		game.ui.countdown_label.text = ""
		game.camera_mode = 0
		for tick in 30:
			await physics_frame
			game.car.drive(1.0/60, 0, 0, 0, false, false)
		game._update_camera(1, true)
		await shot("WEATHER_" + key)
	game.weather.set_weather("clear")
	game.show_home()
	DisplayServer.window_set_size(Vector2i(960, 540))
	await shot("HOME_960x540")
	game.front.open_page("garage")
	await shot("GARAGE_960x540")
	game.queue_free()
	await process_frame
	print("OVERHAUL CAPTURE COMPLETE")
	quit()
