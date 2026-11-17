extends Node

func _ready() -> void:
	var r: Node = load("res://scenes/race.tscn").instantiate()
	add_child(r)
	await get_tree().create_timer(4.2).timeout
	var pad = r.pads["brake"]
	var c: Vector2 = pad.get_global_rect().get_center()
	# 1) 直接喂给 pad
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = true
	t.position = c
	pad._gui_input(t)
	print("direct _gui_input -> down=", pad.down)
	t.pressed = false
	pad._gui_input(t)
	print("release -> down=", pad.down)
	# 2) 走鼠标点击（项目开了 emulate_touch_from_mouse）
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var ws: Vector2 = Vector2(get_window().size)
	var sc: Vector2 = vs / ws
	var wpos: Vector2 = c / sc
	print("canvas=", vs, " window=", ws, " scale=", sc, " wpos=", wpos)
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = true
	m.position = wpos
	m.global_position = wpos
	Input.parse_input_event(m)
	await get_tree().create_timer(0.2).timeout
	print("parsed mouse -> down=", pad.down)
	m.pressed = false
	Input.parse_input_event(m)
	# 3) 打印谁在这个点上
	print("hovered=", get_viewport().gui_get_hovered_control())
	get_tree().quit()
