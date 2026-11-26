extends CanvasLayer
## Basic HUD: clock and date, current region, interaction prompt,
## short notifications.
## The HUD only *displays* time. It never changes it.
## Styled by the cozy theme (assets/ui/cozy_theme.tres).

const SUN := preload("res://assets/ui/icons/sun.svg")
const MOON := preload("res://assets/ui/icons/moon.svg")
const CLOUD := preload("res://assets/ui/icons/cloud.svg")
const RAIN := preload("res://assets/ui/icons/rain.svg")
const SNOW := preload("res://assets/ui/icons/snow.svg")

@onready var _time_label: Label = %TimeLabel
@onready var _date_label: Label = %DateLabel
@onready var _region_label: Label = %RegionLabel
@onready var _clock_panel: Control = %ClockPanel
@onready var _region_title: Label = %RegionTitle
@onready var _toast_panel: Control = %ToastPanel
@onready var _toast_label: Label = %ToastLabel
@onready var _prompt_panel: Control = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel
@onready var _prompt_key: Label = %PromptKey
@onready var _clock_icon: TextureRect = %ClockIcon
@onready var _coin_panel: Control = %CoinPanel
@onready var _coin_label: Label = %CoinLabel
@onready var _saved_panel: Control = %SavedPanel
@onready var _mouse_hint: Control = %MouseHint

var _toast_tween: Tween
var _region_tween: Tween
var _clock_tween: Tween
var _coin_tween: Tween
var _saved_tween: Tween


func _ready() -> void:
	add_to_group(&"hud")
	ActivityClock.time_changed.connect(_on_time_changed)
	WeatherManager.weather_changed.connect(func(_w: int) -> void: _refresh_clock())
	GameManager.notification_posted.connect(show_toast)
	GameManager.region_changed.connect(_on_region_changed)
	GameManager.interaction_prompt_changed.connect(_on_prompt_changed)
	SaveManager.saved.connect(_on_saved)
	if InventoryManager.has_signal(&"money_changed"):
		InventoryManager.money_changed.connect(_on_money_changed)
		_coin_label.text = str(InventoryManager.get_money())
	else:
		_coin_panel.hide()
	_refresh_clock()
	_region_label.text = GameManager.current_region_name
	_prompt_panel.hide()
	_toast_panel.modulate.a = 0.0
	_region_title.modulate.a = 0.0


func _process(_delta: float) -> void:
	# Not while a window (shop, forge, board...) has the player: clicks go to the window then.
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	_mouse_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless" \
			and not (player and player.is_input_locked())


func show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	# Fade in while drifting up a little, wait, then fade out.
	var rest_y := _toast_rest_y()
	_toast_panel.position.y = rest_y + 12.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25)
	_toast_tween.parallel().tween_property(_toast_panel, "position:y", rest_y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)


func _on_time_changed(_day: int, _minute_of_day: int) -> void:
	_refresh_clock()
	if _clock_tween:
		_clock_tween.kill()
	_clock_panel.pivot_offset = _clock_panel.size * 0.5
	_clock_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_clock_panel.scale = Vector2(1.08, 1.08)
	_clock_tween.tween_property(_clock_panel, "scale", Vector2.ONE, 0.4)


## Where the toast sits when shown (its anchored spot near the bottom of the screen).
func _toast_rest_y() -> float:
	return (_toast_panel.get_parent() as Control).size.y + _toast_panel.offset_top


func _refresh_clock() -> void:
	_time_label.text = ActivityClock.get_time_string()
	_date_label.text = ActivityClock.get_date_string()
	var hour := ActivityClock.get_hour()
	# Rain shows day and night; otherwise the moon at night, and the day's sky by day.
	if WeatherManager.is_raining():
		_clock_icon.texture = RAIN
	elif WeatherManager.is_snowing():
		_clock_icon.texture = SNOW
	elif hour < 6 or hour >= 19:
		_clock_icon.texture = MOON
	else:
		_clock_icon.texture = CLOUD if WeatherManager.current == WeatherManager.Weather.CLOUDY else SUN
	_clock_icon.tooltip_text = WeatherManager.get_weather_name()


func _on_region_changed(_region_id: StringName, display_name: String) -> void:
	_region_label.text = display_name
	_region_title.text = display_name
	if _region_tween:
		_region_tween.kill()
	_region_tween = create_tween()
	_region_tween.tween_property(_region_title, "modulate:a", 1.0, 0.8)
	_region_tween.tween_interval(2.2)
	_region_tween.tween_property(_region_title, "modulate:a", 0.0, 1.2)


## A quiet "Game saved" note under the minimap after each save.
func _on_saved(_reason: String) -> void:
	if _saved_tween:
		_saved_tween.kill()
	_saved_tween = create_tween()
	_saved_tween.tween_property(_saved_panel, "modulate:a", 1.0, 0.25)
	_saved_tween.tween_interval(1.6)
	_saved_tween.tween_property(_saved_panel, "modulate:a", 0.0, 0.6)


## Coins: update the counter with a little hop.
func _on_money_changed(new_total: int) -> void:
	_coin_label.text = str(new_total)
	if _coin_tween:
		_coin_tween.kill()
	_coin_panel.pivot_offset = _coin_panel.size * 0.5
	_coin_panel.scale = Vector2(1.12, 1.12)
	_coin_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_coin_tween.tween_property(_coin_panel, "scale", Vector2.ONE, 0.35)


func _on_prompt_changed(text: String) -> void:
	_prompt_panel.visible = not text.is_empty()
	_prompt_key.text = "E"
	_prompt_label.text = text
