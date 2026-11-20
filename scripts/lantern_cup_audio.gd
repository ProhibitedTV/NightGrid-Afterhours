extends RefCounted
## Original two-second ambient café steam-pump / cup-tap loop.
## Sound synthesis happens once per Godot process, never in the render frame.
const RATE = 11025
const COUNT = RATE * 2
static var _stream: AudioStreamWAV

static func sound() -> AudioStreamWAV:
	if _stream != null:
		return _stream
	var rng := RandomNumberGenerator.new()
	rng.seed = 430921
	var samples := PackedByteArray()
	samples.resize(COUNT * 2)
	for i in range(COUNT):
		var time_value := float(i) / float(RATE)
		var pump := 0.024 * sin(TAU * 68.0 * time_value)
		pump += 0.008 * sin(TAU * 134.0 * time_value)
		var cycle := fposmod(time_value, 1.0)
		var hiss_envelope := smoothstep(0.10, 0.21, cycle) * (1.0 - smoothstep(0.67, 0.90, cycle))
		var hiss := rng.randf_range(-1.0, 1.0) * 0.035 * hiss_envelope
		var cup_tap := 0.032 * sin(TAU * 440.0 * time_value) * exp(-23.0 * fposmod(time_value, 0.95))
		var fade := clampf(minf(float(i), float(COUNT - i - 1)) / 220.0, 0.0, 1.0)
		var amplitude := clampi(roundi((pump + hiss + cup_tap) * fade * 32767.0), -32768, 32767)
		var sample := amplitude if amplitude >= 0 else amplitude + 65536
		samples[i * 2] = sample & 255
		samples[i * 2 + 1] = (sample >> 8) & 255
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.stereo = false
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wave.loop_begin = 0
	wave.loop_end = COUNT
	wave.data = samples
	_stream = wave
	return wave
