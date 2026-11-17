extends Node

func _ready() -> void:
	var packed: PackedScene = load("res://scenes/race.tscn")
	var scene: Node = packed.instantiate()
	add_child(scene)
	# 等启动遮罩 + 倒计时走完（splash 2s + countdown 4s）
	for i in 380:
		await get_tree().process_frame
	var pl: RaceCar = scene.get("player")
	pl.started = true
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/hud_race.png")
	# 结算态：冲线后看结果文字 + 重开按钮
	pl.finished = true
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/hud_finish.png")
	get_tree().quit()
