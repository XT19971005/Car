extends SceneTree
func _initialize(): run.call_deferred()
func run():
	print("LOAD")
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	print("START")
	game.start_race()
	game.state = game.State.RACING
	game.ui.countdown_label.text = ""
	print("SET CAMERA")
	game.camera_mode = 0
	game._update_camera(1,true)
	print("WAIT PHYSICS")
	for i in 3:
		await physics_frame
		print("PHYSICS ",i)
		game.car.drive(1.0/60,0,0,0,false,false)
	print("WAIT DRAW")
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	print("SAVE")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/previews/HUD_Clear.png"))
	game.camera_mode = 2
	game._update_camera(1,true)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/previews/COCKPIT_Clear.png"))
	print("COMPLETE")
	quit()
