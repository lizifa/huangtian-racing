class_name RaceCar
extends RigidBody3D
## 街机手感赛车：刚体参与碰撞（车车 / 车墙由物理引擎解算不穿模），
## 纵向仍由速度标量 + 航向角驱动，转向随速度收紧，出界掉速，边缘软墙。

## 物理层：1 = 车辆，2 = 静态场景
const COL_LAYER_CAR := 1
const COL_LAYER_STATIC := 2
## 碰撞盒（世界单位，按 Kit 车模实测包围盒略收窄）
const COLLISION_SIZE := Vector3(1.25, 0.60, 2.40)
const COLLISION_Y := 0.30

const MAX_SPEED := 26.0
const BOOST_SPEED := 34.0
const ACCEL := 12.0
const BRAKE := 26.0
const REVERSE_SPEED := -9.0
const DRAG := 0.12
const TURN_RATE := 3.2          ## 低速满舵每秒转多少弧度
const OFFROAD_MAX := 11.0
## 过弯防冲出：前瞻随速度加长、弯速下限、超速收速系数、方向舵对回正辅助的让位幅度。
const CORNER_LOOK_BASE := 10.0    ## 基础前瞻距离（米）
const CORNER_LOOK_SPEED := 0.5    ## 每 m/s 车速额外加长的前瞻
const CORNER_MIN_CAP := 10.0      ## 弯道限速下限
const CORNER_DECAY := 5.0         ## 超速后每秒向弯限收速的系数
const ASSIST_YIELD := 0.40        ## 打方向时回正辅助保留的让位幅度（越小拉得越住）
## 氮气：点一下给一脚爆发，按住持续推，油量是共用的储能
const NITRO_KICK := 5.5         ## 点按瞬间直接加多少速度（静止按也蹿得出去）
const NITRO_BURST := 1.0         ## 爆发持续多少秒
const NITRO_BURST_THRUST := 20.0 ## 爆发期间额外推力（m/s²）
const NITRO_BOOST_THRUST := 18.0 ## 按住氮气的持续推力
const NITRO_COOLDOWN := 2.4      ## 两次爆发之间至少隔多久
const NITRO_COST := 0.22         ## 一次爆发吃掉多少油
const NITRO_DRAIN := 0.30        ## 按住氮气每秒耗油
const NITRO_REGEN := 0.10        ## 松手每秒回油
const NITRO_OFFROAD_MAX := 4.0   ## 草地上氮气也能把限速顶高这么多

## 碰撞冲量层（街机叠加，不改纯刚体）：追尾被顶短暂提速、侧碰横向滑出 + 短暂失控。
const PUSH_DECAY := 3.2          ## 被顶冲量每秒衰减
const LATERAL_DAMP := 2.4        ## 横向速度每秒阻尼
const KICK_DECAY := 4.5          ## 偏航扰动每秒衰减
const LOSE_TIME := 0.55          ## 一次侧碰的失控时长（秒）
const HIT_PUSH_MAX := 6.0        ## 被追尾最多临时叠加多少速度
const LATERAL_MAX := 7.0         ## 横向速度上限
const KICK_MAX := 1.5            ## 偏航角速度扰动上限（rad/s）

var path: RacePath
var model: Node3D
var speed := 0.0
var yaw := 0.0
var throttle := 0.0              ## 0..1
var brake := 0.0
var steer := 0.0
var is_ai := false
var lap := 0
var progress := 0.0
var laps_total := 3
var finished := false
var finish_time := 0.0
var best_lap := 0.0
var lap_start := 0.0
var last_s := 0.0
var started := false
var color := "red"
var start_s := 0.0
var start_offset := 0.0
var name_label := ""
var slide := 0.0
var bounce := 0.0
var wall_cool := 0.0
var boost_fuel := 1.0
var boosting := false
var nitro_time := 0.0            ## >0 表示正在氮气爆发
var nitro_cool := 0.0            ## >0 表示爆发冷却中
var _nitro_prev := false
var boost_on_now := false
var offroad_now := false
var assist_active := false       ## 赛道辅助这一刻是否在发力（HUD 用它做反馈）
var crash_cool := 0.0            ## 碰撞掉速冷却，避免一帧内反复扣速
var crash_impact := 0.0          ## 最近一次碰撞强度 0..1（反馈/震动用）
var hit_push := 0.0              ## 追尾被顶的临时纵向冲量，叠加推进、随时间衰减
var lateral_v := 0.0             ## 横向速度分量（右为正），叠加进线速度并阻尼衰减
var yaw_kick := 0.0              ## 侧碰注入的偏航角速度扰动，随时间衰减
var lose_control := 0.0          ## 失控剩余时间：期间削弱赛道回正辅助
var exhausts: Array = []   ## 左右两个 ExhaustFx（preload 实例化，不做类型标注，免得依赖全局类缓存）
var audio_on := false
var engine_player: AudioStreamPlayer
var nitro_player: AudioStreamPlayer
var crash_player: AudioStreamPlayer

