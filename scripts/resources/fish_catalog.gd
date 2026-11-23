class_name FishCatalog
extends Resource
## The list of every fish species in the game.

@export var fish: Array[FishData] = []


func get_fish(fish_id: StringName) -> FishData:
	for entry in fish:
		if entry and entry.id == fish_id:
			return entry
	return null


## Fish that can bite in this water at this hour (and season; "" = the current one).
func available(water_id: StringName, hour: int, season_id: StringName = &"") -> Array[FishData]:
	var season := season_id if season_id != &"" else ActivityClock.get_season_id()
	var result: Array[FishData] = []
	for entry in fish:
		if entry and entry.lives_in(water_id) and entry.is_active_at_hour(hour) and entry.is_in_season(season):
			result.append(entry)
	return result


## Weighted random pick. Returns null if nothing lives here at this hour.
## A fish for this water and hour, by bite weight. `rare_bonus` (from a better rod,
## see UpgradeService.rare_bonus) scales each fish's weight by 1 + bonus × rarity, so
## uncommon and rare fish turn up more often.
func pick(water_id: StringName, hour: int, rng: RandomNumberGenerator, rare_bonus: float = 0.0) -> FishData:
	var options := available(water_id, hour)
	var total := 0.0
	for entry in options:
		total += _bite_weight(entry, rare_bonus)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for entry in options:
		roll -= _bite_weight(entry, rare_bonus)
		if roll <= 0.0:
			return entry
	return options.back()


static func _bite_weight(fish: FishData, rare_bonus: float) -> float:
	return fish.weight * (1.0 + rare_bonus * fish.rarity)
