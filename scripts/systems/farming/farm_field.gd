class_name FarmField
extends Node3D
## Grandpa's farm on the Sunflower Fields: owns the garden beds (FarmPlot children),
## grows them when in-game time moves on, and saves their state.
##
## Growth listens to ActivityClock.time_advanced, so crops grow only while activities
## pass time (sleeping, fishing, resting...). Walking around never grows anything.
## Rain and snow (WeatherManager) water every dug bed for you.
## Saved by SaveManager through the "persistent" group (save key "farm").

signal plot_changed(plot: FarmPlot)

const SAVE_VERSION := 1


func _ready() -> void:
	add_to_group(&"persistent")
	add_to_group(&"farm_field")
	ActivityClock.time_advanced.connect(_on_time_advanced)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	if WeatherManager.is_wet():
		_rain_on_beds()
	for plot in get_plots():
		plot.changed.connect(func(p: FarmPlot) -> void: plot_changed.emit(p))
	GameManager.flag_changed.connect(_on_flag_changed)
	_update_sunflower_border()


## Mia's "Sunny Seeds" reward: a row of tall sunflowers along the fence by the gate.
const SUNFLOWER_FLAG := &"mia_sunny_seeds_done"
var _sunflowers: Node3D


func _on_flag_changed(flag: StringName, _value: bool) -> void:
	if flag == SUNFLOWER_FLAG:
		_update_sunflower_border()


func _update_sunflower_border() -> void:
	var on := GameManager.has_flag(SUNFLOWER_FLAG)
	if on and _sunflowers == null:
		_sunflowers = Node3D.new()
		_sunflowers.name = "SunflowerBorder"
		add_child(_sunflowers)
		var mesh := CropVisuals.crop_mesh(&"sunflower", CropData.Stage.READY)
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for z in [-10.0, -8.8, -7.6, -6.4, -5.2, 5.2, 6.4, 7.6, 8.8, 10.0]:
			var flower := MeshInstance3D.new()
			flower.mesh = mesh
			var local := Vector3(-12.2 + rng.randf_range(-0.15, 0.15), 0.0, z)
			var world := to_global(local)
			flower.position = local
			flower.position.y = IslandShape.shared().get_height(world.x, world.z) - global_position.y
			# Facing the farm path coming in through the gate.
			flower.rotation.y = -PI * 0.5 + rng.randf_range(-0.3, 0.3)
			var s := rng.randf_range(1.05, 1.3)
			flower.scale = Vector3(s, s, s)
			_sunflowers.add_child(flower)
	if _sunflowers:
		_sunflowers.visible = on


func get_plots() -> Array[FarmPlot]:
	var result: Array[FarmPlot] = []
	for node in find_children("*", "FarmPlot", true, false):
		result.append(node as FarmPlot)
	return result


func get_plot(plot_id: StringName) -> FarmPlot:
	for plot in get_plots():
		if plot.interaction_id == plot_id:
			return plot
	return null


func _on_time_advanced(minutes: int, _activity_id: StringName) -> void:
	# While it rains, the beds stay soaked for the whole time that passes.
	if WeatherManager.is_wet():
		_rain_on_beds()
	for plot in get_plots():
		plot.grow(minutes)
	# ...and are still soaked when it stops.
	if WeatherManager.is_wet():
		_rain_on_beds()


func _on_weather_changed(_weather: int) -> void:
	if WeatherManager.is_wet():
		_rain_on_beds()


func _rain_on_beds() -> void:
	for plot in get_plots():
		plot.rain()


# ---- SaveManager hook ---------------------------------------------------------------

func get_save_key() -> String:
	return "farm"


func save_state() -> Dictionary:
	var plots := {}
	for plot in get_plots():
		if plot.interaction_id != &"":
			plots[String(plot.interaction_id)] = plot.to_dict()
	return {"version": SAVE_VERSION, "plots": plots}


func load_state(data: Dictionary) -> void:
	var plots: Variant = data.get("plots", {})
	if typeof(plots) != TYPE_DICTIONARY:
		push_warning("FarmField: farm save has no plot list; keeping the farm as it is.")
		return
	for plot in get_plots():
		var key := String(plot.interaction_id)
		if (plots as Dictionary).has(key) and typeof(plots[key]) == TYPE_DICTIONARY:
			plot.from_dict(plots[key])
		else:
			plot.reset()
