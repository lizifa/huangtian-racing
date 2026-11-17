extends Node
## 模拟"手很糙"的玩家：油门踩死，转向只有 0.4 增益还反应慢，看能不能不出界。
func _ready() -> void:
	var p := RacePath.new(1.0)
	var car := RaceCar.new()
	add_child(car)
	car.setup("red", p, 0.0, 0.0)
	car.started = true
	var max_off := 0.0
	var off_frames := 0
	for i in 3600:
		var info := p.at(car.progress + 8.0 + absf(car.speed) * 0.2)
		var dir: Vector3 = info[0] - car.position
		var diff := wrapf(atan2(dir.x, dir.z) - car.yaw, -PI, PI)
		car.steer = lerpf(car.steer, clampf(-diff * 0.45, -1.0, 1.0), 1.0 - exp(-3.0 / 60.0))
		car.throttle = 1.0
		car.step(1.0 / 60.0, float(i) / 60.0)
		var off: float = absf(p.nearest(car.position)[1])
		max_off = maxf(max_off, off)
		if off > RacePath.ROAD_HALF:
			off_frames += 1
		if i % 300 == 0:
			print(i, " spd=", "%.1f" % car.speed, " off=", "%.2f" % off, " lap=", car.lap)
	print("max_off=", "%.2f" % max_off, " off_frames=", off_frames, " laps=", car.lap)
	get_tree().quit()
