extends Node
## 车尾双排气口特写：复用主场景 current 相机，车停发车格，正后方近景固定机位。

var scene: Node
var player: RaceCar
var cam: Camera3D

func _frame_car() -> void:
	var fwd := Vector3(sin(player.yaw), 0.0, cos(player.yaw))
	cam.fov = 32.0
	cam.position = player.position - fwd * 1.9 + Vector3(0, 0.45, 0)
	cam.look_at(player.position + Vector3(0, 0.15, 0))

func _ready() -> void:
	scene = load("res://scenes/race.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(6.6).timeout
	player = scene.get("player")
	cam = scene.get("camera")
	player.started = true
	player.speed = 0.0
	for fx in player.exhausts:
		fx.set_drive(1.0, 8.0, false, false)
	for i in player.exhausts.size():
		var fx: CPUParticles3D = player.exhausts[i]
		print("exhaust[", i, "] local=", fx.position, " global=", fx.global_position.snapped(Vector3.ONE * 0.01),
			" emitting=", fx.emitting)
	print("car pos=", player.global_position.snapped(Vector3.ONE*0.01), " yaw=", round(player.yaw*100)/100)
	for i in 40:
		_frame_car()
		await get_tree().process_frame
	print("shot=", get_viewport().get_texture().get_image().save_png("res://shots/exhaust_rear.png"))
	get_tree().quit()
