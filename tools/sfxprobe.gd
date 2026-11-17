extends Node

func _ready() -> void:
	var pairs := [["engine", SfxSynth.engine_loop()], ["nitro", SfxSynth.nitro_loop()],
		["crash", SfxSynth.crash()], ["ui", SfxSynth.ui_click()]]
	for pair in pairs:
		var st: AudioStreamWAV = pair[1]
		print(pair[0], " samples=", st.data.size() / 2, " rate=", st.mix_rate, " loop=", st.loop_mode)
	print("sfx probe ok")
	get_tree().quit()
