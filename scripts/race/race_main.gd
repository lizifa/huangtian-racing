extends Node3D
## 荒田狂飙：Kenney Racing Kit 素材搭的环形赛道竞速。

const LAPS := 3
const PLAYER_COLOR := "red"
const AI_COLORS := ["green", "orange", "white"]
const ROAD_Y := 0.03

var path: RacePath
var player: RaceCar
var rivals: Array[RaceCar] = []
var cars: Array[RaceCar] = []
var camera: Camera3D
var hud: CanvasLayer
var lbl_lap: Label
var lbl_time: Label
var lbl_best: Label
var lbl_assist: Label
var lbl_speed: Label
var lbl_count: Label
var lbl_result: Label
var btn_restart: Control
var ui_player: AudioStreamPlayer
var pads := {}
var joystick: Control
var joy_steer := 0.0
var joy_throttle := 0.0
var joy_brake := 0.0
var _touch_map := {}   ## 触点 index -> "joy" / 技能键名（集中式分发用）
var race_time := 0.0
var countdown := 4.0
var state := "countdown"
var finish_rank := 0
var splash_hold := 0.3
var cam_far := false
var _prev_reset := false
var _prev_view := false
var _static_props: Array = []   ## 待下一帧按世界网格 AABB 生成静态阻挡盒的道具

func _ready() -> void:
	randomize()
	_build_environment()
	path = RacePath.new(1.0)
	_build_ground()
	_build_road()
	_build_props()
	_build_cars()
	_build_camera()
	_build_hud()
	# 品牌启动图由 Godot boot splash 在引擎阶段展示，主场景不再重复叠整屏，缩短进入等待
	# 道具进树后再按世界网格 AABB 生成静态阻挡盒（需 global_transform 就绪）
	await get_tree().process_frame
	_build_static_bodies()

