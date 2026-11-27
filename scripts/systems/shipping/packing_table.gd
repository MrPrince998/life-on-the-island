class_name PackingTable
extends Interactable
## The packing table by the farm's east gate: press E to see today's shipping orders and
## pack one into a crate (PackingPanel). Packed crates wait on the table until you lift
## them. Carrying a crate, press E here to set it back down.

const TOP_HEIGHT := 0.9
const WOOD := Color(0.55, 0.37, 0.22)
const DARK_WOOD := Color(0.38, 0.25, 0.15)

var _rack: CrateRack
var _panel: PackingPanel


func _init() -> void:
	super._init()
	prompt_text = "Look at the shipping orders"
	interaction_id = &"packing_table"


func _ready() -> void:
	_build()
	var reach := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 2.0, 2.2)
	reach.shape = box
	reach.position.y = 1.0
	add_child(reach)
	_rack = CrateRack.new()
	_rack.name = "Rack"
	_rack.location = ShippingCrate.Location.TABLE
	_rack.slots = PackedVector3Array([Vector3(-0.42, TOP_HEIGHT + 0.03, 0.0), Vector3(0.42, TOP_HEIGHT + 0.03, 0.0)])
	add_child(_rack)


func get_crates() -> Array[ShippingCrate]:
	return _rack.get_crates() if _rack else ([] as Array[ShippingCrate])


func free_slot() -> int:
	return _rack.free_slot() if _rack else -1


func place(crate: ShippingCrate, slot: int = -1) -> bool:
	return _rack.place(crate, slot) if _rack else false


func get_prompt() -> String:
	var carry := PlayerCarry.find(get_tree().get_first_node_in_group(&"player"))
	if carry and carry.is_carrying():
		return "Set the crate back on the table" if free_slot() >= 0 else "The table is full"
	var yard := get_yard()
	var count := yard.orders.size() if yard else 0
	if count == 0:
		return "First shipping orders arrive tomorrow morning" if ActivityClock.get_day() < ShippingYard.FIRST_ORDER_DAY else "Packing table · no orders right now"
	return "Look at the shipping orders (%d)" % count


## Free hands open the orders; full hands can set a crate back on the table.
func can_interact_now(player: Node) -> bool:
	var carry := PlayerCarry.find(player)
	return carry != null and not carry.is_pushing()


func get_yard() -> ShippingYard:
	return get_parent() as ShippingYard


func _on_interact(interactor: Node) -> void:
	var carry := PlayerCarry.find(interactor)
	if carry and carry.is_carrying():
		if free_slot() >= 0:
			carry.put_down_into(self)
		return
	if get_yard() == null:
		return
	if ActivityClock.get_day() < ShippingYard.FIRST_ORDER_DAY and get_yard().orders.is_empty():
		GameManager.notify("Captain Marlow's first shipping orders arrive tomorrow morning.")
		return
	open_panel()


func open_panel() -> PackingPanel:
	if _panel == null or not is_instance_valid(_panel):
		_panel = PackingPanel.new()
		_panel.name = "PackingPanel"
		add_child(_panel)
	_panel.open(get_yard())
	return _panel


func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, TOP_HEIGHT - 0.04, 0), Vector3(1.8, 0.08, 0.85), WOOD)
	for x: float in [-0.8, 0.8]:
		for z: float in [-0.34, 0.34]:
			_box(st, Vector3(x, (TOP_HEIGHT - 0.08) * 0.5, z), Vector3(0.09, TOP_HEIGHT - 0.08, 0.09), DARK_WOOD)
	_box(st, Vector3(0, 0.25, 0), Vector3(1.6, 0.05, 0.7), DARK_WOOD)  # lower shelf
	# A roll of twine and a little stack of labels.
	_box(st, Vector3(0.0, TOP_HEIGHT + 0.03, 0.3), Vector3(0.22, 0.03, 0.14), Color(0.93, 0.89, 0.78))
	st.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.85
	var mesh := MeshInstance3D.new()
	mesh.name = "Table"
	mesh.mesh = st.commit()
	mesh.material_override = material
	add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, TOP_HEIGHT, 0.85)
	shape.shape = box
	shape.position.y = TOP_HEIGHT * 0.5
	body.add_child(shape)
	add_child(body)


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var cube := BoxMesh.new()
	cube.size = size
	var data := cube.get_mesh_arrays()
	var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	for index in indices:
		st.set_color(color)
		st.add_vertex(verts[index] + center)
