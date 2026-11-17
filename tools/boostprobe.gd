extends Node

func _ready() -> void:
	var r: Node = load("res://scenes/race.tscn").instantiate()
	add_child(r)
	await get_tree().create_timer(4.6).timeout
	# 摆到赛道中央、给个初速
	var p: Array = r.path.at(20.0)
	r.player.position = p[0]
	r.player.yaw = atan2(p[1].x, p[1].z)
	r.player.speed = 16.0
	r.player.boosting = false
	await get_tree().create_timer(0.6).timeout
	var s0: float = r.player.speed
	var f0: float = r.player.boost_fuel
	r.pads["nitro"].press(9)
	await get_tree().create_timer(1.0).timeout
	print("boost: speed ", snapped(s0, 0.1), " -> ", snapped(r.player.speed, 0.1),
		" fuel ", snapped(f0, 0.01), " -> ", snapped(r.player.boost_fuel, 0.01),
		" boosting=", r.player.boosting, " fuel0_ring=", r.pads["nitro"].ring)
	r.pads["nitro"].release(9)
	get_tree().quit()