func _show_splash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var tr := TextureRect.new()
	tr.texture = load("res://assets/splash.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	tr.offset_right = 0.0
	tr.offset_bottom = 0.0
	layer.add_child(tr)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(tr, "modulate:a", 0.0, 0.45)
	tw.tween_callback(layer.queue_free)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("7fb8d8")
	sky_mat.sky_horizon_color = Color("dcf0f7")
	sky_mat.ground_bottom_color = Color("4b7a34")
	sky_mat.ground_horizon_color = Color("cfe6f0")
	sky_mat.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dceaf0")
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.4
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.1
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_energy = 1.25
	sun.light_color = Color("fff4e2")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	# 低模色块靠斜投影立形，阴影别硬
	sun.shadow_blur = 1.5
	add_child(sun)

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(340, 340)
	ground.mesh = plane
	ground.position = Vector3(0, -0.02, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5f8f38").srgb_to_linear()
	mat.roughness = 1.0
	ground.material_override = mat
	ground.name = "Ground"
	add_child(ground)
	# 地面静态碰撞：托住刚体，防止车掉出世界
	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = RaceCar.COL_LAYER_STATIC
	ground_body.collision_mask = 0
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = WorldBoundaryShape3D.new()
	ground_body.add_child(ground_shape)
	add_child(ground_body)

func _road_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path.points.size() - 1
	var half := RacePath.ROAD_HALF
	for i in n:
		var p0: Vector3 = path.points[i]
		var p1: Vector3 = path.points[i + 1]
		var t0: Vector3 = path.tangents[i]
		var t1: Vector3 = path.tangents[i + 1]
		var s0 := Vector3(-t0.z, 0, t0.x)
		var s1 := Vector3(-t1.z, 0, t1.x)
		_quad(st,
			p0 + s0 * half + Vector3(0, ROAD_Y, 0), p0 - s0 * half + Vector3(0, ROAD_Y, 0),
			p1 - s1 * half + Vector3(0, ROAD_Y, 0), p1 + s1 * half + Vector3(0, ROAD_Y, 0),
			Color("3b3b40").srgb_to_linear())
		# 红白路肩
		var curb_col := Color("b0362c").srgb_to_linear() if int(float(i) / 2.0) % 2 == 0 else Color("efe7d6").srgb_to_linear()
		_quad(st, p0 + s0 * (half + 0.9) + Vector3(0, ROAD_Y + 0.005, 0), p0 + s0 * half + Vector3(0, ROAD_Y + 0.005, 0),
			p1 + s1 * half + Vector3(0, ROAD_Y + 0.005, 0), p1 + s1 * (half + 0.9) + Vector3(0, ROAD_Y + 0.005, 0), curb_col)
		var curb_col2 := Color("efe7d6").srgb_to_linear() if int(float(i) / 2.0) % 2 == 0 else Color("b0362c").srgb_to_linear()
		_quad(st, p0 - s0 * half + Vector3(0, ROAD_Y + 0.005, 0), p0 - s0 * (half + 0.9) + Vector3(0, ROAD_Y + 0.005, 0),
			p1 - s1 * (half + 0.9) + Vector3(0, ROAD_Y + 0.005, 0), p1 - s1 * half + Vector3(0, ROAD_Y + 0.005, 0), curb_col2)
		# 中线虚线：3 实 4 空
		var seg := 1.0
		var cycle := 7.0
		if fposmod(float(i) * seg, cycle) < 3.0:
			_quad(st, p0 + s0 * 0.12 + Vector3(0, ROAD_Y + 0.01, 0), p0 - s0 * 0.12 + Vector3(0, ROAD_Y + 0.01, 0),
				p1 - s1 * 0.12 + Vector3(0, ROAD_Y + 0.01, 0), p1 + s1 * 0.12 + Vector3(0, ROAD_Y + 0.01, 0), Color("e8e2cf").srgb_to_linear())
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.name = "RoadMesh"
	add_child(mi)

func _build_road() -> void:
	_road_mesh()
	_build_start_line()

func _build_start_line() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 2
	var cols := 10
	var half := RacePath.ROAD_HALF
	var depth := 2.4
	for r in rows:
		for c in cols:
			var t0 := float(r) / float(rows)
			var t1 := float(r + 1) / float(rows)
			var u0 := -half + float(c) / float(cols) * half * 2.0
			var u1 := -half + float(c + 1) / float(cols) * half * 2.0
			var col := Color("efeee6").srgb_to_linear() if (r + c) % 2 == 0 else Color("24262a").srgb_to_linear()
			var info0 := path.at(0.0)
			var p: Vector3 = info0[0]
			var d: Vector3 = info0[1]
			var side := Vector3(-d.z, 0, d.x)
			_quad(st,
				p + d * (t0 * depth) + side * u0 + Vector3(0, ROAD_Y + 0.02, 0),
				p + d * (t0 * depth) + side * u1 + Vector3(0, ROAD_Y + 0.02, 0),
				p + d * (t1 * depth) + side * u1 + Vector3(0, ROAD_Y + 0.02, 0),
				p + d * (t1 * depth) + side * u0 + Vector3(0, ROAD_Y + 0.02, 0), col)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(color)
		st.set_normal(Vector3.UP)
		st.add_vertex(v)
	# 法线统一朝上

## Kenney 的 glTF 色值按 sRGB 存进来时会被引擎当线性用，整体偏白偏淡，
## 这里统一按 sRGB 解释一遍，色块才立得住。
func _fix_kit_colors(node: Node, tint: Color = Color.WHITE) -> void:
	var local: Color = node.get_meta("kit_tint", tint)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				var src := mi.get_active_material(i)
				if src is StandardMaterial3D:
					var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					m.albedo_color = (m.albedo_color.srgb_to_linear() * local)
					mi.set_surface_override_material(i, m)
	for c in node.get_children():
		_fix_kit_colors(c, local)

## 赛道上摆 Kenney 的护墙、看台、旗子、树，全部按 kit 的 1 单位尺度。
func _build_props() -> void:
	var barrier_scenes := ["barrierRed", "barrierWhite"]
	var step := 3.2
	var s := 0.0
	var idx := 0
	while s < path.total:
		var info := path.at(s)
		var p: Vector3 = info[0]
		var d: Vector3 = info[1]
		var side := Vector3(-d.z, 0, d.x)
		for flip in [-1.0, 1.0]:
			if idx % 2 == 1 and flip < 0.0:
				pass
			var m: Node3D = load("res://assets/kit/%s.glb" % barrier_scenes[idx % 2]).instantiate()
			m.position = p + side * (RacePath.ROAD_HALF + 1.35) * flip + Vector3(0, 0.0, 0)
			m.rotation.y = atan2(d.x, d.z)
			m.scale = Vector3.ONE * step
			_attach_static_box(m, Vector3(0.12, 0.20, 0.36), Vector3(0, 0.10, 0))
			add_child(m)
		s += step
		idx += 1

	# 起终点：两侧格子旗 + 看台
	for flip in [-1.0, 1.0]:
		var flag: Node3D = load("res://assets/kit/flagCheckers.glb").instantiate()
		var info := path.at(0.0)
		var side := Vector3(-info[1].z, 0, info[1].x)
		flag.position = info[0] + side * (RacePath.ROAD_HALF + 1.8) * flip
		flag.scale = Vector3.ONE * 4.0
		_attach_static_box(flag, Vector3(0.06, 0.42, 0.06), Vector3(0, 0.42, 0))
		add_child(flag)
	for spot in [0.06, 0.14, 0.22, 0.55]:
		var info := path.at(path.total * spot)
		var side := Vector3(-info[1].z, 0, info[1].x)
		var stand: Node3D = load("res://assets/kit/grandStand.glb").instantiate()
		stand.position = info[0] + side * (RacePath.ROAD_HALF + 13.0) + Vector3(0, 0, 0)
		stand.rotation.y = atan2(info[1].x, info[1].z) + PI
		stand.scale = Vector3.ONE * 4.0
		stand.set_meta("kit_tint", Color(0.78, 0.77, 0.73))
		_attach_static_box(stand, Vector3(0.55, 0.40, 0.55), Vector3(0, 0.40, 0))
		add_child(stand)
		var stand2: Node3D = load("res://assets/kit/grandStandCovered.glb").instantiate()
		stand2.position = info[0] - side * (RacePath.ROAD_HALF + 13.0)
		stand2.rotation.y = atan2(info[1].x, info[1].z)
		stand2.scale = Vector3.ONE * 4.0
		stand2.set_meta("kit_tint", Color(0.78, 0.77, 0.73))
		_attach_static_box(stand2, Vector3(0.55, 0.40, 0.55), Vector3(0, 0.40, 0))
		add_child(stand2)

	# 外圈树，挡住地平线但不挡赛道
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		var ang := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(52.0, 90.0)
		var tree_name := "treeLarge" if i % 3 != 0 else "treeSmall"
		var tree: Node3D = load("res://assets/kit/%s.glb" % tree_name).instantiate()
		tree.position = Vector3(cos(ang) * radius * 1.15, 0, sin(ang) * radius * 0.9)
		tree.rotation.y = rng.randf_range(0.0, TAU)
		tree.scale = Vector3.ONE * rng.randf_range(4.0, 7.5)
		_attach_static_box(tree, Vector3(0.14, 0.32, 0.14), Vector3(0, 0.32, 0))
		add_child(tree)

func _build_cars() -> void:
	# 发车格：起终点线后 8~20 米，左右错开
	var grid := [
		{"s": path.total - 7.0, "off": 1.7, "color": "red", "ai": false},
		{"s": path.total - 10.5, "off": -1.7, "color": "green", "ai": true},
		{"s": path.total - 14.0, "off": 1.7, "color": "orange", "ai": true},
		{"s": path.total - 17.5, "off": -1.7, "color": "white", "ai": true},
	]
	for g in grid:
		var car := RaceCar.new()
		add_child(car)
		car.setup(g.color, path, g.s, g.off)
		car.laps_total = LAPS
		car.is_ai = g.ai
		if not g.ai:
			car.init_audio()
		cars.append(car)
		if g.ai:
			rivals.append(car)
		else:
			player = car
	player.name = "PlayerCar"
	_fix_kit_colors(self)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	var info := path.at(player.start_s)
	camera.position = player.position + Vector3(0, 4.2, -9) * 1.0
	camera.look_at(player.position + Vector3(0, 0.8, 0))

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	# 全局 UI 点击音（按钮/重开）
	ui_player = AudioStreamPlayer.new()
	ui_player.stream = SfxSynth.ui_click()
	ui_player.volume_db = -8.0
	add_child(ui_player)

	# 左上信息卡：深棕半透明磨砂底 + 圆角金边，奶油字，层级由大到小
	var panel := Panel.new()
	panel.position = Vector2(20, 18)
	panel.size = Vector2(252, 152)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.72)
	sb.border_color = Color(0.86, 0.67, 0.38, 0.85)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 20
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	hud.add_child(panel)

	lbl_lap = Label.new()
	lbl_lap.position = Vector2(20, 14)
	lbl_lap.add_theme_font_size_override("font_size", 30)
	lbl_lap.add_theme_color_override("font_color", Color(0.99, 0.95, 0.86))
	panel.add_child(lbl_lap)
	lbl_time = Label.new()
	lbl_time.position = Vector2(20, 56)
	lbl_time.add_theme_font_size_override("font_size", 24)
	lbl_time.add_theme_color_override("font_color", Color(0.95, 0.88, 0.74))
	panel.add_child(lbl_time)
	lbl_best = Label.new()
	lbl_best.position = Vector2(20, 92)
	lbl_best.add_theme_font_size_override("font_size", 18)
	lbl_best.add_theme_color_override("font_color", Color(0.78, 0.68, 0.52))
	panel.add_child(lbl_best)

	lbl_speed = Label.new()
	lbl_speed.anchor_left = 1.0
	lbl_speed.anchor_right = 1.0
	lbl_speed.offset_left = -260
	lbl_speed.offset_right = -30
	lbl_speed.offset_top = 18
	lbl_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_speed.add_theme_font_size_override("font_size", 52)
	lbl_speed.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	lbl_speed.add_theme_color_override("font_outline_color", Color(0.24, 0.16, 0.08))
	lbl_speed.add_theme_constant_override("outline_size", 8)
	hud.add_child(lbl_speed)

	lbl_count = Label.new()
	lbl_count.anchor_left = 0.5
	lbl_count.anchor_right = 0.5
	lbl_count.anchor_top = 0.5
	lbl_count.anchor_bottom = 0.5
	lbl_count.offset_left = -160
	lbl_count.offset_right = 160
	lbl_count.offset_top = -80
	lbl_count.offset_bottom = 40
	lbl_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_count.add_theme_font_size_override("font_size", 96)
	lbl_count.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	lbl_count.add_theme_color_override("font_outline_color", Color(0.28, 0.18, 0.08))
	lbl_count.add_theme_constant_override("outline_size", 12)
	hud.add_child(lbl_count)

	lbl_result = Label.new()
	lbl_result.anchor_left = 0.5
	lbl_result.anchor_right = 0.5
	lbl_result.anchor_top = 0.5
	lbl_result.anchor_bottom = 0.5
	lbl_result.offset_left = -400
	lbl_result.offset_right = 400
	lbl_result.offset_top = -160
	lbl_result.offset_bottom = 160
	lbl_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_result.add_theme_font_size_override("font_size", 40)
	lbl_result.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	lbl_result.add_theme_color_override("font_outline_color", Color(0.2, 0.13, 0.06))
	lbl_result.add_theme_constant_override("outline_size", 8)
	lbl_result.visible = false
	hud.add_child(lbl_result)

	# HUD 位置全部按当下视口尺寸算（横屏 expand 后不是固定 1280×720），避免贴边
	var vs: Vector2 = get_viewport().get_visible_rect().size
	# ==== HUD 手感参数（想再挪位置就只改这 5 个数）====
	var joy_margin_left := 108.0   # 摇杆离左边多远
	var joy_margin_bottom := 96.0  # 摇杆离底边多远（下面还留标签）
	var joy_d := 236.0             # 摇杆直径
	var pad_margin_right := 100.0  # 右下技能区离右边缘（往内收，别贴边）
	var pad_margin_bottom := 30.0  # 右下技能区离底边

	# 左下：半透明虚拟摇杆
	var jd: float = joy_d
	var jx: float = joy_margin_left
	var jy: float = vs.y - jd - joy_margin_bottom
	joystick = preload("res://scripts/race/touch_joystick.gd").new()
	joystick.position = Vector2(jx, jy)
	joystick.size = Vector2(jd, jd)
	hud.add_child(joystick)
	joystick.resize()
	joystick.steer_changed.connect(func(v: float) -> void: joy_steer = v)
	joystick.throttle_changed.connect(func(v: float) -> void: joy_throttle = v)
	joystick.brake_changed.connect(func(v: float) -> void: joy_brake = v)
	# 右下：1 个大键（加速）+ 4 个小键环绕（刹车/氮气/复位/视角）
	var gas_d := 164.0
	var gas_x: float = vs.x - pad_margin_right - gas_d
	var gas_y: float = vs.y - pad_margin_bottom - gas_d
	var big_c := Vector2(gas_x + gas_d * 0.5, gas_y + gas_d * 0.5)
	var gas := _skill("gas", "加速", Vector2(gas_x, gas_y), gas_d,
		Color(0.96, 0.60, 0.18, 0.96), Color(1.0, 0.76, 0.34, 0.98))
	pads["gas"] = gas

	var small_d := 88.0
	var orbit := 146.0
	var small_defs := [
		{"id": "brake", "text": "刹车", "ang": 84.0,
			"base": Color(0.86, 0.30, 0.24, 0.95), "act": Color(0.96, 0.44, 0.36, 0.98)},
		{"id": "nitro", "text": "氮气", "ang": 124.0,
			"base": Color(0.24, 0.46, 0.82, 0.95), "act": Color(0.38, 0.62, 0.96, 0.98)},
		{"id": "reset", "text": "复位", "ang": 164.0,
			"base": Color(0.30, 0.56, 0.38, 0.95), "act": Color(0.42, 0.72, 0.50, 0.98)},
		{"id": "view", "text": "视角", "ang": 200.0,
			"base": Color(0.46, 0.38, 0.30, 0.95), "act": Color(0.62, 0.52, 0.40, 0.98)},
	]
	for def in small_defs:
		var a: float = deg_to_rad(def["ang"])
		var c := Vector2(big_c.x + cos(a) * orbit, big_c.y - sin(a) * orbit)
		var pad := _skill(def["id"], def["text"], c - Vector2(small_d, small_d) * 0.5, small_d,
			def["base"], def["act"])
		pads[def["id"]] = pad
	# 辅助状态灯：收进信息卡底部，让"辅助到底有没有在干活"一眼可见
	lbl_assist = Label.new()
	lbl_assist.position = Vector2(20, 120)
	lbl_assist.size = Vector2(220, 24)
	lbl_assist.add_theme_font_size_override("font_size", 16)
	lbl_assist.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))
	panel.add_child(lbl_assist)
	pads["nitro"].set_ring(1.0)

	# 结束结算后的重开按钮（默认隐藏，冲线后才显示）
	var rb_d := 170.0
	btn_restart = _skill("restart", "",
		Vector2((vs.x - rb_d) * 0.5, vs.y * 0.5 + 86.0), rb_d,
		Color(0.96, 0.60, 0.18, 0.96), Color(1.0, 0.76, 0.34, 0.98), "refresh")
	btn_restart.visible = false

