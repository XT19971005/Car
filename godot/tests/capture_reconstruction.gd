extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.show_menu()
	game.ui.hide()
	DirAccess.make_dir_recursive_absolute("res://test-output/reconstruction")
	for key: String in game.tracks:
		game.select_track(key)
		for progress in [.15, .35, .55, .75]:
			var route: Dictionary = game.track.at_progress(progress)
			game.camera.position = route.point + Vector3.UP * 4.0
			game.camera.look_at(route.point + route.tangent * 50 + Vector3.UP * 2)
			game.camera.fov = 72
			for i in 12: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-output/reconstruction/%s_%02d.png" % [key, progress*100])
		print("RECONSTRUCTION CAPTURE: ", key)
	game.queue_free()
	await process_frame
	quit()
