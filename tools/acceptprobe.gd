extends Node
## 验收探针：视角键 / 赛道辅助 / 静止氮气 / 出界氮气，四件事分别量一次。

var r: Node

func _track_yaw() -> float:
	var n: Array = r.path.nearest(r.player.position)
	return atan2(n[2].x, n[2].z)

func _tap(pad_key: String, idx: int, hold: float) -> void:
	var pad = r.pads[pad_key]
	var c: Vector2 = pad.get_global_rect().get_center()
	var sc: Vector2 = get_viewport().get_visible_rect().size / Vector2(get_window().size)
	var down := InputEventScreenTouch.new()
	down.index = idx
	down.pressed = true
	down.position = c / sc
	Input.parse_input_event(down)
	await get_tree().create_timer(hold).timeout
	var up := InputEventScreenTouch.new()
	up.index = idx
	up.pressed = false
	up.position = c / sc
	Input.parse_input_event(up)

func _ready() -> void:
	r = load("res://scenes/race.tscn").instantiate()
	add_child(r)
	await get_tree().create_timer(6.6).timeout   # splash 2s + 倒计时 4s 走完才进 racing
	print("[state] ", r.state)

	# 1) 视角键
	var cam: Camera3D = r.camera
	var d0: float = cam.global_position.distance_to(r.player.position)
	await _tap("view", 7, 0.15)
	await get_tree().create_timer(1.6).timeout
	print("[view] cam_far=", r.cam_far, " dist ", snapped(d0, 0.1), " -> ",
		snapped(cam.global_position.distance_to(r.player.position), 0.1))

	# 2) 赛道辅助：把车摆回路面中央，车头偏 0.55rad，松手不管
	var p: Array = r.path.at(90.0)
	r.player.position = p[0]
	r.player.speed = 14.0
	var ty: float = atan2(p[1].x, p[1].z)
	r.player.yaw = ty + 0.55
	await get_tree().create_timer(0.05).timeout
	var err0: float = wrapf(_track_yaw() - r.player.yaw, -PI, PI)
	await get_tree().create_timer(1.0).timeout
	var err1: float = wrapf(_track_yaw() - r.player.yaw, -PI, PI)
	print("[assist] yaw err ", snapped(err0, 0.01), " -> ", snapped(err1, 0.01),
		"  1s 变化=", snapped(absf(err0) - absf(err1), 0.01), "rad speed=", snapped(r.player.speed, 0.1))

	# 3) 静止按氮气（赛道中央，速度 0）
	r.player.position = p[0]
	r.player.yaw = ty
	r.player.speed = 0.0
	r.player.boost_fuel = 1.0
	await get_tree().create_timer(0.4).timeout
	var f0: float = r.player.boost_fuel
	await _tap("nitro", 8, 1.0)
	await get_tree().create_timer(0.1).timeout
	print("[nitro@standstill] speed=", snapped(r.player.speed, 0.1),
		" fuel ", snapped(f0, 0.01), " -> ", snapped(r.player.boost_fuel, 0.01))

	# 4) 出界按氮气（草地，speed 12）
	var q: Array = r.path.at(90.0)
	var side := Vector3(-q[1].z, 0.0, q[1].x)
	r.player.position = q[0] + side * (RacePath.ROAD_HALF + 2.2)
	r.player.yaw = atan2(q[1].x, q[1].z)
	r.player.speed = 12.0
	r.player.boost_fuel = 1.0
	await get_tree().create_timer(0.4).timeout
	var f1: float = r.player.boost_fuel
	var s1: float = r.player.speed
	await _tap("nitro", 9, 1.0)
	await get_tree().create_timer(0.1).timeout
	print("[nitro@offroad] speed ", snapped(s1, 0.1), " -> ", snapped(r.player.speed, 0.1),
		" fuel ", snapped(f1, 0.01), " -> ", snapped(r.player.boost_fuel, 0.01))

	# 5) 真·点一下（80ms）：手机上没人长按氮气，短按也得蹿
	var z: Array = r.path.at(90.0)
	r.player.position = z[0]
	r.player.yaw = atan2(z[1].x, z[1].z)
	r.player.speed = 16.0
	r.player.boost_fuel = 1.0
	r.player.nitro_cool = 0.0
	r.player.nitro_time = 0.0
	await get_tree().create_timer(0.4).timeout
	var s2: float = r.player.speed
	await _tap("nitro", 10, 0.08)
	var peak: float = r.player.speed
	for i in 10:
		await get_tree().create_timer(0.1).timeout
		peak = maxf(peak, r.player.speed)
	print("[nitro@tap80ms] speed ", snapped(s2, 0.1), " -> peak ", snapped(peak, 0.1),
		" (km/h ", snapped(peak * 3.6, 1), ") nitro_time=", snapped(r.player.nitro_time, 0.01),
		" cool=", snapped(r.player.nitro_cool, 0.01))
	get_tree().quit()
