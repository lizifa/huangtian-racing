extends Node
## 主场景侧上方近景：核对玩家车座舱里的低模驾驶员位置、不穿模。

var scene: Node
var player: RaceCar
var cam: Camera3D

func _ready() -> void:
	scene = load("res://scenes/race.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(6.6).timeout
	player = scene.get("player")
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()
	player.started = true
	print("player pos=", player.position.snapped(Vector3.ONE*0.01), " yaw=", snapped(player.yaw, 0.02))
	for i in 40:
		var fwd := Vector3(sin(player.yaw), 0.0, cos(player.yaw))
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		cam.fov = 40.0
		cam.position = player.position + right * 1.5 + Vector3(0, 1.25, 0) - fwd * 0.35
		cam.look_at(player.position + Vector3(0, 0.3, -0.2))
		await get_tree().process_frame
	for m in player.model.find_children("*", "MeshInstance3D", true, false):
		print("mesh=", m.name, " pos=", m.position.snapped(Vector3.ONE*0.01))
	print("shot=", get_viewport().get_texture().get_image().save_png("res://shots/driver_main.png"))
	get_tree().quit()
