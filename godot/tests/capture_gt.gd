extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func shot(name: String) -> void:
	for i in 35:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/previews/" + name + ".png"))
func _run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	for pairing in [["monza", "v8"], ["spa", "r6"], ["silverstone", "v6"]]:
		game.select_track(pairing[0])
		game.select_vehicle(pairing[1])
		game.start_race()
		# Let the actual collision body settle before freezing the photo view.
		for tick in 30:
			await physics_frame
			game.car.drive(1.0 / 60, 0, 0, 0, false, false)
		game.state = game.State.RACING
		game.ui.countdown_label.text = ""
		game.camera_mode = 2
		game._update_camera(1, true)
		await shot("GODOT_" + pairing[0] + "_Cockpit")
		game.rear_viewport.get_texture().get_image().save_png("res://test-output/rear_" + pairing[0] + ".png")
		game.ui.hide()
		var p: Dictionary = game.track.at_progress(.0)
		var right := Vector3(-p.tangent.z, 0, p.tangent.x).normalized()
		game.camera.position = p.point + p.tangent * 7 + right * 5 + Vector3.UP * 3
		game.camera.look_at(p.point + Vector3.UP * .65)
		game.camera.fov = 47
		await shot("GODOT_" + pairing[0] + "_" + pairing[1])
		game.camera.position = p.point - p.tangent * 6 + right * 3 + Vector3.UP * 3
		game.camera.look_at(p.point + Vector3.UP * .65)
		await shot("GODOT_" + pairing[0] + "_Rear")
		game.camera.position = p.point - p.tangent * 130 - right * 120 + Vector3.UP * 90
		game.camera.look_at(p.point + p.tangent * 75)
		game.camera.fov = 65
		await shot("GODOT_" + pairing[0] + "_Venue")
		game.ui.show()
	game.queue_free()
	await process_frame
	print("GT CAPTURE COMPLETE")
	quit()
