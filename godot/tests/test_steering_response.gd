extends SceneTree
var failures := 0
func _initialize(): run.call_deferred()
func run():
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000,1,2000)
	collider.shape=shape
	floor_body.add_child(collider)
	floor_body.position=Vector3(10000,-.5,10000)
	root.add_child(floor_body)
	await physics_frame
	var car = game.car
	for key in ["v8","r6","v6"]:
		car.configure_vehicle(key)
		for wet in [0.0,1.0]:
			for initial_speed in [10.0,25.0,55.0]:
				car.reset_at(Vector3(10000,0,10000),Vector3(0,0,1))
				car.surface_wetness=wet
				for i in 30:
					await physics_frame
					car.drive(1.0/60,0,0,0,false,false)
				car.velocity=Vector3(0,0,initial_speed)
				car.speed=initial_speed
				var early := 0.0
				var peak_slip := 0.0
				for i in 60:
					await physics_frame
					car.drive(1.0/60,0,0,.6,false,false)
					peak_slip=maxf(peak_slip,car.slip)
					if i==14: early=absf(rad_to_deg(car.heading))
				var full := absf(rad_to_deg(car.heading))
				for i in 6:
					await physics_frame
					car.drive(1.0/60,0,0,-.6,false,false)
				var reversed: bool = car.yaw_rate>0
				for i in 45:
					await physics_frame
					car.drive(1.0/60,0,0,0,false,false)
				var settled: bool = absf(car.yaw_rate)<.015 and car.slip<.10
				print("STEERING: %s wet=%.0f speed=%.0f initial_deg=%.3f one_second_deg=%.3f reverse_100ms=%s slip=%.3f settled=%s" % [key,wet,initial_speed,early,full,reversed,peak_slip,settled])
				if not settled or peak_slip>1.4: failures+=1
				if "--baseline" not in OS.get_cmdline_user_args():
					if not reversed: failures+=1
					if initial_speed==10 and early<18: failures+=1
					if initial_speed==25 and full<(42.0 if wet>0 else 57.0): failures+=1
					if initial_speed==55 and (full<(15.0 if wet>0 else 21.0) or full>29.0): failures+=1
	game.queue_free()
	await process_frame
	print("STEERING RESULT failures=",failures)
	quit(1 if failures else 0)