## 登记路边道具，等下一帧 global_transform 就绪后按世界网格 AABB 生成静态阻挡盒。
## local_size/local_offset 仅作取不到网格时的兜底（当前所有 kit 模型都有网格）。
func _attach_static_box(prop: Node3D, local_size: Vector3 = Vector3.ZERO, local_offset: Vector3 = Vector3.ZERO) -> void:
	_static_props.append(prop)

## 为每个登记道具建一个独立 StaticBody，盒体对齐模型世界 AABB（位置、尺寸直接取网格包络）。
func _build_static_bodies() -> void:
	for prop in _static_props:
		var aabb := _mesh_world_aabb(prop)
		if aabb.size.length() < 0.01:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = RaceCar.COL_LAYER_STATIC
		body.collision_mask = 0
		body.position = aabb.get_center()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)

## 合并 prop 下所有网格在世界空间的轴对齐 AABB。
func _mesh_world_aabb(root: Node3D) -> AABB:
	var merged := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var a: AABB = m.get_aabb()
		for k in range(8):
			var corner: Vector3 = m.global_transform * a.get_endpoint(k)
			if first:
				merged = AABB(corner, Vector3.ZERO)
				first = false
			else:
				merged = merged.expand(corner)
	return merged

func _skill(id: String, text: String, pos: Vector2, diameter: float, base: Color, active: Color, icon: String = "") -> Control:
	var b: Control = preload("res://scripts/race/skill_pad.gd").new()
	b.label_text = text
	b.icon = icon
	b.base_color = base
	b.active_color = active
	b.position = pos
	b.size = Vector2(diameter, diameter)
	hud.add_child(b)
	return b

