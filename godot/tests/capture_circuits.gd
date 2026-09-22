extends SceneTree
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
	for i in 35: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/previews/" + name + ".png"))
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.show_menu()
	game.ui.hide()
	for key: String in game.tracks:
		game.select_track(key)
		await process_frame
		await RenderingServer.frame_post_draw
		var batches: Array[Node] = game.track.find_children("*", "MultiMeshInstance3D", true, false)
		for batch in batches:
			if batch.multimesh.get_aabb().size.length() < .01:
				push_error("EMPTY SAVED GEOMETRY: " + key + "/" + batch.name)
				quit(1)
				return
		var start: Dictionary = game.track.at_progress(.02)
		var right := Vector3(start.tangent.z, 0, -start.tangent.x)
		game.camera.position = start.point - start.tangent * 45 + right * 60 + Vector3.UP * 35
		game.camera.look_at(start.point + start.tangent * 65)
		game.camera.fov = 65
		await shot("CIRCUIT_" + key + "_Start")
		var bounds := AABB(game.track.points[0], Vector3.ONE)
		for p: Vector3 in game.track.points: bounds = bounds.expand(p)
		var extent := maxf(bounds.size.x, bounds.size.z)
		game.camera.far = 10000
		game.camera.position = bounds.get_center() + Vector3(extent * .2, extent * .9, extent * .7)
		game.camera.look_at(bounds.get_center())
		await shot("CIRCUIT_" + key + "_Overview")
		print("CIRCUIT RENDER PASS: ", key, " batches=", batches.size())
	game.queue_free()
	await process_frame
	print("ALL CIRCUITS VISUALLY CAPTURED")
	quit()
