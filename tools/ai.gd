extends Node
func _ready() -> void:
	var scene: Node = load("res://scenes/race.tscn").instantiate()
	add_child(scene)
	var path: RacePath = scene.get("path")
	var cars: Array = scene.get("cars")
	for car in cars:
		car.started = true
	var ai: RaceCar = cars[1]
	for i in 200:
		ai.drive_ai(1.0 / 60.0, float(i) / 60.0, 12.0, 0.9)
		if i % 20 == 0:
			var n := path.nearest(ai.position)
			print(i, " pos=", ai.position.round(), " s=", "%.1f" % n[0], " off=", "%.2f" % n[1], " yaw=", "%.2f" % ai.yaw, " want_tan=", n[2].round(), " steer=", "%.2f" % ai.steer, " spd=", "%.1f" % ai.speed)
	get_tree().quit()