func _pad(glyph: String, pos: Vector2, diameter: float = 150.0) -> Control:
	var b := preload("res://scripts/race/touch_button.gd").new()
	b.glyph = glyph
	b.position = pos
	b.size = Vector2(diameter, diameter)
	hud.add_child(b)
	return b

func _process(delta: float) -> void:
	if splash_hold > 0.0:
		splash_hold -= delta
		if lbl_count != null:
			lbl_count.visible = false
		_update_camera(delta)
		return
	if state == "countdown":
		countdown -= delta
		var n := int(ceil(countdown))
		lbl_count.visible = true
		lbl_count.text = "GO!" if countdown <= 1.0 else str(n)
		if countdown <= 1.0:
			lbl_count.text = "GO!"
			_begin_race()
	_update_player_input()
	if state == "racing":
		race_time += delta
	for car in cars:
		if car.is_ai:
			car.drive_ai(delta, race_time, 12.0, 0.86 if car == rivals[0] else 0.93)
		else:
			car.step(delta, race_time)
	_update_camera(delta)
	_update_hud()
	_check_finish()

func _begin_race() -> void:
	if state != "countdown":
		return
	state = "racing"
	for car in cars:
		car.started = true
		car.lap_start = 0.0
	lbl_count.visible = false

## 集中式触摸分发：不依赖 Control 的 GUI 命中，iOS 上更稳
func _input(event: InputEvent) -> void:
	if joystick == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_route_down(event.index, event.position)
		else:
			_route_up(event.index)
	elif event is InputEventScreenDrag:
		_route_move(event.index, event.position)

