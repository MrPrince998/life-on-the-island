class_name FinaleTrigger
extends Node
## Plays the closing credits when you read Grandpa's last letter (journal page 10).
## Listens to the page itself (not the flag), so loading a finished game doesn't
## replay them.

@export var page_path: NodePath


func _ready() -> void:
	var page := get_node_or_null(page_path) as JournalPage
	if page:
		page.read.connect(func(_p: JournalPage) -> void: FinaleCredits.play(get_tree()))
