class_name FieldRow
extends Interactable
## One row of a CropField (made by the field). E does whatever the row needs next:
## plant it, cut it, or gather and tie the cut stalks. The field does the work.

var field: CropField
var index: int = 0


func can_interact_now(player: Node) -> bool:
	if field == null or field.is_busy():
		return false
	return not (player is PlayerController and (player as PlayerController).is_hands_busy())


func get_prompt() -> String:
	return field.row_prompt(index) if field else ""


func _on_interact(interactor: Node) -> void:
	if field:
		await field.act_on_row(index, interactor as PlayerController)
