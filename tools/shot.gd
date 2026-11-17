extends Node
func _ready() -> void:
	var packed: PackedScene = load("res://scenes/race.tscn")
	var scene: Node = packed.instantiate()
	add_child(scene)
	for i in 6:
		await get_tree().process_frame
	var view := OS.get_environment("SHOT_VIEW")
	if view == "wide":
		var cam: Camera3D = scene.get("camera")
		cam.position = Vector3(0, 62, 52)
		cam.look_at(Vector3(0, 0, 0))
	elif view == "top":
		var cam2: Camera3D = scene.get("camera")
		cam2.position = Vector3(0, 70, 0.1)
		cam2.look_at(Vector3(0, 0, 0))
	elif view == "debug":
		var cam3: Camera3D = scene.get("camera")
		var pl: RaceCar = scene.get("player")
		print("player pos=", pl.position, " yaw=", pl.yaw)
		print("cam pos=", cam3.position)
		cam3.position = pl.position + Vector3(0, 10, 0)
		cam3.look_at(pl.position)
		print("cam after=", cam3.global_position, " rot=", cam3.global_rotation)
	elif view == "chase":
		# 让玩家车跑一小段，看追尾镜头
		var player: RaceCar = scene.get("player")
		player.started = true
		player.throttle = 1.0
		for i in 90:
			player.step(1.0 / 60.0, 0.0)
			await get_tree().process_frame
	var camX: Camera3D = scene.get("camera")
	var plX: RaceCar = scene.get("player")
	print("final player=", plX.position, " yaw=", plX.yaw, " speed=", plX.speed)
	print("final cam=", camX.global_position, " rot=", camX.global_rotation)
	for i in 4:
		await get_tree().process_frame
	print("shot=", get_viewport().get_texture().get_image().save_png("res://shots/race_%s.png" % ("chase" if view == "" else view)))
	get_tree().quit()
