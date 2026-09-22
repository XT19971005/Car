extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	for pair in [["monza", .18], ["spa", .16], ["laguna", .70]]:
		game.select_track(pair[0])
		game.start_race()
		game.state = game.State.RACING
		game.ui.hide()
		var route: Dictionary = game.track.at_progress(pair[1])
		game.car.reset_at(route.point, route.tangent)
		for i in 30:
			await physics_frame
			game.car.drive(1.0/60,0,0,0,false,false)
		game.camera_mode = 0
		game._update_camera(1,true)
		game.weather.camera_position=game.camera.position
		for weather in ["clear", "overcast", "rain", "sunset"]:
			game.weather.set_weather(weather)
			for i in 60: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/previews/ATMOSPHERE_%s_%s.png" % [pair[0],weather]))
			print("ATMOSPHERE CAPTURE ",pair[0]," ",weather)
	game.queue_free()
	await process_frame
	quit()
