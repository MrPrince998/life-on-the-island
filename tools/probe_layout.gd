extends SceneTree
## Dev tool: prints terrain heights at key layout points and an ASCII map.
## Run: Godot --headless --path . --script res://tools/probe_layout.gd

func _init() -> void:
	var s := IslandShape.new()
	var t0 := Time.get_ticks_msec()
	var count := 0
	for zi in 321:
		for xi in 321:
			s.get_height(-320 + xi * 2, -320 + zi * 2)
			count += 1
	print("heights: %d samples in %d ms" % [count, Time.get_ticks_msec() - t0])
	t0 = Time.get_ticks_msec()
	for zi in 321:
		for xi in 321:
			s.distance_to_paths(Vector2(-320 + xi * 2, -320 + zi * 2))
	print("path dist: %d ms" % [Time.get_ticks_msec() - t0])
	var points := {
		"village": Vector2(0, 115), "spawn": Vector2(-4, 100), "cottage": Vector2(-24, 100),
		"farm": Vector2(115, 70), "headland": Vector2(172, -92), "hills": Vector2(-20, -125), "forest": Vector2(-115, -20),
	}
	for key in points:
		var p: Vector2 = points[key]
		print("%-10s %s h=%.2f" % [key, p, s.get_height(p.x, p.y)])
	for z in range(40, 76, 2):
		print("dock line x=10 z=%d h=%.2f" % [z, s.get_height(10, z)])
	# ASCII map: ~ sea, . beach, w lake, digits = height/5
	for zi in range(-300, 301, 12):
		var line := ""
		for xi in range(-300, 301, 6):
			var h := s.get_height(xi, zi)
			var lake := Vector2(xi, zi).distance_to(IslandShape.LAKE_CENTER) < IslandShape.LAKE_RADIUS * 1.1 and h < IslandShape.LAKE_LEVEL
			if lake: line += "w"
			elif h < 0.0: line += "~"
			elif h < 2.0: line += "."
			else: line += str(mini(int(h / 4.0), 9))
		print(line)
	# lake-square puddle check
	var puddles := 0
	for zi in range(-40, 70):
		for xi in range(-40, 60):
			var d := Vector2(xi, zi).distance_to(IslandShape.LAKE_CENTER)
			if d > IslandShape.LAKE_RADIUS and s.get_height(xi, zi) < IslandShape.LAKE_LEVEL + 0.05:
				puddles += 1
	print("points below lake level outside lake radius: ", puddles)
	quit()
