extends Node
## Original synthesized sounds; no sample downloads or external audio assets.
var muted: bool = false:
	set(value):
		muted = value
		if muted:
			for voice: Variant in voices:
				voice.stop()
var voices: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var tones: Dictionary = {}

func _ready() -> void:
	for i: Variant in 4:
		var player: Variant = AudioStreamPlayer.new()
		player.volume_db = -15.0
		add_child(player)
		voices.append(player)
	tones["eat"] = _tone(660.0, 990.0, 0.13)
	tones["start"] = _tone(440.0, 660.0, 0.18)
	tones["end"] = _tone(240.0, 90.0, 0.30)
	tones["pause"] = _tone(440.0, 380.0, 0.07)
	tones["win"] = _tone(660.0, 1320.0, 0.45)

func play_sound(sound: String) -> void:
	if muted or not tones.has(sound):
		return
	var voice: Variant = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = tones[sound]
	voice.play()

func _tone(from_hz: float, to_hz: float, duration: float) -> AudioStreamWAV:
	const RATE: Variant = 22050
	var data: Variant = PackedByteArray()
	data.resize(int(duration * RATE) * 2)
	var phase: Variant = 0.0
	for i: Variant in data.size() / 2:
		var t: Variant = float(i) / float(data.size() / 2)
		var frequency: Variant = lerpf(from_hz, to_hz, t)
		phase += TAU * frequency / RATE
		var envelope: Variant = minf(t * 35.0, 1.0) * pow(1.0 - t, 2.0)
		var sample: Variant = int((sin(phase) * 0.85 + sin(phase * 2.0) * 0.15) * envelope * 15000)
		data.encode_s16(i * 2, sample)
	var stream: Variant = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
