extends SceneTree
## Closed-loop driver exercises actual car movement, collision, checkpoint and results systems.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			game.select_track(argument.trim_prefix("--track="))
		if argument.begins_with("--car="):
			game.select_vehicle(argument.trim_prefix("--car="))
	game.ui.lap_choice.select(0)
	game.start_race()
	game.set_physics_process(false)
	game.state = game.State.RACING
	var car = game.car
	car.automatic_gears = true
	var peak_offroad := 0.0
	var airborne := 0
	var stalled := 0
	var last_checkpoint_progress := 0.0
	for step in 30000:
		await physics_frame
		var sample: Dictionary = game.track.sample(car.position)
		var look: Dictionary = game.track.at_progress(float(sample.progress) + (7.0 + absf(car.speed) * 0.28) / game.track.length)
		var target: Vector3 = look.point - car.position
		var error := wrapf(atan2(target.x, target.z) - car.heading, -PI, PI)
		var target_speed := 42.0
		# Brake before curvature: the controller no longer relies on unbounded yaw.
		for distance in [10.0, 25.0, 45.0, 70.0, 100.0]:
			var entry: Dictionary = game.track.at_progress(float(sample.progress)+(distance-8.0)/game.track.length)
			var exit_point: Dictionary = game.track.at_progress(float(sample.progress)+(distance+8.0)/game.track.length)
			var curvature := absf((entry.tangent as Vector3).signed_angle_to(exit_point.tangent,Vector3.UP))/16.0
			var corner_speed := sqrt(float(car.profile.grip)*.95/maxf(curvature,.001))
			target_speed = minf(target_speed,sqrt(corner_speed*corner_speed+2.0*10.0*maxf(distance-12.0,0.0)))
		var look_distance := maxf(Vector2(target.x,target.z).length(),1.0)
		var angle: float = car.steering_angle_at_speed(car.speed)
		var turn := -atan(2.0*float(car.profile.wheelbase)*sin(error)/look_distance)/angle
		car.drive(1.0/60,1.0 if car.speed<target_speed else 0.0,.8 if car.speed>target_speed+.5 else 0.0,clampf(turn,-1,1),false,float(sample.distance)>game.track.half_width+.85)
		stalled = stalled + 1 if step > 120 and absf(car.speed) < 1.5 else 0
		if step % 300 == 0:
			if step > 300 and absf(float(sample.progress) - last_checkpoint_progress) < 0.001:
				stalled = 181
			last_checkpoint_progress = float(sample.progress)
		if stalled > 180:
			print("STALL track=%s position=%s error=%.3f floor=%s velocity=%s" % [game.selected_track, car.position, error, car.is_on_floor(), car.velocity])
			print("ROAD SAMPLE ", sample)
			for i in car.get_slide_collision_count():
				var collision: KinematicCollision3D = car.get_slide_collision(i)
				print("COLLISION normal=%s point=%s collider=%s" % [collision.get_normal(), collision.get_position(), collision.get_collider().get_parent().get_path()])
			break
		sample = game.track.sample(car.position)
		peak_offroad = maxf(peak_offroad, float(sample.distance))
		if not car.is_on_floor():
			airborne += 1
		var event: String = game.session.tick(1.0 / 60, float(sample.progress), float(sample.distance) <= game.track.half_width + 1.0, car.velocity.dot(sample.tangent) > 0)
		if step % 3000 == 0:
			print("DRIVE step=%d gate=%d progress=%.3f speed=%.1f distance=%.2f" % [step, game.session.next_gate, sample.progress, car.speed, sample.distance])
		if event == "finish":
			if peak_offroad > game.track.half_width + 1.0:
				push_error("DRIVE FAIL: controller left track: %.2fm" % peak_offroad)
				game.queue_free()
				await process_frame
				quit(1)
				return
			game._save_record()
			game._finish()
			print("DRIVE PASS: track=%s car=%s lap=%.3f max_road_offset=%.2fm airborne_ticks=%d results=%s" % [game.selected_track, game.selected_vehicle, game.session.elapsed, peak_offroad, airborne, game.state == game.State.RESULTS])
			game.queue_free()
			await process_frame
			quit(0)
			return
	push_error("DRIVE FAIL: Did not complete lap; gate=%d position=%s" % [game.session.next_gate, car.position])
	game.queue_free()
	await process_frame
	quit(1)
