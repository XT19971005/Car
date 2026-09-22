extends AudioStreamPlayer
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

func _exit_tree() -> void:
	stop()
	playback = null
	stream = null

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.08
	stream = generator
	volume_db = -10
	play()
	playback = get_stream_playback()

func _process(dt: float) -> void:
	if not playback:
		return
	gain = move_toward(gain, 1.0 if active else 0.0, dt * 5)
	var frequency := rpm / 60.0 * 2.0
	for i in playback.get_frames_available():
		phase = fposmod(phase + frequency / 22050.0, 1.0)
		var noise := rng.randf_range(-1, 1)
		noise_state = lerpf(noise_state, noise, 0.12)
		var motor := sin(phase * TAU) * 0.4 + sin(phase * TAU * 2) * 0.16 + sin(phase * TAU * 4) * 0.07
		var sample := (motor * (0.22 + throttle * 0.32) + noise_state * absf(speed) / 76 * 0.22 + noise * minf(slip / 12, 0.2)) * gain
		playback.push_frame(Vector2(sample, sample))
