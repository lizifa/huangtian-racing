extends Node3D

func _ready() -> void:
	var packed: PackedScene = load("res://assets/kit/raceCarRed.glb")
	var m := packed.instantiate()
	m.scale = Vector3.ONE * 1.9
	add_child(m)
	await get_tree().process_frame
	var first := true
	var box := AABB()
	for c in m.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			var local := AABB(verts[0], Vector3.ZERO)
			for v in verts:
				local = local.expand(v)
			var world_local := AABB(mi.transform * local.position, mi.transform.basis * local.size)
			print("mesh=", c.name, " surf=", s, " local_box=", world_local.position.round(), " size=", world_local.size.round())
			if first:
				box = world_local; first = false
			else:
				box = box.merge(world_local)
	print("MERGED local pos=", box.position.round(), " size=", box.size.round())
	print("x range=", box.position.x.round(), "..", (box.position.x + box.size.x).round())
	print("y range=", box.position.y.round(), "..", (box.position.y + box.size.y).round())
	print("z range=", box.position.z.round(), "..", (box.position.z + box.size.z).round())
	get_tree().quit()
