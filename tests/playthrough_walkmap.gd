extends RefCounted
## "Could a player walk there?" for the playthrough bot (tests/playthrough.gd).
##
## Flood-fills a 1 m grid over the island from a start point, using the real physics
## world: a cell is standable when a ray from the sky lands on a floor that isn't too
## steep and isn't under deep water; you can step to a neighbour when it is at most a
## jump higher and no wall blocks the way (two horizontal rays, knee and chest height).
## Doors and the rowboat are links (from -> to). Approximate on purpose: it is there to
## catch soft-locks (a quest target nobody could reach), not to judge every pebble.

const CELL := 1.0
const HALF := 235
## Highest step up between neighbouring cells (the jump clears about 1.3 m).
const MAX_RISE := 1.1
## Floor no steeper than the player's floor_max_angle (48 degrees).
const MIN_NORMAL_Y := 0.66
const MAX_WATER := 1.25
## Willow Creek turns you back sooner (PlayerController.max_creek_depth).
const MAX_CREEK := 0.5
const SKY := 120.0

var _space: PhysicsDirectSpaceState3D
var _tree: SceneTree
var _exclude: Array[RID] = []
var _n := HALF * 2 + 1
## Per cell: NAN = not looked at yet, -INF = not standable, else floor height.
var _h := PackedFloat32Array()
var _reach := PackedByteArray()
var reached_cells := 0


func build(space: PhysicsDirectSpaceState3D, tree: SceneTree, exclude: Array[RID], start: Vector3, links: Array) -> void:
	_space = space
	_tree = tree
	_exclude = exclude
	_h.resize(_n * _n)
	_h.fill(NAN)
	_reach.resize(_n * _n)
	_reach.fill(0)
	reached_cells = 0
	var queue := PackedInt32Array()
	var head := 0
	var first := _nearest_standable(start)
	if first < 0:
		return
	_reach[first] = 1
	queue.append(first)
	var pending_links := links.duplicate()
	while true:
		while head < queue.size():
			var c := queue[head]
			head += 1
			reached_cells += 1
			var ci := c % _n
			var cj := c / _n
			var ch := _h[c]
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = ci + d.x
				var nj: int = cj + d.y
				if ni < 0 or nj < 0 or ni >= _n or nj >= _n:
					continue
				var nc := nj * _n + ni
				if _reach[nc] == 1:
					continue
				var nh := _height(nc)
				if nh == -INF or nh - ch > MAX_RISE:
					continue
				if not _clear_between(_pos(ci, cj, ch), _pos(ni, nj, nh)):
					continue
				_reach[nc] = 1
				queue.append(nc)
		# Doors / boats whose near end is now reachable open up their far end.
		var opened := false
		for link in pending_links.duplicate():
			if is_reachable(link[0], 2.5):
				pending_links.erase(link)
				var far := _nearest_standable(link[1])
				if far >= 0 and _reach[far] == 0:
					_reach[far] = 1
					queue.append(far)
					opened = true
		if not opened:
			break


## True when some reached cell is within `radius` metres (and about the same height).
func is_reachable(point: Vector3, radius: float = 2.5) -> bool:
	var ci := roundi(point.x / CELL) + HALF
	var cj := roundi(point.z / CELL) + HALF
	var r := ceili(radius / CELL)
	for dj in range(-r, r + 1):
		for di in range(-r, r + 1):
			var i := ci + di
			var j := cj + dj
			if i < 0 or j < 0 or i >= _n or j >= _n:
				continue
			var c := j * _n + i
			if _reach[c] == 1 and absf(_h[c] - point.y) < 3.0 and Vector2(di, dj).length() * CELL <= radius:
				return true
	return false


func _nearest_standable(point: Vector3) -> int:
	var ci := roundi(point.x / CELL) + HALF
	var cj := roundi(point.z / CELL) + HALF
	for r in 4:
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				var i := ci + di
				var j := cj + dj
				if i < 0 or j < 0 or i >= _n or j >= _n:
					continue
				var c := j * _n + i
				var h := _height(c)
				if h != -INF and absf(h - point.y) < 3.0:
					return c
	return -1


func _pos(i: int, j: int, h: float) -> Vector3:
	return Vector3((i - HALF) * CELL, h, (j - HALF) * CELL)


func _height(c: int) -> float:
	var h := _h[c]
	if not is_nan(h):
		return h
	var p := _pos(c % _n, c / _n, 0.0)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, SKY, p.z), Vector3(p.x, -40.0, p.z), 1, _exclude)
	var hit := _space.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).y < MIN_NORMAL_Y:
		h = -INF
	else:
		var ground: Vector3 = hit.position
		var wadeable := WaterBody.deepest_at(_tree, ground) <= MAX_WATER and IslandShape.shared().get_creek_depth(ground) <= MAX_CREEK
		h = ground.y if wadeable else -INF
	_h[c] = h
	return h


func _clear_between(a: Vector3, b: Vector3) -> bool:
	for up in [0.55, 1.3]:
		var from: Vector3 = a + Vector3.UP * up
		var to: Vector3 = b + Vector3.UP * up
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, _exclude)
		if not _space.intersect_ray(query).is_empty():
			return false
		query = PhysicsRayQueryParameters3D.create(to, from, 1, _exclude)
		if not _space.intersect_ray(query).is_empty():
			return false
	return true
