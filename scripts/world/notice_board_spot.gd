class_name NoticeBoardSpot
extends Interactable
## The village mailbox: press E to read today's requests (RequestBoardPanel).
## A "!" floats above the mailbox while new requests are waiting. Reading costs no time.

const MARKER_HEIGHT := 1.8

var _marker: Label3D
var _bob := 0.0


func _ready() -> void:
	if prompt_text == "Interact":
		prompt_text = "Check village requests"
	_marker = Label3D.new()
	_marker.name = "NewMarker"
	_marker.text = "!"
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.font_size = 96
	_marker.outline_size = 22
	_marker.modulate = Color(1.0, 0.82, 0.3)
	_marker.outline_modulate = Color(0.35, 0.2, 0.08)
	_marker.pixel_size = 0.004
	_marker.no_depth_test = false
	_marker.position = Vector3(0, MARKER_HEIGHT, 0)
	add_child(_marker)
	RequestBoard.board_changed.connect(_refresh_marker)
	ActivityClock.day_started.connect(func(_day: int) -> void: _refresh_marker())
	_refresh_marker()


func get_prompt() -> String:
	var waiting := RequestBoard.get_requests().size()
	if waiting > 0:
		return "%s (%d request%s)" % [prompt_text, waiting, "" if waiting == 1 else "s"]
	return prompt_text


func _on_interact(interactor: Node) -> void:
	var panel := get_tree().get_first_node_in_group(&"request_board_panel")
	if panel and panel.has_method(&"open"):
		panel.call(&"open", interactor)


func has_marker() -> bool:
	return _marker.visible


func _refresh_marker() -> void:
	_marker.visible = RequestBoard.has_news()


func _process(delta: float) -> void:
	if _marker.visible:
		_bob += delta
		_marker.position.y = MARKER_HEIGHT + sin(_bob * 2.2) * 0.08
