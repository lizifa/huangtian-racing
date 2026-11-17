class_name ExhaustFx
extends CPUParticles3D
## 排气管尾气：怠速一层薄烟，油门越深成团越浓，氮气时更猛、颜色更暖。
## 粒子走世界坐标，车往前开烟留在后面，才有拖尾的味道。

static var _dot_tex: Texture2D

func _init() -> void:
	amount = 64
	lifetime = 1.0
	lifetime_randomness = 0.35
	local_coords = false
	emitting = false
	explosiveness = 0.0
	direction = Vector3(0.0, 0.18, -1.0)
	spread = 20.0
	gravity = Vector3(0.0, 0.85, 0.0)
	initial_velocity_min = 0.9
	initial_velocity_max = 2.8
	damping_min = 0.6
	damping_max = 1.4
	scale_amount_min = 0.18
	scale_amount_max = 0.34
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.62))
	grow.add_point(Vector2(0.35, 1.15))
	grow.add_point(Vector2(1.0, 1.7))
	scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.65, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.80),
		Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	color_ramp = ramp
	color = Color(0.86, 0.86, 0.88, 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _soft_dot()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	quad.material = mat
	mesh = quad

## 32×32 软圆点，省得为一个烟团再塞一张 PNG 进仓库。
static func _soft_dot() -> Texture2D:
	if _dot_tex != null:
		return _dot_tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := float(n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex

## 每帧喂一次驾驶状态：油门、车速、是否在氮气、是否压草地。
## 浓度（amount）不解每帧改（改一次会重建粒子），靠尺寸和初速表达强弱。
func set_drive(throttle: float, speed: float, boosting: bool, offroad: bool) -> void:
	var load_k := clampf(absf(speed) / 26.0, 0.0, 1.0)
	var t := clampf(maxf(throttle, load_k * 0.7), 0.0, 1.0)
	# 怠速/低速保留一层薄烟：负荷系数加地板，避免松油门滑行时几乎看不到尾气
	var tl := clampf(0.35 + 0.65 * t, 0.0, 1.0)
	# 完全静止（没车速、没给油、没开氮气）就不排尾气
	var idle := absf(speed) < 0.5 and throttle <= 0.05 and not boosting
	emitting = not idle
	if boosting:
		initial_velocity_max = 4.6
		scale_amount_min = 0.70
		scale_amount_max = 1.20
		color = Color(0.96, 0.92, 0.88, 1.0)
	elif offroad:
		initial_velocity_max = 3.2
		scale_amount_min = 0.50
		scale_amount_max = 0.85
		color = Color(0.74, 0.70, 0.60, 1.0)
	else:
		initial_velocity_max = 2.4 + tl * 1.2
		scale_amount_min = 0.46 + tl * 0.14
		scale_amount_max = 0.70 + tl * 0.22
		color = Color(0.82, 0.82, 0.85, 1.0)
