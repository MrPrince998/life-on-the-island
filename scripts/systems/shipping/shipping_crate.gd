class_name ShippingCrate
extends Interactable
## A packed crate for one shipping order (see ShippingYard). Press E to lift it when
## your hands are free; then carry it (PlayerCarry), load it onto the HandCart or set it
## on the ShippingPad at the jetty. It knows where it is, for saving.

enum Location { GROUND, TABLE, CART, PAD, CARRIED }

const MODEL := preload("res://source_assets/tripo/wooden_crate.glb")
## The crate's size (metres): it sits on its base at this node's origin.
const SIZE := 0.62

var order_id: int = 0
var buyer: String = ""
var location: Location = Location.GROUND
## Slot on the table, cart or pad (-1 elsewhere).
var slot: int = -1

var _body: StaticBody3D


func _init() -> void:
	super._init()
	prompt_text = "Lift the crate"


func _ready() -> void:
	add_to_group(&"shipping_crate")
	var model := FittedModel.new()
	model.name = "Model"
	model.model = MODEL
	model.size = SIZE
	model.snap_to_ground = false
	model.collision = FittedModel.Collision.NONE
	add_child(model)
	var label := Label3D.new()
	label.name = "Label"
	label.text = buyer
	label.font_size = 22
	label.pixel_size = 0.0025
	label.outline_size = 6
	label.modulate = Color(0.32, 0.2, 0.1)
	label.outline_modulate = Color(0.95, 0.88, 0.72)
	label.position = Vector3(0, SIZE * 0.55, SIZE * 0.52)
	add_child(label)
	var reach := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.75
	reach.shape = sphere
	reach.position.y = SIZE * 0.5
	add_child(reach)
	# A solid box while it stands on the ground, so you walk round it.
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 1
	_body.collision_mask = 0
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * SIZE * 0.95
	box.shape = shape
	box.position.y = SIZE * 0.5
	_body.add_child(box)
	add_child(_body)
	set_location(location)


func set_location(where: Location, slot_index: int = -1) -> void:
	location = where
	slot = slot_index
	if _body:
		_body.collision_layer = 1 if where == Location.GROUND else 0
	monitorable = where != Location.CARRIED


func get_prompt() -> String:
	var order_text := "for %s" % buyer if buyer != "" else ""
	match location:
		Location.CART:
			return "Lift the crate off the cart %s" % order_text
		Location.PAD:
			return "Lift the crate back off the jetty"
		Location.TABLE:
			return "Lift the crate %s" % order_text
	return "Lift the crate %s" % order_text


## Only with free hands (PlayerInteraction asks this while your hands are full too).
func can_interact_now(player: Node) -> bool:
	var carry := PlayerCarry.find(player)
	return carry != null and not carry.is_hands_busy() and location != Location.CARRIED


func _on_interact(interactor: Node) -> void:
	var carry := PlayerCarry.find(interactor)
	if carry:
		carry.pick_up(self)


func to_dict() -> Dictionary:
	var where := location
	var xform := global_transform
	if where == Location.CARRIED:
		# Saved mid-carry: it'll be waiting on the ground at your feet.
		where = Location.GROUND
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		if player:
			xform = Transform3D(Basis(), player.global_position + player.global_basis.z * -0.9)
	return {
		"order_id": order_id, "buyer": buyer, "location": where, "slot": slot,
		"x": xform.origin.x, "y": xform.origin.y, "z": xform.origin.z, "yaw": xform.basis.get_euler().y,
	}
