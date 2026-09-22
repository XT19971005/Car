extends SceneTree
var folder: String
func _initialize(): run.call_deferred()
func shot(name: String):
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var path := folder.path_join(name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("REPORT CAPTURE: ", name)
func run():
	folder = ProjectSettings.globalize_path("res://../art/日报截图/2026-09-22")
	DisplayServer.window_set_size(Vector2i(1920,1080))
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.show_home()
	game._update_camera(1,true)
	await shot("01_封面与界面/01_主界面")
	var titles := {"v8":"八缸GT跑车", "r6":"拉力掀背车", "v6":"赛道原型车"}
	for key in titles:
		game.show_home()
		game.front.select_car(key)
		game._update_camera(1,true)
		game.front.hide()
		game.ui.root.hide()
		for angle in [0,1]:
			game.camera.position = Vector3(10005.7,2.2,6.0 if angle==0 else -6.0)
			game.camera.look_at(Vector3(10000,.65,0))
			game.camera.fov = 42
			await shot("02_车辆/"+key+"_"+titles[key]+("_前侧" if angle==0 else "_后侧"))
	game.show_menu()
	game._update_camera(1,true)
	await shot("01_封面与界面/02_赛前设置")
	for setup in [["spa","v6",.16,"clear","斯帕_原型赛车"], ["monza","v8",.0,"clear","蒙扎_八缸赛车"], ["bathurst","r6",.36,"sunset","巴瑟斯特_山地日落"]]:
		game.select_track(setup[0])
		game.select_vehicle(setup[1])
		game.start_race()
		game.ui.root.show()
		game.state = game.State.RACING
		game.ui.countdown_label.text = ""
		game.weather.set_weather(setup[3])
		var p: Dictionary = game.track.at_progress(setup[2])
		game.car.reset_at(p.point,p.tangent)
		for i in 20:
			await physics_frame
			game.car.drive(1.0/60,0,0,0,false,false)
		game.camera_mode=0
		game._update_camera(1,true)
		game._update_hud()
		await shot("03_游戏实景/"+setup[4]+"_追车视角")
		game.camera_mode=2
		game._update_camera(1,true)
		await shot("03_游戏实景/"+setup[4]+"_驾驶舱")
		if setup[0]=="spa":
			game.ui.root.hide()
			game.rear_display.hide()
			var right := Vector3(-p.tangent.z,0,p.tangent.x).normalized()
			game.camera.position=p.point+p.tangent*7+right*4+Vector3.UP*2.4
			game.camera.look_at(p.point+Vector3.UP*.6)
			game.camera.fov=52
			await shot("01_封面与界面/03_赛道封面_无界面")
	game.queue_free()
	await process_frame
	print("DAILY REPORT COMPLETE: 15 screenshots")
	quit()
