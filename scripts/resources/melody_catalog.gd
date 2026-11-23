class_name MelodyCatalog
extends Resource
## All ukulele melodies (data/melodies/melody_catalog.tres).

const DEFAULT_PATH := "res://data/melodies/melody_catalog.tres"

@export var melodies: Array[MelodyData] = []

static var _shared: MelodyCatalog


static func shared() -> MelodyCatalog:
	if _shared == null:
		_shared = load(DEFAULT_PATH) as MelodyCatalog
	return _shared


func get_melody(melody_id: StringName) -> MelodyData:
	for melody in melodies:
		if melody.id == melody_id:
			return melody
	return null
