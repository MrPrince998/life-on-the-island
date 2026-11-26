class_name CartHandle
extends Interactable
## The push handles of a HandCart. Free hands: push the cart. Carrying a crate: load it
## onto the cart's bed (when there's room).

var cart: HandCart


func _init() -> void:
	super._init()
	prompt_text = "Push the cart"
	interaction_id = &"hand_cart"


func _ready() -> void:
	var reach := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.8, 3.2)
	reach.shape = box
	reach.position = Vector3(0, 0, -1.1)
	add_child(reach)


func get_prompt() -> String:
	var carry := PlayerCarry.find(get_tree().get_first_node_in_group(&"player"))
	if carry and carry.is_carrying():
		return "Load the crate onto the cart" if cart.free_slot() >= 0 else "The cart is full"
	var count := cart.get_crates().size()
	return "Push the cart" + (" (%d %s)" % [count, "crate" if count == 1 else "crates"] if count > 0 else "")


func can_interact_now(player: Node) -> bool:
	var carry := PlayerCarry.find(player)
	return carry != null and not carry.is_pushing() and not cart.is_pushed()


func _on_interact(interactor: Node) -> void:
	var carry := PlayerCarry.find(interactor)
	if carry == null:
		return
	if carry.is_carrying():
		if cart.free_slot() >= 0:
			carry.put_down_into(cart)
	else:
		carry.grab_cart(cart)
