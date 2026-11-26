class_name LakesideAction
extends Interactable
## Small contextual actions owned by the lakeside project.
@export var sunset: bool = false
@export var invitation: bool = false

func get_prompt() -> String:
	var project := get_parent() as LakesideProject
	if invitation:
		return "End fishing together" if project.is_visiting() else "Invite Oliver to fish at the dock"
	return "Place bench facing sunset (15 min)" if sunset else "Place bench facing the lake (15 min)"

func _on_interact(interactor: Node) -> void:
	var project := get_parent() as LakesideProject
	if invitation:
		if project.is_visiting():
			project.end_visit()
		else:
			project.invite(interactor as PlayerController)
	else:
		project.place_bench(sunset)
