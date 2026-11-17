extends Node
## 模拟"手搓玩家"：一直踩死油门，用带延迟的转向追前视点，看会不会冲出赛道。
func _ready() -> void:
	var p := RacePath.new(1.0)
	var car := RaceCar.new()
	add_child(car)
	car.setup("red", p, 0.0, 0.0)
	car.started = true
	var goal := 0.0
	var max_off := 0.0
	var off_frames := 0
	for i in 3600:
		var info := p.at(car.progress + 11.0 + absf(car.speed) * 0.25)
		var dir: Vector3 = info[0] - car.position
		var diff := wrapf(atan2(dir.x, dir.z) - car.yaw, -PI, PI)
		goal = clampf(-diff * 1.1, -1.0, 1.0)
		car.steer = lerpf(car.steer, goal, 1.0 - exp(-6.0 / 60.0))
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
