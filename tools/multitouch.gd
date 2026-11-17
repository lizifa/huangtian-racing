extends Node

var r: Node

func _tp(pos: Vector2, pressed: bool, idx: int) -> void:
	var sc: Vector2 = get_viewport().get_visible_rect().size / Vector2(get_window().size)
	var t := InputEventScreenTouch.new()
	t.index = idx
	t.pressed = pressed
	t.position = pos / sc
	Input.parse_input_event(t)

func _ready() -> void:
	r = load("res://scenes/race.tscn").instantiate()
	add_child(r)
	await get_tree().create_timer(4.6).timeout
	var jc: Vector2 = r.joystick.get_global_rect().get_center()
	var bc: Vector2 = r.pads["brake"].get_global_rect().get_center()
	# 第一根手指按住摇杆并上推
	_tp(jc, true, 0)
	await get_tree().create_timer(0.15).timeout
	# 拖动上推
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = (jc + Vector2(0, -60)) / (get_viewport().get_visible_rect().size / Vector2(get_window().size))
	Input.parse_input_event(drag)
	await get_tree().create_timer(0.1).timeout
	# 第二根手指按刹车
	_tp(bc, true, 1)
	await get_tree().create_timer(0.3).timeout
	print("joystick active=", r.joystick.active, " throttle=", r.joy_throttle,
		" | brake pad down=", r.pads["brake"].down, " player.brake=", r.player.brake)
	_tp(bc, false, 1)
	_tp(jc, false, 0)
	get_tree().quit()
