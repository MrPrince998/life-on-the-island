class_name MelodyData
extends Resource
## One of Grandpa's ukulele melodies: a few notes that, played in order, do something
## gentle. Add one by making a .tres in data/melodies/ and listing it in
## data/melodies/melody_catalog.tres. The effect itself lives in UkuleleController.

## Stable ID used by saves. Never rename.
@export var id: StringName = &""
@export var title: String = ""
## Scale notes 1..8 (1 = low C ... 8 = high C), as the player plays them on keys 1-8.
@export var notes: PackedInt32Array = PackedInt32Array()
## What it does: "sunset", "starlight", "rain", "serenade" or "lullaby".
@export var effect: StringName = &""
@export_multiline var description: String = ""
## Learned when this story flag is on ("" = known as soon as you have the ukulele).
@export var learn_flag: StringName = &""
## Where to learn it (shown in the song book until it's learned).
@export var hint: String = ""


## "5 3 2 1" for the song book.
func notes_text() -> String:
	var parts: Array[String] = []
	for n in notes:
		parts.append(str(n))
	return " ".join(parts)
