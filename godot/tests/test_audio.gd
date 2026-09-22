extends SceneTree
const EngineAudio = preload("res://scripts/engine_audio.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var folder := ProjectSettings.globalize_path("res://../art/previews/audio")
	DirAccess.make_dir_recursive_absolute(folder)
	for key: String in preload("res://scripts/car_catalog.gd").CARS:
		var engine := EngineAudio.new()
		root.add_child(engine)
		engine.rng.seed = 7
		engine.engine_type = key
		engine.cylinders = int(preload("res://scripts/car_catalog.gd").CARS[key].cylinders)
		engine.gain = 1
		var buffer := PackedByteArray()
		var samples := 44100 * 8
		buffer.resize(samples * 4)
		var peak := 0.0
		var energy := 0.0
		for i in samples:
			var seconds := float(i) / 44100
			engine.rpm = 950 + clampf((seconds - 1) / 4, 0, 1) * 6400
			engine.throttle = clampf(seconds - 1, 0, 1)
			engine.speed = clampf(seconds - 1, 0, 5) * 13
			engine.shift = clampf(1.0 - absf(seconds - 3.5) * 7, 0, 1)
			engine.slip = 7 if seconds > 5 and seconds < 6 else 0
			engine.rumble = 1 if seconds > 6 and seconds < 7 else 0
			engine.gain = 0 if seconds > 7.4 else 1
			var frame: Vector2 = engine.synthesize_frame()
			if not is_finite(frame.x) or not is_finite(frame.y):
				push_error("AUDIO FAIL: non-finite sample " + key)
				quit(1)
				return
			peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
			energy += frame.length_squared() * .5
			buffer.encode_s16(i * 4, roundi(clampf(frame.x, -1, 1) * 32767))
			buffer.encode_s16(i * 4 + 2, roundi(clampf(frame.y, -1, 1) * 32767))
		if peak >= .98 or sqrt(energy / samples) < .02 or engine.synthesize_frame().length() > .00001:
			push_error("AUDIO FAIL: clipping, silent engine or menu noise " + key)
			quit(1)
			return
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 44100
		wav.stereo = true
		wav.data = buffer
		wav.save_to_wav(folder.path_join("GT_" + key + "_preview.wav"))
		print("AUDIO PASS: %s peak=%.3f rms=%.3f stopped=silent" % [key, peak, sqrt(energy / samples)])
		engine.queue_free()
		await process_frame
	print("AUDIO COMPLETE: 3 engines")
	quit()
