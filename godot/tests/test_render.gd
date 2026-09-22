extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for circuit: String in game.tracks:
		game.select_track(circuit)
		game.start_race()
		game.state = game.State.RACING
		game.ui.countdown_label.text = ""
		for mode in [0, 2]:
			game.camera_mode = mode
			for i in 35:
				await process_frame
			var durations: Array[float] = []
			var previous := Time.get_ticks_usec()
			for i in 120:
				await process_frame
				await RenderingServer.frame_post_draw
				var current := Time.get_ticks_usec()
				durations.append(float(current - previous) / 1000)
				previous = current
			var total := 0.0
			for duration in durations:
				total += duration
			durations.sort()
			print("RENDER: %s view=%d avg_fps=%.1f p95_ms=%.1f" % [circuit, mode, 120000.0 / total, durations[113]])
	game.show_menu()
	DisplayServer.window_set_size(Vector2i(960, 540))
	for i in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/menu-960x540.png")
	game.queue_free()
	await process_frame
	print("RENDER COMPLETE")
	quit()
