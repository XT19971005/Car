extends SceneTree
func _initialize() -> void:
	_run.call_deferred()

func capture(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/" + name + ".png")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await capture("menu")
	game.start_race()
	game.set_physics_process(false)
	game.countdown = 0
	game.state = game.State.RACING
	game.ui.countdown_label.text = ""
	await capture("race")
	game.pause_race()
	await capture("pause")
	game.session.elapsed = 262.543
	game.session.best = 85.320
	game.session.laps.assign([{"time": 89.223, "valid": true}, {"time": 88.0, "valid": true}, {"time": 85.320, "valid": true}])
	game.ui.show_results(game.session, true)
	await capture("results")
	game.queue_free()
	await process_frame
	quit()
