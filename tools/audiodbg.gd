extends Node

func _ready() -> void:
	var scene: Node = load("res://scenes/race.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout
	var pl: RaceCar = scene.get("player")
	print("audio_on=", pl.audio_on)
	print("engine_player=", pl.engine_player, " nitro=", pl.nitro_player, " crash=", pl.crash_player)
	if pl.engine_player != null:
		var st: AudioStreamWAV = pl.engine_player.stream
		print("eng stream=", st, " data=", st.data.size() if st != null else -1,
			" vol=", pl.engine_player.volume_db, " playing=", pl.engine_player.playing)
	pl.started = true
	pl.throttle = 1.0
	for i in 30:
		await get_tree().physics_frame
	print("after drive: eng playing=", pl.engine_player.playing,
		" pitch=", pl.engine_player.pitch_scale, " vol=", pl.engine_player.volume_db,
		" spd=", pl.speed)
	var ui: AudioStreamPlayer = scene.get("ui_player")
	print("ui_player=", ui, " stream=", ui.stream if ui != null else null)
	if ui != null:
		ui.play()
		await get_tree().process_frame
		print("ui playing=", ui.playing)
	get_tree().quit()