const CAR_SCENES := {"red": "raceCarRed", "green": "raceCarGreen", "orange": "raceCarOrange", "white": "raceCarWhite"}
const ExhaustScript := preload("res://scripts/race/exhaust_fx.gd")
## Kit 车模本地坐标实测（四款车一致）：x ∈ [-0.714, 0.014]，车尾 z ≈ -1.336。
## 两个排气口分别贴在后轮内侧、车尾下沿左右两侧，管口略突出车尾端面。
const EXHAUST_LOCAL := [
	Vector3(-0.54, 0.09, -1.36),
	Vector3(-0.16, 0.09, -1.36),
]
## 程序化低模驾驶员（挂在 body 节点本地系）：橙头盔 + 黑面罩 + 深灰赛车服躯干。
const DRIVER_HELMET := Vector3(0.305, 0.24, -0.48)
const DRIVER_VISOR := Vector3(0.305, 0.25, -0.40)
const DRIVER_TORSO := Vector3(0.305, 0.13, -0.52)

func setup(car_color: String, car_path: RacePath, s: float, offset: float) -> void:
	color = car_color
	path = car_path
	start_s = s
	start_offset = offset
	_setup_body()
	var packed: PackedScene = load("res://assets/kit/%s.glb" % CAR_SCENES.get(car_color, "raceCarRed"))
	model = packed.instantiate()
	model.scale = Vector3.ONE * 1.9
	model.position = Vector3(0, 0.02, 0)
	add_child(model)
	_build_exhaust()
	_build_driver()

	reset_to_grid()

## 刚体属性 + 碰撞盒：只允许绕 Y 转，锁定俯仰翻滚，街赛车不侧翻。
func _setup_body() -> void:
	collision_layer = COL_LAYER_CAR
	collision_mask = COL_LAYER_CAR | COL_LAYER_STATIC
	mass = 1.0
	linear_damp = 0.0
	angular_damp = 1.0
	gravity_scale = 0.0   ## 街赛车贴地行驶，不用重力，避免下沉/弹跳/侧翻
	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	pm.bounce = 0.25
	physics_material_override = pm
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = COLLISION_SIZE
	shape.shape = box
	shape.position = Vector3(0.0, COLLISION_Y, 0.0)
	add_child(shape)

## 车尾左右双排气口：粒子挂在 model 本地空间，跟随车身缩放与侧倾；
## 另在每个口位置挂一根深色短管，确保车尾左右两个管口肉眼可辨。
func _build_exhaust() -> void:
	for local in EXHAUST_LOCAL:
		var fx := ExhaustScript.new()
		fx.position = local
		model.add_child(fx)
		exhausts.append(fx)
		_add_tail_pipe(local)

func _add_tail_pipe(local: Vector3) -> void:
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
	node.position = local + Vector3(0.0, 0.0, -0.03)
	model.add_child(node)

