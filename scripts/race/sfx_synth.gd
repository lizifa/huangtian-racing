class_name SfxSynth
extends RefCounted
## 卡通轻快低模风格音效：全部在代码里合成 PCM16 缓冲，不依赖外部音频文件，
## 无授权风险。引擎/氮气为循环缓冲，撞击/点击为一次性短音。

const RATE := 22050

static func _pcm16(samples: Array, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = clampi(int(round(samples[i] * 32767.0)), -32768, 32767)
		bytes[i * 2] = v & 0xff
		bytes[i * 2 + 1] = (v >> 8) & 0xff
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

## 引擎循环：三角波 + 轻方波叠加，带活塞节奏门控；播放时用 pitch_scale 随车速变调。
static func engine_loop() -> AudioStreamWAV:
	var dur := 1.2
	var n := int(RATE * dur)
	var sm: Array = []
	var f0 := 96.0
	for i in n:
		var t: float = float(i) / RATE
		var gate: float = 0.6 + 0.4 * sin(TAU * 7.0 * t)
		var ph: float = f0 * t - floor(f0 * t)
		var tri: float = 2.0 * abs(2.0 * ph - 1.0) - 1.0
		var sq: float = 1.0 if sin(TAU * f0 * t) >= 0.0 else -1.0
		var s: float = (0.55 * tri + 0.22 * sq) * gate
		sm.append(clampf(s * 0.5, -1.0, 1.0))
	return _pcm16(sm, true)

## 氮气风啸循环：低通白噪，带轻微起伏。
static func nitro_loop() -> AudioStreamWAV:
	var dur := 1.4
	var n := int(RATE * dur)
	var sm: Array = []
	var prev: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var white: float = randf() * 2.0 - 1.0
		prev = prev * 0.7 + white * 0.3
		var amp: float = 0.5 + 0.3 * sin(TAU * 18.0 * t)
		sm.append(clampf(prev * amp * 0.8, -1.0, 1.0))
	return _pcm16(sm, true)

## 撞击闷击：噪声 + 低频下坠，按撞击强度调音量/音高。
static func crash() -> AudioStreamWAV:
	var dur := 0.22
	var n := int(RATE * dur)
	var sm: Array = []
	for i in n:
		var t: float = float(i) / RATE
		var env: float = exp(-t * 14.0)
		var noise: float = randf() * 2.0 - 1.0
		var thump: float = sin(TAU * (120.0 - 60.0 * t) * t)
		var s: float = env * (0.6 * noise + 0.5 * thump)
		sm.append(clampf(s, -1.0, 1.0))
	return _pcm16(sm, false)

## UI 短提示音：短促上扫 blip。
static func ui_click() -> AudioStreamWAV:
	var dur := 0.08
	var n := int(RATE * dur)
	var sm: Array = []
	for i in n:
		var t: float = float(i) / RATE
		var env: float = exp(-t * 30.0)
		var f: float = 700.0 - 300.0 * t
		var s: float = env * sin(TAU * f * t) * 0.6
		sm.append(clampf(s, -1.0, 1.0))
	return _pcm16(sm, false)
