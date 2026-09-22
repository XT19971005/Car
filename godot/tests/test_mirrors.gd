extends SceneTree
var failures:=0
func _initialize():run.call_deferred()
func check(value:bool,title:String):
	if not value:failures+=1;push_error(title)
	else:print("MIRROR PASS: ",title)
func run():
	var game=load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_race()
	game.state=game.State.RACING
	game.ui.countdown_label.text=""
	for key in ["v8","r6","v6"]:
		game.select_vehicle(key)
		check(game.car.side_mirrors.size()==2,"Two real side mirrors "+key)
		check(game.car.body_visual.find_children("MirrorGlass_*", "MeshInstance3D", true, false).size()==2,"Two authored GLB glass meshes "+key)
		for angle in [0.0,PI*.5,PI]:
			game.car.heading=angle
			game.car.rotation.y=angle
			game.camera_mode=2
			game._update_camera(1,true)
			var rear=game.rear_camera
			check((-rear.global_basis.z).dot(-game.car.global_basis.z)>.99,"Central camera faces rear "+key)
			check(rear.is_position_behind(game.car.to_global(Vector3(0,1,15))),"Objects ahead excluded "+key)
			var left=rear.unproject_position(game.car.to_global(Vector3(4,1,-18)))
			check(game.rear_display.flip_h and left.x>game.rear_viewport.size.x*.5,"Driver left displays on mirrored left "+key)
			for mirror in game.car.side_mirrors:
				mirror.update_view(true)
				var side_camera=mirror.get_node("Viewport/Camera")
				check((-side_camera.global_basis.z).dot(-game.car.body_visual.global_basis.z)>.95,"Side camera points rearward "+key)
	game.select_vehicle("v8")
	game.start_race()
	game.state=game.State.RACING
	game.ui.countdown_label.text=""
	game.camera_mode=2
	for pair in [[Vector3(4,1.4,-14),Color.RED],[Vector3(-4,1.4,-14),Color.BLUE],[Vector3(0,1.4,14),Color.GREEN]]:
		var mesh:=MeshInstance3D.new()
		var sphere:=SphereMesh.new()
		sphere.radius=.65;sphere.height=1.3
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=pair[1]
		sphere.material=material
		mesh.mesh=sphere
		root.add_child(mesh)
		mesh.global_position=game.car.to_global(pair[0])
	game._update_camera(1,true)
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-output/mirror-direction-proof.png"))
	var left_mirror = game.car.side_mirrors[0]
	check(left_mirror.get_node("Viewport").render_target_update_mode==SubViewport.UPDATE_ALWAYS,"Visible edge mirror keeps rendering")
	var image: Image = left_mirror.get_node("Viewport").get_texture().get_image()
	check(image.get_pixel(128,32).get_luminance()>.02,"Authored mirror receives nonblack rear image")
	print("MIRROR RESULT failures=",failures)
	quit(1 if failures else 0)
