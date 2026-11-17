extends Node
## 核对路边道具静态盒：独立 StaticBody 按世界 AABB 生成，这里把盒与就近网格包络配对比较。

var scene: Node

func _ready() -> void:
	scene = load("res://scenes/race.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout

	# 所有网格世界 AABB（按最近节点归属）
	var meshes: Array = []
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var a := _aabb_from_mesh(m)
		if a.size.length() > 0.01:
			meshes.append({"aabb": a, "node": m})

	var bodies := scene.find_children("*", "StaticBody3D", true, false)
	var n := 0
	var unmatched_box := 0
	for b in bodies:
		var body: StaticBody3D = b
		if body.name == "Ground":
			continue
		var box := _box_world(body)
		if box.size.length() < 0.01:
			continue
		n += 1
		# 最近网格
		var best: Dictionary = {}
		var best_d := 1e9
		for me in meshes:
			var d: float = me.aabb.get_center().distance_to(box.get_center())
			if d < best_d:
				best_d = d; best = me
		if best_d > 1.0:
			unmatched_box += 1
			print("[box] 无就近网格 d=%.2f box=%s size=%s" % [best_d, _fmt(box), _sz(box)])
			continue
		print("[pair] mesh_size=%s box_size=%s 中心距=%.2f" % [_sz(best.aabb), _sz(box), best_d])
	print("total boxes=", n, " unmatched=", unmatched_box)
	get_tree().quit()

func _aabb_from_mesh(m: MeshInstance3D) -> AABB:
	var a: AABB = m.get_aabb()
	var merged := AABB()
	var first := true
	for k in range(8):
		var c: Vector3 = m.global_transform * a.get_endpoint(k)
		if first:
			merged = AABB(c, Vector3.ZERO); first = false
		else:
			merged = merged.expand(c)
	return merged

func _box_world(body: StaticBody3D) -> AABB:
	var merged := AABB()
	var first := true
	for sh in body.find_children("*", "CollisionShape3D", true, false):
		var s: CollisionShape3D = sh
		var box := s.shape as BoxShape3D
		if box == null: continue
		var half := box.size * 0.5
		for dx in [-1.0, 1.0]:
			for dy in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					var local := s.position + Vector3(dx * half.x, dy * half.y, dz * half.z)
					var c: Vector3 = s.global_transform * local
					if first:
						merged = AABB(c, Vector3.ZERO); first = false
					else:
						merged = merged.expand(c)
	return merged

func _fmt(a: AABB) -> String:
	return "lo=%s hi=%s" % [a.position.snapped(Vector3.ONE*0.02), (a.position+a.size).snapped(Vector3.ONE*0.02)]

func _sz(a: AABB) -> String:
	return str(a.size.snapped(Vector3.ONE*0.02))
