extends Node
func _ready() -> void:
	var p := RacePath.new(1.0)
	var car := RaceCar.new()
	add_child(car)
	car.setup("red", p, 0.0, 0.0)
	car.started = true
	# 模拟"一直踩死油门不转向"，看会不会无限远离赛道
	var max_off := 0.0
	var off_frames := 0
	for i in 1800:
		car.throttle = 1.0
		car.step(1.0 / 60.0, float(i) / 60.0)
		var off: float = absf(car.path.nearest(car.position)[1])
		max_off = maxf(max_off, off)
		if off > RacePath.ROAD_HALF:
			off_frames += 1
		if i % 300 == 0:
			print(i, " spd=", "%.1f" % car.speed, " off=", "%.2f" % off, " s=", "%.1f" % car.progress, " yaw=", "%.2f" % car.yaw, " th=", car.throttle)
	print("max_off=", "%.2f" % max_off, " off_frames=", off_frames)
	get_tree().quit()
