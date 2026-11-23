extends Light3D
## Switches a lamp on in the evening and off in the morning, following ActivityClock.

@export var on_energy: float = 1.5
## Energy outside lamp hours (0 = switched off).
@export var off_energy: float = 0.0
@export var on_from_hour: int = 18
@export var off_from_hour: int = 7
## Optional story flag: the lamp stays dark until it's on (the village street lamps
## are relit on Market Day).
@export var requires_flag: StringName = &""


func _ready() -> void:
	ActivityClock.time_changed.connect(_on_time_changed)
	if requires_flag != &"":
		GameManager.flag_changed.connect(func(_f: StringName, _v: bool) -> void:
			_on_time_changed(ActivityClock.get_day(), ActivityClock.get_minute_of_day()))
	_on_time_changed(ActivityClock.get_day(), ActivityClock.get_minute_of_day())


func _on_time_changed(_day: int, _minute_of_day: int) -> void:
	var hour := ActivityClock.get_hour()
	var lit := hour >= on_from_hour or hour < off_from_hour
	if requires_flag != &"" and not GameManager.has_flag(requires_flag):
		light_energy = 0.0
		visible = false
		return
	light_energy = on_energy if lit else off_energy
	visible = light_energy > 0.0
