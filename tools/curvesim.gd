extends Node
func _ready() -> void:
	var p := RacePath.new(1.0)
	for s in [0.0, 20.0, 50.0, 90.0]:
		var a := p.at(s)
		var b := p.at(s + 10.0)
		var c := p.nearest(a[0])
		print("s=", s, " at[0]=", a[0], " at[1]=", a[1], " at.size=", a.size())
		print("   ahead[1]=", b[1], " nearest[2]=", c[2], " nearest[1]=", "%.2f" % c[1])
	get_tree().quit()
