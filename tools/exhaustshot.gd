extends Node
## 跑起来拍一张：确认尾气（怠速 / 油门 / 氮气）在画面上真的看得见。

var scene: Node
var player: RaceCar
var cam: Camera3D

func _frame_car(side: float, back: float, up: float, look_up: float) -> void:
	var fwd := Vector3(sin(player.yaw), 0.0, cos(player.yaw))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	cam.fov = 46.0
	cam.position = player.position - fwd * back + right * side + Vector3(0, up, 0)
	cam.look_at(player.position + Vector3(0, look_up, 0))

func _drive(frames: int) -> void:
	for i in frames:
		_frame_car(0.0, 3.2, 1.2, 0.3)
		await get_tree().process_frame

func _ready() -> void:
	scene = load("res://scenes/race.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(6.6).timeout   # splash + 倒计时
	player = scene.get("player")
	cam = scene.get("camera")
	# 摇杆推满：throttle = 1，车自己往前开
	scene.get("joystick").active = true
	var js = scene.get("joystick")
	js._update_from(js.size * 0.5 + Vector2(0.0, -js.radius * 0.62))
	await _drive(70)
	var ex0 = player.exhausts[0]
	print("[drive] speed=", snapped(player.speed, 0.1), " exhaust emitting=", ex0.emitting,
		" pos=", ex0.position, " scale_max=", snapped(ex0.scale_amount_max, 0.01))
	print("shot drive=", get_viewport().get_texture().get_image().save_png("res://shots/exhaust_drive.png"))
	# 氮气爆发
	scene.get("pads")["nitro"].press(9)
	await _drive(24)
	print("[nitro] speed=", snapped(player.speed, 0.1), " nitro_time=", snapped(player.nitro_time, 0.01),
		" fuel=", snapped(player.boost_fuel, 0.01), " scale_max=", snapped(ex0.scale_amount_max, 0.01))
	print("shot nitro=", get_viewport().get_texture().get_image().save_png("res://shots/exhaust_nitro.png"))
	scene.get("pads")["nitro"].release(9)
	get_tree().quit()
