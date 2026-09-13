extends RefCounted

const MIX_RATE := 22050

static func generate(kind: String) -> AudioStreamWAV:
	var data: PackedByteArray
	match kind:
		"honk":
			data = _honk()
		"eat":
			data = _eat()
		"growl":
			data = _growl()
		_:
			data = _eat()

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

static func resolve(kind: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://assets/sounds/%s.%s" % [kind, ext]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream != null:
				return stream
	return generate(kind)

static func play(at: Node, kind: String) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = resolve(kind)
	at.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

static func _honk() -> PackedByteArray:
	var duration := 0.35
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var phase := 0.0
	for i in range(frame_count):
		var t := float(i) / frame_count
		var freq: float = lerp(340.0, 260.0, t)
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		var value := 1.0 if phase < 0.5 else -1.0
		var envelope: float = 1.0 if t < 0.85 else clamp((1.0 - t) / 0.15, 0.0, 1.0)
		var sample := value * envelope * 0.5
		data.encode_s16(i * 2, int(sample * 32767.0))
	return data

static func _eat() -> PackedByteArray:
	var duration := 0.18
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var phase := 0.0
	for i in range(frame_count):
		var t := float(i) / frame_count
		var freq: float = lerp(420.0, 780.0, t)
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		var value := sin(phase * TAU)
		var envelope := sin(t * PI)
		var sample := value * envelope * 0.5
		data.encode_s16(i * 2, int(sample * 32767.0))
	return data

static func _growl() -> PackedByteArray:
	var duration := 0.6
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in range(frame_count):
		var t := float(i) / frame_count
		var freq := 90.0
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		var base_wave := phase * 2.0 - 1.0
		var tremolo := 0.6 + 0.4 * sin(t * 18.0)
		var noise := rng.randf_range(-0.15, 0.15)
		var envelope: float = clamp(min(t / 0.05, (1.0 - t) / 0.2), 0.0, 1.0)
		var sample := (base_wave * 0.7 + noise) * tremolo * envelope * 0.5
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))
	return data
