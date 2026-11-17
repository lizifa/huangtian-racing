extends Node3D
## 静态车尾特写：只摆车模 + 双管口 + 双粒子，相机按模型真实 AABB 对准正后方。

const PIPES := [Vector3(-0.54, 0.09, -1.36), Vector3(-0.16, 0.09, -1.36)]

func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("7fb8d8")
	sky_mat.sky_horizon_color = Color("dcf0f7")
	sky_mat.ground_bottom_color = Color("4b7a34")
	sky_mat.ground_horizon_color = Color("cfe6f0")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dceaf0")
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_energy = 1.25
	sun.light_color = Color("fff4e2")
	add_child(sun)

	var packed: PackedScene = load("res://assets/kit/raceCarRed.glb")
	var model := packed.instantiate()
	model.scale = Vector3.ONE * 1.9
	add_child(model)

	var ExhaustScript := load("res://scripts/race/exhaust_fx.gd")
	for local in PIPES:
		var fx: CPUParticles3D = ExhaustScript.new()
		fx.position = local
		fx.set_drive(1.0, 8.0, false, false)
		model.add_child(fx)
		_add_pipe(model, local)

	await get_tree().process_frame

	# 合并模型全局 AABB
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for mi in model.find_children("*", "MeshInstance3D"):
		var m: MeshInstance3D = mi
		var a: AABB = m.get_aabb()
		var g: Transform3D = m.global_transform
		for k in range(8):
			var c: Vector3 = g * a.get_endpoint(k)
			lo = lo.min(c)
			hi = hi.max(c)
	print("AABB lo=", lo.snapped(Vector3.ONE*0.01), " hi=", hi.snapped(Vector3.ONE*0.01))
	var center := (lo + hi) * 0.5

	var cam := Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	# 车尾在本地 -Z，相机站在 -Z 一侧
	cam.position = center + Vector3(0, 0.05, -(hi.z - lo.z) * 1.6)
	cam.look_at(center)
	cam.make_current()

	for i in 30:
		await get_tree().process_frame
	print("shot=", get_viewport().get_texture().get_image().save_png("res://shots/car_rear_still.png"))
	get_tree().quit()

func _add_pipe(model: Node3D, local: Vector3) -> void:
	var node := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.055
	cyl.height = 0.12
	cyl.radial_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.13)
	mat.roughness = 0.6
	cyl.material = mat
	node.mesh = cyl
	node.rotation.x = PI / 2.0
	node.position = local + Vector3(0, 0, -0.03)
	model.add_child(node)
