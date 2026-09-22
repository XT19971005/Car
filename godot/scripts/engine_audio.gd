extends AudioStreamPlayer
var texture_samples := PackedFloat32Array()
var texture_cursor := 0.0
var mechanical_phase := 0.0
var rain_amount := 0.0
var playback: AudioStreamGeneratorPlayback
var phase := 0.0
var noise_state := 0.0
var rpm := 950.0
var throttle := 0.0
var speed := 0.0
var slip := 0.0
var active := false
var gain := 0.0
var rng := RandomNumberGenerator.new()
var cylinders := 8
var engine_type := "v8"
var shift := 0.0
var impact := 0.0
var rumble := 0.0
var cockpit := false
var filtered_left := 0.0
var filtered_right := 0.0
var exhaust_phase := 0.0
var tyre_phase := 0.0
var cue_phase := 0.0
var cue_frequency := 800.0
var cue_remaining := 0.0
var cue_duration := 0.0

func play_cue(frequency: float, duration := .08) -> void:
	cue_frequency = frequency
	cue_remaining = duration
	cue_duration = duration

func _exit_tree() -> void:
	stop()
	playback = null
	stream = null

func _ready() -> void:
	var sample := AudioStreamWAV.load_from_file("res://assets/audio/engine_texture.wav")
	if sample:
		var data := sample.data
		texture_samples.resize(data.size() / 2)
		for i in texture_samples.size(): texture_samples[i] = float(data.decode_s16(i * 2)) / 32768.0
	if DisplayServer.get_name() == "headless":
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.12
	stream = generator
	volume_db = -8
	play()
	playback = get_stream_playback()

func _process(dt: float) -> void:
	if not playback:
		return
	gain = move_toward(gain, 1.0 if active else 0.0, dt * 5)
	for i in playback.get_frames_available():
		playback.push_frame(synthesize_frame())

func synthesize_frame() -> Vector2:
	var frequency := rpm / 120.0 * cylinders
	phase = fposmod(phase + frequency / 44100.0, 1.0)
	exhaust_phase = fposmod(exhaust_phase + rpm / 120.0 / 44100.0, 1.0)
	tyre_phase = fposmod(tyre_phase + (650 + slip * 23) / 44100.0, 1.0)
	var noise := rng.randf_range(-1, 1)
	noise_state = lerpf(noise_state, noise, 0.065)
	var pulse := sin(phase * TAU) * .40 + sin(phase * TAU * 2.0 + .4) * .19 + sin(phase * TAU * 3.0) * .10 + sin(phase * TAU * 5.0) * .045
	var firing := sin(exhaust_phase * TAU) * .08 + sin(exhaust_phase * TAU * 2) * .08
	var motor := pulse + firing
	if engine_type == "r6":
		motor += sin(phase * TAU * 1.5) * .12
	elif engine_type == "v6":
		motor += sin(phase * TAU * 6.0) * throttle * .035
	var texture := 0.0
	if not texture_samples.is_empty():
		var ratio := clampf(rpm / 3200.0, .40, 2.6) * (.84 if engine_type == "v8" else 1.18 if engine_type == "r6" else 1.02)
		texture_cursor = fposmod(texture_cursor + ratio, texture_samples.size())
		var index := int(texture_cursor)
		texture = lerpf(texture_samples[index], texture_samples[(index + 1) % texture_samples.size()], fposmod(texture_cursor, 1.0))
	mechanical_phase = fposmod(mechanical_phase + (rpm / 60.0 * 12) / 44100.0, 1.0)
	var whine := sin(mechanical_phase * TAU) * throttle * (.023 if engine_type == "v6" else .009)
	var exhaust := (motor * .29 + texture * .85 + whine) * (.35 + throttle * .55) * (1.0 - shift * .6)
	var tyre := sin(tyre_phase * TAU) * minf(slip / 18, .16) + noise_state * minf(absf(speed) / 90, 1) * .15
	var kerb := (sin(exhaust_phase * TAU * .5) + noise_state) * rumble * minf(absf(speed) / 80, 1) * .09
	var collision := noise_state * impact * .42
	var value := (exhaust + tyre + kerb + collision) * gain + noise * rain_amount * .065
	if cue_remaining > 0:
		cue_phase = fposmod(cue_phase + cue_frequency / 44100.0, 1.0)
		var envelope := minf(cue_remaining * 90, 1) * minf((cue_duration - cue_remaining) * 180, 1)
		value += sin(cue_phase * TAU) * envelope * .16
		cue_remaining = maxf(0, cue_remaining - 1.0 / 44100.0)
	var filtering := .12 if cockpit else .45
	filtered_left = lerpf(filtered_left, value, filtering)
	filtered_right = lerpf(filtered_right, value + noise_state * .018 * gain, filtering * .94)
	return Vector2(tanh(filtered_left), tanh(filtered_right))
