extends Node3D
func _ready() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 26.0
	cam.position = Vector3(8, 30, -1.0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	add_child(cam)
	cam.current = true
	var names := ["roadStraight", "roadCornerLarge", "roadCornerSmall", "roadStart"]
	var xs := [0.0, 4.0, 8.0, 12.0]
	var rots := [0.0, 0.0, 90.0, 180.0]
	for i in names.size():
		var m: Node3D = load("res://assets/kit/%s.glb" % names[i]).instantiate()
		m.position = Vector3(xs[i], 0, 4.0)
		m.rotation_degrees.y = rots[i]
		add_child(m)
	# 四个大弯，分别转 0/90/180/270 看朝向
	for i in 4:
		var c: Node3D = load("res://assets/kit/roadCornerLarge.glb").instantiate()
		c.position = Vector3(i * 4.0, 0, -4.0)
		c.rotation_degrees.y = i * 90.0
		add_child(c)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.3
	add_child(light)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b0d2dd")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d5e3ea")
	env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 40)
	ground.mesh = pm
	ground.position = Vector3(8, -0.02, 0)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("2f4f4f")
	ground.material_override = mat
	add_child(ground)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("saved=", get_viewport().get_texture().get_image().save_png("/tmp/probe.png"))
	get_tree().quit()
