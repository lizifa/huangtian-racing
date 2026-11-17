extends Node
func _ready() -> void:
	var p := RacePath.new(1.0)
	print("total=", p.total, " pts=", p.points.size())
	for s in [0.0, 10.0, p.total - 7.0, p.total - 3.0]:
		var a := p.at(s)
		print("at ", s, " -> ", a[0], " dir=", a[1])
	var near := p.nearest(Vector3(-25.95784, 0, -14.35021))
	print("near=", near)
	get_tree().quit()
