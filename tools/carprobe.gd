extends Node
func _ready() -> void:
	var p := RacePath.new(1.0)
	var car := RaceCar.new()
	add_child(car)
	car.setup("red", p, p.total - 7.0, 1.7)
	car.started = true
	car.throttle = 1.0
	var t := 0.0
	for i in 120:
		var before := p.nearest(car.position)
		car.step(1.0 / 60.0, t)
		t += 1.0 / 60.0
		if i >= 84 and i <= 100:
			print(i, " pre=", car.position.round(), " spd=", "%.2f" % car.speed, " off_before=", "%.2f" % before[1], " s_before=", "%.1f" % before[0], " after=", car.position.round())
	get_tree().quit()
