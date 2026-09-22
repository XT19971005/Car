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
	game.ui.lap_choice.select(0)
	game.start_race()
	game.set_physics_process(false)
	game.state = game.State.RACING
	var car = game.car
	var peak_offroad := 0.0
	var airborne := 0
	var stalled := 0
	var last_checkpoint_progress := 0.0
	for step in 30000:
		await physics_frame
		var sample: Dictionary = game.track.sample(car.position)
		var look: Dictionary = game.track.at_progress(float(sample.progress) + (9.0 + absf(car.speed) * 0.40) / game.track.length)
		var target: Vector3 = look.point - car.position
		var error := wrapf(atan2(target.x, target.z) - car.heading, -PI, PI)
		var ahead: Dictionary = game.track.at_progress(float(sample.progress) + 65.0 / game.track.length)
		var bend := absf((sample.tangent as Vector3).signed_angle_to(ahead.tangent, Vector3.UP))
		var target_speed := clampf(42.0 - bend * 30, 13, 42)
		car.drive(1.0 / 60, 1.0 if car.speed < target_speed else 0.0, 0.65 if car.speed > target_speed + 1.0 else 0.0, clampf(-error * 2.7, -1, 1), false, float(sample.distance) > 8.85)
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
		var event: String = game.session.tick(1.0 / 60, float(sample.progress), float(sample.distance) <= 9, car.velocity.dot(sample.tangent) > 0)
		if step % 3000 == 0:
			print("DRIVE step=%d gate=%d progress=%.3f speed=%.1f distance=%.2f" % [step, game.session.next_gate, sample.progress, car.speed, sample.distance])
		if event == "finish":
			game._save_record()
			game._finish()
			print("DRIVE PASS: track=%s lap=%.3f max_road_offset=%.2fm airborne_ticks=%d results=%s" % [game.selected_track, game.session.elapsed, peak_offroad, airborne, game.state == game.State.RESULTS])
			game.queue_free()
			await process_frame
			quit(0)
			return
	push_error("DRIVE FAIL: Did not complete lap; gate=%d position=%s" % [game.session.next_gate, car.position])
	game.queue_free()
	await process_frame
	quit(1)
