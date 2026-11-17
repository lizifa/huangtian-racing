extends Node3D
## 侧撞定向测试：B 从右侧横撞直行的 A，验证 A 注入横向滑速 + 偏航扰动 + 短暂失控，
## 且不侧翻、不打转、冲量在封顶内。

var a: RaceCar
var b: RaceCar
var max_lat := 0.0
var max_kick := 0.0
var max_lose := 0.0
var max_tilt := 0.0
var yaw0 := 0.0

func _ready() -> void:
	var ground := StaticBody3D.new()
	var gshape := CollisionShape3D.new()
	gshape.shape = WorldBoundaryShape3D.new()
	ground.add_child(gshape)
	add_child(ground)

	a = RaceCar.new()
	add_child(a)
	a._setup_body()
	a.started = true
	a.speed = 8.0
	a.yaw = 0.0
	a.position = Vector3(0, 0, 0)
	yaw0 = a.yaw

	b = RaceCar.new()
	add_child(b)
	b._setup_body()
	b.started = true
	b.speed = 6.0
	b.yaw = -PI / 2.0   # 朝 -X 横顶 A 右侧
	b.position = Vector3(1.15, 0, 0)

	var dt := 1.0 / 60.0
	for i in 150:
		await get_tree().physics_frame
		for c in [a, b]:
			c.hit_push = maxf(0.0, c.hit_push - RaceCar.PUSH_DECAY * dt)
			c.lateral_v = maxf(0.0, absf(c.lateral_v) - RaceCar.LATERAL_DAMP * dt) * signf(c.lateral_v)
			c.yaw_kick = maxf(0.0, absf(c.yaw_kick) - RaceCar.KICK_DECAY * dt) * signf(c.yaw_kick)
			c.lose_control = maxf(0.0, c.lose_control - dt)
		max_tilt = maxf(max_tilt, maxf(absf(a.rotation.x), absf(a.rotation.z)))
		max_lat = maxf(max_lat, absf(a.lateral_v))
		max_kick = maxf(max_kick, absf(a.yaw_kick))
		max_lose = maxf(max_lose, a.lose_control)
		if i % 15 == 0:
			print(i, " A spd=", snapped(a.speed, 0.1), " yaw=", snapped(a.yaw, 0.02),
				" lat=", snapped(a.lateral_v, 0.1), " kick=", snapped(a.yaw_kick, 0.1),
				" lose=", snapped(a.lose_control, 0.1), " pos=", a.position.snapped(Vector3.ONE * 0.1))
	print("=== A max_lat=", snapped(max_lat, 0.1), " max_kick=", snapped(max_kick, 0.1),
		" max_lose=", snapped(max_lose, 0.1), " max_tilt=", snapped(max_tilt, 0.001),
		" yaw_drift=", snapped(wrapf(a.yaw - yaw0, -PI, PI), 0.02))
	get_tree().quit()
