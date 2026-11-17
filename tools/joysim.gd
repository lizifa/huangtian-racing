extends Node

func _ready() -> void:
	var r: Node = load("res://scenes/race.tscn").instantiate()
	add_child(r)
	await get_tree().create_timer(3.6).timeout
	# 模拟“摇杆上推”：等价于玩家手指向上拖
	var js = r.joystick
	js.active = true
	js._update_from(js.size * 0.5 + Vector2(0.0, -js.radius * 0.62))
	print("joy_throttle=", r.joy_throttle, " state=", r.state)
	await get_tree().create_timer(3.4).timeout
	print("speed=", snapped(r.player.speed, 0.1), " kmh=", r.player.current_kmh())
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shots/joystick_up.png")
	get_tree().quit()
