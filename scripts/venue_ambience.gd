extends RefCounted
## Tiny, original procedural audio loops; created only once at startup.
## No licensed soundtrack, imported samples or per-frame synthesis.
const SAMPLE_RATE = 11025
const LOOP_SECONDS = 2
static var _cache: Dictionary = {}

static func soundscape(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var frames := SAMPLE_RATE * LOOP_SECONDS
	var data := PackedByteArray()
	data.resize(frames * 2)
	var generator := RandomNumberGenerator.new()
	generator.seed = {
		"STALL": 43178, "CAFE": 31323, "BAR": 55217, "CLUB": 77823
	}.get(kind, 41001)
	for i in range(frames):
		var t := float(i) / float(SAMPLE_RATE)
		var noise := generator.randf_range(-1.0, 1.0)
		var sample := 0.0
		var phase := fposmod(t * 2.0, 1.0)
		match kind:
			"STALL":
				# Grill hiss, ventilation and a subtle kettle pulse.
				sample = noise * 0.050 + sin(TAU * 92.0 * t) * 0.018
				sample += sin(TAU * 210.0 * t) * 0.012 * pow(1.0 - phase, 3.0)
			"CAFE":
				# Espresso pump's low hum and gently recurring crockery taps.
				var clink := exp(-38.0 * fposmod(t + 0.3, 1.0))
				sample = noise * 0.014 + sin(TAU * 74.0 * t) * 0.018
				sample += sin(TAU * 1180.0 * t) * 0.055 * clink
			"BAR":
				# Low ventilation, distant conversation-like murmur and glass tick.
				sample = noise * 0.018 + sin(TAU * 66.0 * t) * 0.023
				sample += sin(TAU * 630.0 * t) * 0.016 * exp(-15.0 * phase)
			"CLUB":
				# Original two-hertz abstract bass pulse with soft static.
				var kick := exp(-11.0 * phase)
				sample = sin(TAU * 58.0 * t) * kick * 0.15
				sample += noise * 0.012 + sin(TAU * 116.0 * t) * 0.018
			_:
				sample = noise * 0.012
		# Enforce a smooth loop boundary even for noise-based scenes.
		var fade := clampf(minf(float(i), float(frames - i - 1)) / 175.0, 0.0, 1.0)
		var signed := clampi(roundi(sample * fade * 32767.0), -32768, 32767)
		var packed := signed if signed >= 0 else signed + 65536
		data[i * 2] = packed & 255
		data[i * 2 + 1] = (packed >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	stream.data = data
	_cache[kind] = stream
	return stream

static func soundscape_count() -> int:
	return _cache.size()