## 座舱里补一个低模驾驶员：橙头盔 + 黑面罩 + 深灰躯干，挂在 body 本地系跟随车身。
func _build_driver() -> void:
	var bodies := model.find_children("body", "MeshInstance3D", true, false)
	if bodies.is_empty():
		return
	var seat: Node3D = bodies[0]

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
	helmet.position = DRIVER_HELMET
	seat.add_child(helmet)

	var visor := MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.10, 0.06, 0.04)
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color(0.05, 0.05, 0.06)
	vm.roughness = 0.3
	visor.mesh = vb
	visor.material_override = vm
	visor.position = DRIVER_VISOR
	seat.add_child(visor)

	var torso := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.20, 0.18, 0.22)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.18, 0.18, 0.20)
	tm.roughness = 0.7
	torso.mesh = tb
	torso.material_override = tm
	torso.position = DRIVER_TORSO
	seat.add_child(torso)

func reset_to_grid() -> void:
	var info := path.at(start_s)
	var p: Vector3 = info[0]
	var d: Vector3 = info[1]
	var side := Vector3(-d.z, 0.0, d.x)
	position = p + side * start_offset
	yaw = atan2(d.x, d.z)   # 模型 +Z 朝前
	speed = 0.0
	lap = 0
	progress = start_s
	last_s = start_s
	finished = false
	rotation = Vector3(0, yaw, 0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	slide = 0.0
	hit_push = 0.0
	lateral_v = 0.0
	yaw_kick = 0.0
	lose_control = 0.0
	crash_cool = 0.0
	crash_impact = 0.0
	if audio_on and nitro_player.playing:
		nitro_player.stop()

## 音频只给玩家车挂（AI 车静音，避免多引擎嘈杂、省移动端性能）。
func init_audio() -> void:
	audio_on = true
	engine_player = AudioStreamPlayer.new()
	engine_player.stream = SfxSynth.engine_loop()
	engine_player.volume_db = -14.0
	add_child(engine_player)
	nitro_player = AudioStreamPlayer.new()
	nitro_player.stream = SfxSynth.nitro_loop()
	nitro_player.volume_db = -10.0
	add_child(nitro_player)
	crash_player = AudioStreamPlayer.new()
	crash_player.stream = SfxSynth.crash()
	add_child(crash_player)

func current_kmh() -> float:
	return speed * 3.6

func step(delta: float, race_time: float) -> void:
	wall_cool = maxf(0.0, wall_cool - delta)
	# 碰撞冲量随时间衰减：纵向冲量、横向速度、偏航扰动、失控计时
	hit_push = maxf(0.0, hit_push - PUSH_DECAY * delta)
	lateral_v = maxf(0.0, absf(lateral_v) - LATERAL_DAMP * delta) * signf(lateral_v)
	yaw_kick = maxf(0.0, absf(yaw_kick) - KICK_DECAY * delta) * signf(yaw_kick)
	lose_control = maxf(0.0, lose_control - delta)
	if finished:
		throttle = 0.0
		brake = 1.0
	var nearest := path.nearest(position)
	var s: float = nearest[0]
	var offset: float = nearest[1]
	var tan: Vector3 = nearest[2]
	progress = s

	# 氮气计时 + 点按爆发（按住也算一次触发，之后持续推）
	nitro_time = maxf(0.0, nitro_time - delta)
	nitro_cool = maxf(0.0, nitro_cool - delta)
	if boosting and not _nitro_prev and nitro_cool <= 0.0 and boost_fuel >= NITRO_COST:
		_fire_nitro()
	_nitro_prev = boosting

	# 出界：抓地下降、限速，草地拖慢
	offroad_now = absf(offset) > RacePath.ROAD_HALF - 0.2
	# 氮气不再看车速和路面，静止按也能蹿，草地上只是打折
	boost_on_now = boosting and boost_fuel > 0.0
	if boost_on_now:
		boost_fuel = maxf(0.0, boost_fuel - NITRO_DRAIN * delta)
	else:
		boost_fuel = minf(1.0, boost_fuel + NITRO_REGEN * delta)
	var nitro_live := boost_on_now or nitro_time > 0.0
	var look_ahead := CORNER_LOOK_BASE + absf(speed) * CORNER_LOOK_SPEED
	var ahead: Vector3 = path.at(s + look_ahead)[1]
	var bend := absf(wrapf(atan2(ahead.x, ahead.z) - atan2(tan.x, tan.z), -PI, PI))
	var curve := bend / look_ahead
	var corner_cap := MAX_SPEED
	if curve > 0.002:
		corner_cap = clampf(TURN_RATE * 0.90 * 0.95 / curve, CORNER_MIN_CAP, MAX_SPEED)
	var target_cap := OFFROAD_MAX + (NITRO_OFFROAD_MAX if nitro_live else 0.0) if offroad_now else maxf(corner_cap, BOOST_SPEED if nitro_live else 0.0)
	if not offroad_now and not nitro_live and speed > corner_cap:
		speed -= (speed - corner_cap) * CORNER_DECAY * delta
	# 牵引力控制：已超弯限时压低油门推力，避免长按油门硬冲出弯
	var corner_over := 0.0 if offroad_now else clampf((speed - corner_cap) / 6.0, 0.0, 1.0)
	var accel_scale := 1.0 - corner_over * 0.7
	if throttle > 0.0:
		speed += ACCEL * throttle * accel_scale * (0.55 if offroad_now else 1.0) * delta
	# 氮气推力：爆发那 1 秒更猛，按住继续给持续推力
	var thrust := 0.0
	if nitro_time > 0.0:
		thrust = NITRO_BURST_THRUST
	if boost_on_now:
		thrust = maxf(thrust, NITRO_BOOST_THRUST)
	if thrust > 0.0:
		speed += thrust * (0.55 if offroad_now else 1.0) * delta
	if brake > 0.0:
		speed = maxf(0.0, speed - BRAKE * brake * delta) if speed > 0.0 else maxf(speed, 0.0)
	speed = clampf(speed, REVERSE_SPEED, target_cap)
	# 阻力 + 出界额外阻力
	speed -= speed * (DRAG + (0.35 if offroad_now else 0.0)) * delta
	if throttle <= 0.0 and brake <= 0.0 and absf(speed) < 0.35:
		speed = 0.0

	if not started:
		slide = 0.0
		_update_visual(delta)
		return

	# 转向：速度越高舵角越小
	var speed_factor := clampf(absf(speed) / 8.0, 0.0, 1.0)
	var high_speed_limit := 1.0 - 0.10 * clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
	var yaw_rate := -steer * TURN_RATE * speed_factor * high_speed_limit
	if speed < 0.0:
		yaw_rate = -yaw_rate
	# 失控期间削弱回正辅助，让撞击偏转能短暂偏出车道，再自己回正
	var control_scale := 1.0 - 0.75 * clampf(lose_control / LOSE_TIME, 0.0, 1.0)
	# 赛道辅助：偏得越远拉得越狠，方向盘打满时让位给玩家（不然手感被抢）
	if not is_ai:
		var track_yaw := atan2(tan.x, tan.z)
		var pull := wrapf(track_yaw - yaw, -PI, PI)
		var lateral := clampf(absf(offset) / RacePath.ROAD_HALF, 0.0, 1.0)
		var gain := lerpf(1.1, 2.6, lateral * lateral)
		gain *= 1.0 - ASSIST_YIELD * clampf(absf(steer), 0.0, 1.0)
		gain *= control_scale
		var rate := clampf(pull, -1.2, 1.2) * gain
		yaw_rate += rate
		assist_active = absf(rate) > 0.25 and absf(pull) > 0.08
	else:
		assist_active = false
	yaw += (yaw_rate + yaw_kick) * delta
	slide = lerpf(slide, -steer * 0.32 * speed_factor, 1.0 - exp(-8.0 * delta))

	# 位置推进交给刚体：_physics_process 里按 yaw/speed 写 linear_velocity，
	# 碰撞阻挡与分离由物理引擎解算，这里不再直接改 position。

	# 边缘软墙：贴上去之后只抹掉朝外的那部分速度，让车顺着墙滑，别把位置硬掰回去
	var limit := RacePath.ROAD_HALF + 1.15
	if absf(offset) > limit:
		var nn := path.nearest(position)
		var t_now: Vector3 = nn[2]
		# 滑墙：车头顺着墙走，只损失一点速度，不会像撞墙一样被吃掉
		var along_yaw := atan2(t_now.x, t_now.z)
		yaw = lerp_angle(yaw, along_yaw if speed >= 0.0 else along_yaw + PI, 0.3)
		if wall_cool <= 0.0:
			speed *= 0.72
			wall_cool = 0.6
			slide *= 0.5
		bounce = 1.0


	# 出界时把车头拉回路的方向，手一松就能自己开回来（辅助的一部分）
	if absf(offset) > RacePath.ROAD_HALF - 0.1:
		var along_yaw := atan2(tan.x, tan.z)
		var need := wrapf(along_yaw - yaw, -PI, PI)
		yaw += clampf(need, -1.2, 1.2) * 2.2 * control_scale * delta
		assist_active = assist_active or absf(need) > 0.15

	# 贴墙时别把速度磨到停：油门还在就给个下限，蹭墙也能往前走
	if absf(offset) > limit and throttle > 0.0:
		speed = maxf(speed, minf(MAX_SPEED * 0.42, 10.0))

	# 圈数：按 s 从尾绕到头判一圈
	var s_before := last_s
	last_s = s
	if s_before > path.total - 12.0 and s < 12.0 and speed > 0.0:
		lap += 1
		if lap >= 1 and lap_start > 0.0:
			var lap_time := race_time - lap_start
			if best_lap <= 0.0 or lap_time < best_lap:
				best_lap = lap_time
		lap_start = race_time
		if lap >= laps_total:
			finished = true
			finish_time = race_time
	_update_visual(delta)

## 物理帧：把街机模型的 yaw/speed 写给刚体，碰撞阻挡与分离由引擎解算。
func _physics_process(delta: float) -> void:
	rotation.y = yaw
	crash_cool = maxf(0.0, crash_cool - delta)
	crash_impact = maxf(0.0, crash_impact - 4.0 * delta)
	_update_audio()
	if not started:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var target_v := forward * (speed + hit_push) + right * lateral_v
	linear_velocity = Vector3(target_v.x, 0.0, target_v.z)
	angular_velocity = Vector3.ZERO

## 引擎循环随车速变调变响；氮气叠加风啸；未发车/冲线后静音。
func _update_audio() -> void:
	if not audio_on:
		return
	if not started or finished:
		if engine_player.playing:
			engine_player.stop()
		if nitro_player.playing:
			nitro_player.stop()
		return
	if not engine_player.playing:
		engine_player.play()
	var spd: float = clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
	var load: float = clampf(throttle, 0.0, 1.0)
	engine_player.pitch_scale = 0.85 + spd * 0.65 + load * 0.1
	engine_player.volume_db = lerpf(-14.0, -6.0, spd)
	if boosting and boost_fuel > 0.0:
		if not nitro_player.playing:
			nitro_player.play()
	elif nitro_player.playing:
		nitro_player.stop()

## 碰撞进入：按接触方向分类——被追尾吃向前冲量、撞击方掉速、侧碰横滑 + 短暂失控。
func _on_body_entered(body: Node) -> void:
	if not started:
		return
	if body.name == "Ground":
		return
	var other_speed := 0.0
	var other_fwd := Vector3.ZERO
	if body is RaceCar:
		var oc := body as RaceCar
		other_speed = absf(oc.speed)
		other_fwd = Vector3(sin(oc.yaw), 0.0, cos(oc.yaw))
	var rel := absf(speed) + other_speed
	var impact := clampf(rel / 26.0, 0.0, 1.0)
	crash_impact = maxf(crash_impact, impact)
	bounce = 1.0
	if audio_on and crash_cool <= 0.0:
		crash_player.volume_db = lerpf(-12.0, -4.0, impact)
		crash_player.pitch_scale = lerpf(1.0, 0.8, impact)
		crash_player.play()

	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var to_other: Vector3 = body.global_position - global_position
	to_other.y = 0.0
	var dist: float = to_other.length()
	var n: Vector3 = to_other / dist if dist > 0.05 else -fwd
	var dot := fwd.dot(n)   # >0 本车撞向对方；<0 对方从后方/侧后顶本车

	if body is RaceCar:
		var head_on := fwd.dot(other_fwd) < 0.3
		if dot < -0.3:
			# 被后车追尾：吃一脚向前冲量，只轻微掉速
			var push := clampf(other_speed * 0.35, 1.5, HIT_PUSH_MAX) * impact
			hit_push = minf(hit_push + push, HIT_PUSH_MAX)
			lose_control = maxf(lose_control, 0.15)
			if crash_cool <= 0.0:
				speed *= lerpf(0.95, 0.85, impact)
				crash_cool = 0.35
		elif absf(dot) <= 0.3:
			# 侧面剐蹭：横向滑出 + 车头偏转 + 短暂失控（推向远离撞击侧）
			var side := -signf(fwd.cross(n).y)
			if side == 0.0:
				side = 1.0
			lateral_v = clampf(lateral_v + side * impact * LATERAL_MAX * 0.6, -LATERAL_MAX, LATERAL_MAX)
			yaw_kick = clampf(yaw_kick + side * impact * KICK_MAX, -KICK_MAX, KICK_MAX)
			lose_control = LOSE_TIME
			if crash_cool <= 0.0:
				speed *= lerpf(0.9, 0.72, impact)
				crash_cool = 0.35
		else:
			# 本车撞向对方（追尾前车 / 正面）：掉速，正面更重
			if crash_cool <= 0.0:
				speed *= lerpf(0.82, 0.5, impact) * (0.85 if head_on else 1.0)
				crash_cool = 0.35
	else:
		# 撞静态护栏/道具：只掉速，横向顺墙滑由 step 的软墙逻辑处理
		if crash_cool <= 0.0:
			speed *= lerpf(0.82, 0.55, impact)
			crash_cool = 0.35

func _update_visual(delta: float) -> void:
	# 刚体朝向只在 _physics_process 里按 yaw 同步；这里是 idle 帧，
	# 直接写刚体 rotation 会覆盖物理位姿、把速度积分结果冲掉，故只动模型子节点。
	bounce = maxf(0.0, bounce - delta * 4.0)
	if model:
		model.rotation.y = slide
		var kick := clampf(absf(speed) / 18.0, 0.0, 1.0)
		model.position.y = 0.02 + sin(Time.get_ticks_msec() * 0.02) * 0.01 * kick
		model.rotation.z = -throttle * 0.06 + brake * 0.08 + bounce * 0.12
		model.rotation.x = kick * 0.03
	for fx in exhausts:
		fx.set_drive(throttle, speed, nitro_time > 0.0 or boost_on_now, offroad_now)

## 点一下氮气：当场给一脚速度，然后 1 秒里持续猛推，之后进冷却
func _fire_nitro() -> void:
	boost_fuel = maxf(0.0, boost_fuel - NITRO_COST)
	nitro_time = NITRO_BURST
	nitro_cool = NITRO_COOLDOWN
	speed = minf(speed + NITRO_KICK, BOOST_SPEED)

## AI：沿路径找前视点，按曲率决定油门。
func drive_ai(delta: float, race_time: float, look: float, skill: float) -> void:
	var info := path.at(progress + look)
	var target: Vector3 = info[0]
	var dir := (target - position)
	var want_yaw := atan2(dir.x, dir.z)
	var diff := wrapf(want_yaw - yaw, -PI, PI)
	steer = clampf(-diff * 1.7, -1.0, 1.0)
	var curve := absf(wrapf(atan2(path.at(progress + look + 12.0)[1].x, path.at(progress + look + 12.0)[1].z) - want_yaw, -PI, PI))
	var target_speed := MAX_SPEED * skill * (1.0 - clampf(curve * 1.1, 0.0, 0.55))
	if speed < target_speed:
		throttle = 1.0
		brake = 0.0
	elif speed > target_speed + 3.0:
		throttle = 0.0
		brake = 0.6
	else:
		throttle = 0.25
		brake = 0.0
	# 被撞失控：短暂收油、舵不强行修正，让车滑一段再回线
	if lose_control > 0.0:
		throttle = minf(throttle, 0.3)
		steer *= 0.4
	step(delta, race_time)
