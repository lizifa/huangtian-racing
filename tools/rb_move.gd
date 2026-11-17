extends Node3D
## 护栏阻挡定向测试：车朝一道静态墙开，验证被挡住、不穿透。

var rb: RaceCar

func _ready() -> void:
	# 地面
	var ground := StaticBody3D.new()
	var gshape := CollisionShape3D.new()
	gshape.shape = WorldBoundaryShape3D.new()
	ground.add_child(gshape)
	add_child(ground)
	# 静态墙，放在 x=3.0
	var wall := StaticBody3D.new()
	wall.collision_layer = RaceCar.COL_LAYER_STATIC
	var wshape := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(0.2, 1.0, 6.0)
	wshape.shape = wbox
	wshape.position = Vector3(3.0, 0.5, 0)
	wall.add_child(wshape)
	add_child(wall)

	rb = RaceCar.new()
	add_child(rb)
	rb._setup_body()
	rb.started = true
	rb.speed = 10.0
	rb.yaw = PI / 2.0   # 朝 +X 撞墙
	rb.position = Vector3(0, 0, 0)
	for i in 60:
		await get_tree().physics_frame
		if i % 10 == 0:
			print(i, " pos=", rb.position.snapped(Vector3.ONE * 0.01),
				" vel=", rb.linear_velocity.snapped(Vector3.ONE * 0.1))
	print("=== final x=", snapped(rb.position.x, 0.01), " (墙在 x=3.0，盒半宽 0.625，应停在 x<2.4)")
	get_tree().quit()
