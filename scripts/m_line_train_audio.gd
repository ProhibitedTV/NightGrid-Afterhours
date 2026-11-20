extends RefCounted
## Original, cached 11-kHz rolling and arrival cues for the M-Line.
## No copyrighted recordings, imported samples or runtime synthesis in _process.
const SAMPLE_RATE = 11025
static var _sounds: Dictionary = {}

static func sound(kind: String) -> AudioStreamWAV:
	if _sounds.has(kind):
		return _sounds[kind]
	var seconds := 2.0
	var frames := int(float(SAMPLE_RATE) * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var generator := RandomNumberGenerator.new()
	generator.seed = 91127 if kind == "ROLL" else 18641
	for i in range(frames):
		var t := float(i) / float(SAMPLE_RATE)
		var white_noise := generator.randf_range(-1.0, 1.0)
		var sample := 0.0
		if kind == "ROLL":
			var running := sin(TAU * 56.0 * t) * 0.038
			running += sin(TAU * 91.0 * t) * 0.013
			var contact := exp(-38.0 * fposmod(t * 6.0, 1.0))
			sample = running + white_noise * 0.026 + contact * 0.042
		else:
			# Two short ascending station acknowledgement notes.
			var first := maxf(0.0, t - 0.07)
			var second := maxf(0.0, t - 0.62)
			sample = sin(TAU * 622.25 * first) * exp(-6.0 * first) * 0.12 if t >= 0.07 else 0.0
			if t >= 0.62:
				sample += sin(TAU * 783.99 * second) * exp(-6.0 * second) * 0.13
		# Suppress discontinuity at loop boundaries and keep chime silence intact.
		var blend := clampf(minf(float(i), float(frames - i - 1)) / 160.0, 0.0, 1.0)
		var signed := clampi(roundi(sample * blend * 32767.0), -32768, 32767)
		var value := signed if signed >= 0 else signed + 65536
		data[i * 2] = value & 255
		data[i * 2 + 1] = (value >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if kind == "ROLL" else AudioStreamWAV.LOOP_DISABLED
	stream.loop_begin = 0
	stream.loop_end = frames
	stream.data = data
	_sounds[kind] = stream
	return stream

static func cache_count() -> int:
	return _sounds.size()
