extends Node
## 刚体碰撞探针：跑若干物理帧，统计车车间距最小值、车身侧翻角、碰撞掉速情况。

var scene: Node
var cars: Array = []

func _dump_phys(n: Node, indent: String) -> void:
	var cls := n.get_class()
	if cls.ends_with("Body3D") or cls.ends_with("Shape3D") or cls.begins_with("Collision"):
		print(indent, cls, " ", n.name)
	for c in n.get_children():
		_dump_phys(c, indent + "  ")

func _ready() -> void:
	scene = load("res://scenes/race.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout
	cars = scene.get("cars")
	for c in cars:
		c.started = true
		c.is_ai = true   # 探针里四辆车都按 AI 跑，便于观察车车逼近与碰撞
	for n in cars[0].get_children():
		_dump_phys(n, "  ")
	if OS.get_environment("ONE_CAR") == "1":
		for i in range(1, cars.size()):
			cars[i].queue_free()
		cars = [cars[0]]
		print("one car only")
	if OS.get_environment("NO_STATIC") == "1":
		for n in scene.find_children("*", "StaticBody3D", true, false):
			n.set_deferred("collision_layer", 0)
		print("static bodies disabled")

	## 对照 2：项目脚本类型的裸车，固定 speed/yaw，不经主场景 step 驱动。
	var probe_car := RaceCar.new()
	probe_car._setup_body()
	probe_car.started = true
	probe_car.speed = 8.0
	probe_car.yaw = 0.0
	add_child(probe_car)
	probe_car.position = cars[0].position + Vector3(-4, 0, 0)

	## 对照：在项目场景里放一个裸刚体，外部喂速度，看项目物理世界是否正常积分。
	var probe_rb := RigidBody3D.new()
	var pshape := CollisionShape3D.new()
	var pbox := BoxShape3D.new()
	pbox.size = Vector3(1, 1, 1)
	pshape.shape = pbox
	probe_rb.add_child(pshape)
	add_child(probe_rb)
	probe_rb.position = cars[0].position + Vector3(2, 0, 0)

	var min_gap := INF
	var max_tilt := 0.0
	var crash_cars := 0
	var max_push := 0.0
	var max_lat := 0.0
	var max_kick := 0.0
	var max_lose := 0.0
	for i in 420:
		await get_tree().physics_frame
		probe_rb.linear_velocity = Vector3(8, 0, 0)
		if i % 60 == 0:
			print("probe_rb pos=", probe_rb.position.snapped(Vector3.ONE * 0.01),
				" probe_car pos=", probe_car.position.snapped(Vector3.ONE * 0.01),
				" pc_vel=", probe_car.linear_velocity.snapped(Vector3.ONE * 0.1))
		if OS.get_environment("FORCE_VEL") == "1":
			for c in cars:
				c.linear_velocity = Vector3(10, 0, 0)
		for c in cars:
			max_tilt = maxf(max_tilt, maxf(absf(c.rotation.x), absf(c.rotation.z)))
			if c.crash_impact > 0.3:
				crash_cars += 1
			max_push = maxf(max_push, c.hit_push)
			max_lat = maxf(max_lat, absf(c.lateral_v))
			max_kick = maxf(max_kick, absf(c.yaw_kick))
			max_lose = maxf(max_lose, c.lose_control)
		for ai in cars.size():
			for bi in range(ai + 1, cars.size()):
				min_gap = minf(min_gap, cars[ai].position.distance_to(cars[bi].position))
		if i % 60 == 0:
			for c in cars:
				print(i, " class=", c.get_class(), " isRB=", c is RigidBody3D,
					" spd=", snapped(c.speed, 0.1), " freeze=", c.freeze,
					" sleep=", c.is_sleeping(),
					" vel=", c.linear_velocity.snapped(Vector3.ONE * 0.1),
					" pos=", c.position.snapped(Vector3.ONE * 0.1))
	print("=== min_gap=", snapped(min_gap, 0.01), " max_tilt=", snapped(max_tilt, 0.001),
		" crash_frames=", crash_cars,
		" max_push=", snapped(max_push, 0.1), " max_lat=", snapped(max_lat, 0.1),
		" max_kick=", snapped(max_kick, 0.1), " max_lose=", snapped(max_lose, 0.1))
	get_tree().quit()
