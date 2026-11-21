extends RefCounted
## Original, deterministic sound design: no third-party clips or sample packs.
## PCM is generated on first use and cached, never synthesized in a render tick.
const RATE = 11025
const BED_SECONDS = 9.0
static var _cache: Dictionary = {}

static func sound(kind: String, variation: int = 0) -> AudioStreamWAV:
	var key := "%s_%d" % [kind, variation]
	if _cache.has(key):
		return _cache[key]
	var is_bed := kind in ["WIND", "TRAFFIC", "INDUSTRIAL", "WATER"]
	var seconds := BED_SECONDS if is_bed else (0.19 if kind.begins_with("STEP") else (0.12 if kind == "UI" else 0.44))
	var frames := roundi(float(RATE) * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var generator := RandomNumberGenerator.new()
	generator.seed = 117293 + kind.hash() * 7 + variation * 5197
	var low_noise := 0.0
	for i in range(frames):
		var t := float(i) / float(RATE)
		var noise := generator.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, noise, 0.011)
		var sample := 0.0
		match kind:
			"WIND":
				# Long lowpass gusts and occasional rooftop whistling.
				var gust := 0.55 + 0.24 * sin(TAU * 0.21 * t) + 0.17 * sin(TAU * 0.37 * t)
				sample = low_noise * gust * 0.34
				sample += 0.0025 * sin(TAU * 143.0 * t) * (0.5 + 0.5 * sin(TAU * 0.14 * t))
			"TRAFFIC":
				# Several distant tire swells, not distinct repeated horn samples.
				var wave := 0.5 + 0.5 * sin(TAU * 0.23 * t)
				var approaching := pow(wave, 4.0)
				sample = low_noise * 0.09 + noise * 0.009 * approaching
				sample += 0.015 * approaching * sin(TAU * (58.0 + 6.0 * sin(TAU * 0.15 * t)) * t)
			"INDUSTRIAL":
				var compressor := 0.5 + 0.5 * sin(TAU * 0.14 * t)
				sample = 0.027 * sin(TAU * 52.0 * t) + 0.009 * sin(TAU * 104.0 * t)
				sample += low_noise * compressor * 0.20 + noise * 0.005
			"WATER":
				var swell := 0.48 + 0.34 * sin(TAU * 0.17 * t) + 0.13 * sin(TAU * 0.37 * t)
				sample = noise * 0.014 * swell + low_noise * 0.26 * swell
			"STEP_CONCRETE", "STEP_TILE":
				var decay := exp(-36.0 * t) * (0.8 + 0.04 * float(variation))
				var heel := noise * 0.135 * decay + sin(TAU * (155.0 + variation * 18.0) * t) * decay * 0.050
				var toe_time := maxf(0.0, t - 0.065)
				var toe := exp(-70.0 * toe_time) * 0.055 * sin(TAU * (380.0 + variation * 25.0) * toe_time) if t > 0.065 else 0.0
				sample = heel + toe
				if kind == "STEP_TILE":
					sample += 0.025 * sin(TAU * 1120.0 * t) * exp(-65.0 * t)
			"DOOR":
				# Motorized latch, seal and the short padded door-close thud.
				var latch_time := maxf(0.0, t - 0.19)
				sample = sin(TAU * (92.0 + 85.0 * t) * t) * exp(-18.0 * t) * 0.095
				if t >= 0.19:
					sample += (noise * 0.11 + low_noise * 0.19) * exp(-34.0 * latch_time)
			"TRANSIT":
				# Short, distinctive two-tone boarding/alighting acknowledgement.
				sample = 0.095 * sin(TAU * 523.25 * t) * exp(-15.0 * t)
				if t > 0.17:
					var note_t := t - 0.17
					sample += 0.10 * sin(TAU * 659.25 * note_t) * exp(-16.0 * note_t)
			"PICKUP":
				sample = 0.10 * sin(TAU * 493.88 * t) * exp(-13.0 * t)
				sample += 0.055 * sin(TAU * 987.77 * t) * exp(-24.0 * t)
			"DELIVERY":
				sample = 0.09 * sin(TAU * 587.33 * t) * exp(-16.0 * t)
				if t > 0.16:
					var complete_t := t - 0.16
					sample += 0.12 * sin(TAU * 880.0 * complete_t) * exp(-12.0 * complete_t)
			"JUMP":
				sample = noise * 0.08 * exp(-25.0 * t)
				sample += 0.055 * sin(TAU * (185.0 + 170.0 * t) * t) * exp(-20.0 * t)
			"LAND":
				sample = (noise * 0.13 + low_noise * 0.25) * exp(-29.0 * t)
				sample += 0.055 * sin(TAU * 91.0 * t) * exp(-24.0 * t)
			"UI":
				sample = 0.055 * sin(TAU * (780.0 - 150.0 * t) * t) * exp(-32.0 * t)
			_:
				return null
		# Edges are continuous even on periodic beds; waveforms are quiet by
		# default, leaving headroom for the creator's NightGrid FM soundtrack.
		var fade_seconds := 0.16 if is_bed else 0.005
		var edge := clampf(minf(t, seconds - t) / fade_seconds, 0.0, 1.0)
		var pcm := clampi(roundi(sample * edge * 32767.0), -32768, 32767)
		var sample_u16 := pcm if pcm >= 0 else pcm + 65536
		data[i * 2] = sample_u16 & 255
		data[i * 2 + 1] = (sample_u16 >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if is_bed else AudioStreamWAV.LOOP_DISABLED
	wav.loop_begin = 0
	wav.loop_end = frames
	wav.data = data
	_cache[key] = wav
	return wav

static func cache_count() -> int:
	return _cache.size()
