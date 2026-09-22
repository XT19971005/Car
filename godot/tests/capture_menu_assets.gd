extends SceneTree
func _initialize() -> void: run.call_deferred()
func shot(path: String) -> void:
	for i in 32: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/"+path+".png"))
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for key in ["v8","r6","v6"]:
		game.front.select_car(key)
		game._update_camera(1,true)
		game.front.hide()
		game.ui.root.hide()
		game.camera.position=Vector3(10006.8,2.2,6.8)
		game.camera.look_at(Vector3(10000,.65,0))
		game.camera.fov=42
		await shot("garage_"+key)
		game.front.show()
	game.select_track("spa")
	game.start_race()
	game.front.hide()
	game.ui.root.hide()
	game.rear_display.hide()
	var p: Dictionary = game.track.at_progress(.16)
	game.car.reset_at(p.point,p.tangent)
	for i in 30:
		await physics_frame
		game.car.drive(1.0/60,0,0,0,false,false)
	var right := Vector3(-p.tangent.z,0,p.tangent.x).normalized()
	game.camera.position=p.point+p.tangent*7+right*4+Vector3.UP*2.4
	game.camera.look_at(p.point+Vector3.UP*.6)
	game.camera.fov=52
	game.weather.set_weather("clear")
	await shot("race")
	game.queue_free()
	await process_frame
	quit()
