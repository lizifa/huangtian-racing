extends Node
## 近景拍玩家车：从侧后方 + 正后方各拍一张，用来确认车头车尾朝向和排气管位置。

func _shot(tag: String, offset: Vector3, look_offset: Vector3) -> void:
	var packed: PackedScene = load("res://scenes/race.tscn")
	var scene: Node = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout   # 等开屏淡出，不然拍到的是 splash
	for i in 4:
		await get_tree().process_frame
	var player: RaceCar = scene.get("player")
	var cam: Camera3D = scene.get("camera")
	var fwd := Vector3(sin(player.yaw), 0.0, cos(player.yaw))
	cam.fov = 42.0
	cam.position = player.position + fwd * offset.z + Vector3(0, offset.y, 0) + Vector3(-fwd.z, 0, fwd.x) * offset.x
	cam.look_at(player.position + look_offset)
	for i in 6:
		await get_tree().process_frame
	print(tag, " saved=", get_viewport().get_texture().get_image().save_png("res://shots/car_%s.png" % tag))
	scene.queue_free()
	await get_tree().process_frame

func _ready() -> void:
	await _shot("side", Vector3(3.2, 1.6, -3.0), Vector3(0, 0.5, 0))
	await _shot("rear", Vector3(0.0, 1.4, -4.2), Vector3(0, 0.5, 0))
	get_tree().quit()
