extends SceneTree
## Dev tool: prints the bounding box and triangle count of Tripo models.
## Run: Godot --headless --path . --script res://tools/measure_models.gd -- name1 name2

func _init() -> void:
	for n in OS.get_cmdline_user_args():
		var scene: PackedScene = load("res://source_assets/tripo/%s.glb" % n)
		var root := scene.instantiate() as Node3D
		get_root().add_child(root)
		var box := AABB()
		var first := true
		var tris := 0
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
			for s in m.mesh.get_surface_count():
				var arr := m.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		print("%s pos=%s size=%s tris=%d" % [n, box.position, box.size, tris])
		root.free()
	quit()
