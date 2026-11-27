class_name ShippingPad
extends Interactable
## The spot at the end of the shipping jetty where Captain Marlow collects crates at
## 6 PM (ShippingYard.sail_now). Carrying a crate, press E here to set it down.

const SLOTS := 6

var _rack: CrateRack


func _init() -> void:
	super._init()
	prompt_text = "Set the crate down for Captain Marlow"
	interaction_id = &"shipping_pad"


func _ready() -> void:
	var reach := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 2.0, 5.0)
	reach.shape = box
	reach.position.y = 1.0
	add_child(reach)
	_rack = CrateRack.new()
	_rack.name = "Rack"
	_rack.location = ShippingCrate.Location.PAD
	# Two rows of three on the end platform, clear of the walkway down the middle.
	_rack.slots = PackedVector3Array([
		Vector3(-1.6, 0, 0.6), Vector3(-1.6, 0, -0.3), Vector3(-1.6, 0, -1.2),
		Vector3(1.6, 0, 0.6), Vector3(1.6, 0, -0.3), Vector3(1.6, 0, -1.2),
	])
	add_child(_rack)


func get_crates() -> Array[ShippingCrate]:
	return _rack.get_crates() if _rack else ([] as Array[ShippingCrate])


func free_slot() -> int:
	return _rack.free_slot() if _rack else -1


func place(crate: ShippingCrate, slot: int = -1) -> bool:
	return _rack.place(crate, slot) if _rack else false


func get_prompt() -> String:
	return prompt_text if free_slot() >= 0 else "The jetty is full of crates"


## Only while carrying a crate.
func can_interact_now(player: Node) -> bool:
	var carry := PlayerCarry.find(player)
	return carry != null and carry.is_carrying()


func _on_interact(interactor: Node) -> void:
	var carry := PlayerCarry.find(interactor)
	if carry and carry.is_carrying() and free_slot() >= 0:
		carry.put_down_into(self)
