extends Node

var r: Node

func _press(pad_key: String, pressed: bool, idx: int) -> void:
	var pad = r.pads[pad_key]
	var c: Vector2 = pad.get_global_rect().get_center()
	var sc: Vector2 = get_viewport().get_visible_rect().size / Vector2(get_window().size)
	var t := InputEventScreenTouch.new()
	t.index = idx
	t.pressed = pressed
	t.position = c / sc
	Input.parse_input_event(t)

func _ready() -> void:
	r = load("res://scenes/race.tscn").instantiate()
	add_child(r)
	await get_tree().create_timer(4.6).timeout
	print("state=", r.state)
	# 先用摇杆把车开起来
	r.joystick.active = true
	r.joystick._update_from(r.joystick.size * 0.5 + Vector2(0.0, -r.joystick.radius * 0.62))
	await get_tree().create_timer(2.5).timeout
	print("before brake: speed=", snapped(r.player.speed, 0.1), " kmh=", snapped(r.player.current_kmh(), 1))
	# 按住刹车（第二根手指）
	_press("brake", true, 2)
	await get_tree().create_timer(1.0).timeout
	print("brake down=", r.pads["brake"].down, " pad_brake=", r.player.brake, " speed=", snapped(r.player.speed, 0.1))
	_press("brake", false, 2)
	await get_tree().create_timer(1.6).timeout
	print("after release: speed=", snapped(r.player.speed, 0.1))
	# 按住氮气
	var before_boost: float = r.player.boost_fuel
	_press("nitro", true, 3)
	await get_tree().create_timer(1.0).timeout
	print("nitro down=", r.pads["nitro"].down, " boosting=", r.player.boosting, " speed=", snapped(r.player.speed, 0.1),
		" fuel=", snapped(r.player.boost_fuel, 0.01), " (before ", snapped(before_boost, 0.01), ")")
	_press("nitro", false, 3)
	# 复位键
	var before_pos: Vector3 = r.player.position
	_press("reset", true, 4)
	await get_tree().create_timer(0.3).timeout
	_press("reset", false, 4)
	print("reset moved ", snapped(before_pos.distance_to(r.player.position), 0.01), "m speed=", snapped(r.player.speed, 0.1))
	get_tree().quit()
