class_name NPCScheduleEntry
extends Resource
## One part of a villager's day: from `from_hour` on, they go to `position` (walking
## through `via` first, if set) and do `activity` there. Driven by the ActivityClock,
## so the day only moves on when the player does activities.

## Activities a villager can do at a spot.
const IDLE := &"idle"        ## stand, breathe, look around now and then
const SIT := &"sit"          ## sit down (bench), sit, stand up when leaving
const PLANT := &"plant"      ## kneel and plant
const WATER := &"water"      ## water the plants

@export_range(0, 23) var from_hour: int = 6
## World position on the ground (y is taken from the terrain plus height_offset).
@export var position: Vector3
## Direction to face when there: 0 = +Z, 90 = +X (degrees).
@export var facing_degrees: float = 0.0
@export var activity: StringName = IDLE
## Extra height above the terrain (e.g. sitting on a bench).
@export var height_offset: float = 0.0
## Ground points to walk through on the way here (to go round fences and beds).
@export var via: PackedVector3Array = PackedVector3Array()