func _route_down(idx: int, pos: Vector2) -> void:
	# 结算界面：点"再来一局"直接重载场景，状态全部清零
	if state == "finished" and btn_restart != null and btn_restart.visible:
		var rr: Rect2 = btn_restart.get_global_rect()
		if pos.distance_to(rr.get_center()) <= rr.size.x * 0.5 + 16.0:
			get_tree().reload_current_scene()
			return
	var jrect: Rect2 = joystick.get_global_rect()
	# 摇杆命中区略放大，拇指不用正中对齐
	var jc: Vector2 = jrect.get_center()
	if pos.distance_to(jc) <= jrect.size.x * 0.5 + 10.0:
		_touch_map[idx] = "joy"
		joystick.press_at(pos - jrect.position, idx)
		return
	for key in pads:
		var b: Control = pads[key]
		var c: Vector2 = b.get_global_rect().get_center()
		if pos.distance_to(c) <= b.size.x * 0.5 + 14.0:
			_touch_map[idx] = key
			b.press(idx)
			if ui_player != null:
				ui_player.play()
			if key in ["brake", "nitro", "reset"]:
				Input.vibrate_handheld(35)
			return

func _route_move(idx: int, pos: Vector2) -> void:
	if _touch_map.get(idx, "") == "joy":
		joystick.drag_at(pos - joystick.get_global_rect().position, idx)

