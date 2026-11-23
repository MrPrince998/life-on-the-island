@tool
class_name CreekWater
extends MeshInstance3D
## The water surface of Willow Creek: a ribbon that follows the creek's centre line
## (IslandShape.creek_samples) at its water level, from the beach where it meets the sea
## to where it runs into the lake, built in code so it always matches the carved
## channel. Uses the lake's water material.

## Ribbon half-width; a little wider than the water so it tucks under the banks.
@export var half_width: float = IslandShape.CREEK_HALF_WIDTH + 0.9
@export var rebuild: bool = false:
	set(value):
		if value:
			build()


func _ready() -> void:
	build()


func build() -> void:
	var shape := IslandShape.shared()
	var samples := shape.creek_samples
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in samples.size():
		var s := samples[i]
		var p := Vector2(s.x, s.y)
		# Stop once the creek has run into the lake (the lake's own surface takes over).
		if shape.get_lake_distance(p) < 0.9:
			break
		# The west end runs out into the sea: the sea's own surface covers it there.
		if s.z < IslandShape.SEA_LEVEL + 0.15:
			continue
		var a := samples[maxi(i - 1, 0)]
		var b := samples[mini(i + 1, samples.size() - 1)]
		var tangent := Vector2(b.x - a.x, b.y - a.y).normalized()
		var side := Vector2(-tangent.y, tangent.x) * half_width
		left.append(Vector3(p.x + side.x, s.z, p.y + side.y))
		right.append(Vector3(p.x - side.x, s.z, p.y - side.y))
	for i in left.size() - 1:
		for v in [left[i], right[i], left[i + 1], right[i], right[i + 1], left[i + 1]]:
			st.set_uv(Vector2((v as Vector3).x, (v as Vector3).z) * 0.1)
			st.add_vertex(v)
	st.generate_tangents()
	mesh = st.commit()


## Water level of the creek at a world point (or -INF away from the creek).
static func level_at(p: Vector2) -> float:
	var info := IslandShape.shared().get_creek_info(p)
	return info.y if info.x < IslandShape.CREEK_HALF_WIDTH else -INF
