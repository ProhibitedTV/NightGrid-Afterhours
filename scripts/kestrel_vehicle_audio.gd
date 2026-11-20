extends RefCounted
## Authored original synthesized EV motor bed; loops are cached once.
## This is not recorded music, an external asset or per-frame DSP.
const SAMPLE_RATE = 11025
const FRAMES = 22050
static var _cached: AudioStreamWAV

static func sound() -> AudioStreamWAV:
	if _cached != null:
		return _cached
	var data := PackedByteArray()
	data.resize(FRAMES * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 621198
	for i in range(FRAMES):
		var t := float(i) / float(SAMPLE_RATE)
		var phase := fposmod(t * 8.0, 1.0)
		var motor := 0.032 * sin(TAU * 71.0 * t) + 0.015 * sin(TAU * 142.0 * t)
		var electronic := 0.008 * sin(TAU * 285.0 * t)
		var road := 0.012 * rng.randf_range(-1.0, 1.0)
		var tread := 0.011 * exp(-18.0 * phase)
		var fade := clampf(minf(float(i), float(FRAMES - i - 1)) / 240.0, 0.0, 1.0)
		var sample := clampi(roundi((motor + electronic + road + tread) * fade * 32767.0), -32768, 32767)
		var packed := sample if sample >= 0 else sample + 65536
		data[i * 2] = packed & 255
		data[i * 2 + 1] = (packed >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = FRAMES
	stream.data = data
	_cached = stream
	return stream