func _route_up(idx: int) -> void:
	var key: String = _touch_map.get(idx, "")
	if key == "":
		return
	if key == "joy":
		joystick.release_at(idx)
	else:
		pads[key].release(idx)
	_touch_map.erase(idx)

func _update_player_input() -> void:
	if state != "racing":
		return
	var steer := 0.0
	var gas := 0.0
	var brake := 0.0
	steer += joy_steer
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		steer -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		steer += 1.0
	if _down("gas") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		gas = 1.0
	if _down("brake") or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE):
		brake = 1.0
	player.steer = clampf(steer, -1.0, 1.0)
	player.throttle = maxf(gas, joy_throttle)
	player.brake = maxf(brake, joy_brake)
	player.boosting = _down("nitro") or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_N)
	var want_reset: bool = _down("reset") or Input.is_key_pressed(KEY_R)
	if want_reset and not _prev_reset:
		respawn_player()
	_prev_reset = want_reset
	var want_view: bool = _down("view") or Input.is_key_pressed(KEY_V)
	if want_view and not _prev_view:
		cam_far = not cam_far
	_prev_view = want_view

func respawn_player() -> void:
	var near: Array = path.nearest(player.position)
	player.position = near[3] + Vector3(0.0, 0.05, 0.0)
	player.yaw = atan2(near[2].x, near[2].z)
	player.rotation = Vector3(0.0, player.yaw, 0.0)
	player.speed = 6.0
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO

