extends Node

func _ready() -> void:
	var s: Node = load("res://scenes/race.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(3.2).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shots/after_splash.png")
	get_tree().quit()
