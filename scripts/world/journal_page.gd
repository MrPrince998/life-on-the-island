class_name JournalPage
extends Interactable
## One of Grandpa's journal pages, left where he loved to be. Press E to read it and
## keep it. Sets the story flag "journal_page_<n>" (saved with the game), so a read
## page stays gone. Reading costs no time.

signal read(page: JournalPage)

@export var page: int = 1
@export_multiline var text: String = ""


func _ready() -> void:
	if interaction_id == &"":
		interaction_id = StringName("journal_page_%d" % page)
	prompt_text = "Read Grandpa's journal page"
	GameManager.flag_changed.connect(func(_flag: StringName, _value: bool) -> void: _apply())
	_apply()


func get_flag() -> StringName:
	return StringName("journal_page_%d" % page)


func is_read() -> bool:
	return GameManager.has_flag(get_flag())


func _on_interact(_interactor: Node) -> void:
	if is_read():
		return
	GameManager.set_flag(get_flag())
	GameManager.notify("Grandpa's journal, page %d: \"%s\"" % [page, text])
	read.emit(self)


func _apply() -> void:
	var gone := is_read()
	enabled = not gone
	for child in get_children():
		if child is Node3D:
			(child as Node3D).visible = not gone