func _down(key: String) -> bool:
	var b = pads.get(key)
	return b != null and b.down

func _update_camera(delta: float) -> void:
	var target: RaceCar = player
	var forward := Vector3(sin(target.yaw), 0.0, cos(target.yaw))
	var speed_k := clampf(target.speed / RaceCar.MAX_SPEED, 0.0, 1.0)
	var back := (12.6 if cam_far else 8.6) + speed_k * 2.4
	var height := (7.4 if cam_far else 4.2) + speed_k * 0.4
	var want := target.position - forward * back + Vector3(0, height, 0)
	camera.position = camera.position.lerp(want, 1.0 - exp(-7.0 * delta))
	var look := target.position + forward * 5.0 + Vector3(0, 1.1, 0)
	camera.look_at(look)
	camera.fov = lerpf(camera.fov, 60.0 + speed_k * 12.0 + (8.0 if target.nitro_time > 0.0 else 0.0), 1.0 - exp(-4.0 * delta))

func _update_hud() -> void:
	lbl_lap.text = "圈 %d / %d" % [mini(player.lap + 1, LAPS), LAPS]
	lbl_time.text = "时间 %s" % _fmt(race_time)
	lbl_best.text = "最快圈 %s" % ("--" if player.best_lap <= 0.0 else _fmt(player.best_lap))
	lbl_speed.text = "%d km/h" % int(player.current_kmh())
	# 操作反馈：氮气爆发亮蓝、刹车转红，让人一眼看出按键生效
	if player.nitro_time > 0.0:
		lbl_speed.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0))
	elif player.boosting and player.boost_fuel > 0.0:
		lbl_speed.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))
	elif player.brake > 0.2:
		lbl_speed.add_theme_color_override("font_color", Color(1.0, 0.66, 0.58))
	else:
		lbl_speed.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	# 辅助状态：正在修正时亮起来
	if player.assist_active:
		lbl_assist.text = "辅助 · 自动回正"
		lbl_assist.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	else:
		lbl_assist.text = "辅助 · 待命"
		lbl_assist.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))
	var nb = pads.get("nitro")
	if nb != null and nb.has_method("set_ring"):
		nb.set_ring(player.boost_fuel)
		nb.set_dim(player.boost_fuel <= 0.02 or (player.nitro_cool > 0.0 and player.nitro_time <= 0.0))

func _fmt(t: float) -> String:
	var m := int(t) / 60
	var s := fmod(t, 60.0)
	return "%d:%05.2f" % [m, s]

func _check_finish() -> void:
	if state != "racing":
		return
	if player.finished:
		state = "finished"
		var rank := 1
		for car in cars:
			if car != player and car.finished:
				rank += 1
		lbl_result.text = "第 %d 名\n总时间 %s\n最快圈 %s" % [rank, _fmt(player.finish_time), _fmt(player.best_lap)]
		lbl_result.visible = true
		if btn_restart != null:
			btn_restart.visible = true
