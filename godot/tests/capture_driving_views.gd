extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for key in ["v8", "r6", "v6"]:
		game.select_vehicle(key)
		game.start_race()
		game.state = game.State.RACING
		game.ui.countdown_label.text = ""
		for i in 3:
			await physics_frame
			game.car.drive(1.0/60,0,0,0,false,false)
		for mode in game.CAMERA_NAMES.size():
			game.camera_mode = mode
			game._update_camera(1,true)
			game._update_hud()
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/previews/VIEW_"+key+"_"+str(mode)+".png"))
		game.camera_mode = 2
		for turn in [-1.0, 1.0]:
			for i in 16:
				await physics_frame
				game.car.drive(1.0/60,0,0,turn,false,false)
			game._update_camera(1,true)
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/previews/STEERING_"+key+("_left" if turn<0 else "_right")+".png"))
	game.queue_free()
	await process_frame
	print("DRIVING VIEWS CAPTURED: 24")
	quit()
