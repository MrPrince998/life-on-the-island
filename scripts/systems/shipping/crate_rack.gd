class_name CrateRack
extends Node3D
## A few spots where shipping crates sit (on the packing table, the hand-cart's bed, the
## jetty pad). Crates placed here become its children, so they move with it.

## Local positions of the spots (the crate's base sits on each).
@export var slots: PackedVector3Array = PackedVector3Array()
## Which ShippingCrate.Location a crate here is in.
@export var location: int = ShippingCrate.Location.TABLE


func free_slot() -> int:
	var taken := {}
	for crate in get_crates():
		taken[crate.slot] = true
	for i in slots.size():
		if not taken.has(i):
			return i
	return -1


## How a crate sits on a spot (local to the rack): a little turned, for a hand-placed look.
func slot_transform(slot: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, 0.08 * (slot % 3) - 0.08), slots[slot])


func get_crates() -> Array[ShippingCrate]:
	var out: Array[ShippingCrate] = []
	for child in get_children():
		if child is ShippingCrate and not child.is_queued_for_deletion():
			out.append(child)
	return out


## Puts a crate on a spot (a free one when slot < 0). Returns false if there's no room.
func place(crate: ShippingCrate, slot: int = -1) -> bool:
	if slot < 0 or slot >= slots.size():
		slot = free_slot()
	if slot < 0:
		return false
	for other in get_crates():
		if other != crate and other.slot == slot:
			return false
	if crate.get_parent():
		crate.reparent(self, false)
	else:
		add_child(crate)
	crate.transform = slot_transform(slot)
	crate.set_location(location, slot)
	return true
