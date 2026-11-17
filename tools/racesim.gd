extends Node
func _ready() -> void:
	var scene: Node = load("res://scenes/race.tscn").instantiate()
	add_child(scene)
	var path: RacePath = scene.get("path")
	var cars: Array = scene.get("cars")
	var rivals: Array = scene.get("rivals")
	for car in cars:
		car.started = true
	for i in 1800:
		for car in cars:
			if car.is_ai:
				car.drive_ai(1.0 / 60.0, float(i) / 60.0, 12.0, 0.9)
			else:
				car.throttle = 0.85
				car.step(1.0 / 60.0, float(i) / 60.0)
		if i % 300 == 0:
			var line := ""
			for car in cars:
				var n := path.nearest(car.position)
				var off: float = n[1]
				line += "[%s s=%.0f spd=%.1f lap=%d] " % [car.color, n[0], car.speed, car.lap]
			print(i, " ", line)
	get_tree().quit()
