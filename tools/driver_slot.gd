extends Node3D
## 定位座舱：实例化红车，打印各 mesh 本地/全局 AABB，侧后方近景截图。

var model: Node3D

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
	model = packed.instantiate()
	model.scale = Vector3.ONE * 1.9
	add_child(model)

	await get_tree().process_frame
	await get_tree().process_frame

	# 占位驾驶员挂到 body 节点下，与车身顶点同一本地坐标系
	var body_node: Node3D = model.find_children("body", "MeshInstance3D", true, false)[0]
	var helmet := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.085
	hs.height = 0.17
	hs.radial_segments = 12
	hs.rings = 8
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.95, 0.55, 0.12)
	hm.roughness = 0.5
	helmet.mesh = hs
	helmet.material_override = hm
	helmet.position = Vector3(0.305, 0.24, -0.48)
	body_node.add_child(helmet)

	# 黑色面罩：贴头盔朝前（+Z）一侧
	var visor := MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.10, 0.06, 0.04)
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color(0.05, 0.05, 0.06)
	vm.roughness = 0.3
	visor.mesh = vb
	visor.material_override = vm
	visor.position = Vector3(0.305, 0.25, -0.40)
	body_node.add_child(visor)

	var torso := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.20, 0.18, 0.22)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.18, 0.18, 0.20)
	tm.roughness = 0.7
	torso.mesh = tb
	torso.material_override = tm
	torso.position = Vector3(0.305, 0.13, -0.52)
	body_node.add_child(torso)

	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for mi in model.find_children("*", "MeshInstance3D"):
		var m: MeshInstance3D = mi
		var a: AABB = m.get_aabb()
		print("mesh=", m.name, " local_aabb=", a.position.snapped(Vector3.ONE*0.01),
			" size=", a.size.snapped(Vector3.ONE*0.01))
		var g: Transform3D = m.global_transform
		for k in range(8):
			var c: Vector3 = g * a.get_endpoint(k)
			lo = lo.min(c)
			hi = hi.max(c)
	print("GLOBAL lo=", lo.snapped(Vector3.ONE*0.01), " hi=", hi.snapped(Vector3.ONE*0.01))
	var center := (lo + hi) * 0.5

	# 打印 body 顶点按 z 分桶的 y 范围，找座舱凹槽（上沿下凹处）
	for mi in model.find_children("*", "MeshInstance3D"):
		var m: MeshInstance3D = mi
		if m.name != "body":
			continue
		var arr: Array = m.mesh.surface_get_arrays(0)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var buckets := {}
		for v in pos:
			var k := snappedf(v.z, 0.1)
			if not buckets.has(k):
				buckets[k] = [v.y, v.y, v.x, v.x]
			buckets[k][0] = minf(buckets[k][0], v.y)
			buckets[k][1] = maxf(buckets[k][1], v.y)
			buckets[k][2] = minf(buckets[k][2], v.x)
			buckets[k][3] = maxf(buckets[k][3], v.x)
		var ks := buckets.keys()
		ks.sort()
		for k in ks:
			var b = buckets[k]
			print("body z=%.1f y[%.2f,%.2f] x[%.2f,%.2f]" % [k, b[0], b[1], b[2], b[3]])

	var cam := Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	# 侧后方 45° 近景
	cam.position = center + Vector3(2.6, 0.7, -1.4)
	cam.look_at(center)
	cam.make_current()

	for i in 30:
		await get_tree().process_frame
	print("shot=", get_viewport().get_texture().get_image().save_png("res://shots/driver_slot.png"))
	get_tree().quit()
