class_name FoliageLayer
extends Resource
## One kind of scattered plant (a Tripo model) and the rules for where it grows.
## Add a new plant by making a new .tres in data/foliage/ and listing it on the
## Vegetation node in scenes/world/island.tscn.

@export var id: StringName = &""
## The model (.glb). Its first mesh and albedo texture are used.
@export var model: PackedScene
@export var count: int = 100
@export var scale_range: Vector2 = Vector2(1.0, 1.0)
## Minimum distance between two of these plants (metres).
@export var spacing: float = 2.0
## Trees and bushes keep their distance from each other across layers.
@export var blocks_others: bool = false

@export_group("Where it grows (0 = never, 1 = full density)")
@export_range(0.0, 1.0) var forest: float = 0.0
@export_range(0.0, 1.0) var hills: float = 0.0
@export_range(0.0, 1.0) var meadow: float = 0.0
@export_range(0.0, 1.0) var coast: float = 0.0
@export_range(0.0, 1.0) var village: float = 0.0
@export_range(0.0, 1.0) var lakeshore: float = 0.0
## Steep slopes and cliffs (good for rocks).
@export_range(0.0, 1.0) var rocky: float = 0.0
## The lake's edge: shallow water and the wet bank (good for reeds).
@export_range(0.0, 1.0) var lake_edge: float = 0.0
## Open lake water away from the shore (good for lily pads; use float_on_water).
@export_range(0.0, 1.0) var lake_surface: float = 0.0

@export_group("Placement")
## Sit on the lake's water surface instead of the ground (floating plants).
@export var float_on_water: bool = false
## Tilt the plant to follow the ground slope (good for ground cover).
@export var align_to_ground: bool = false
## How far to sink into the ground, as a fraction of the plant's height.
@export var sink: float = 0.02
## Squash (<1) or stretch (>1) the model vertically, e.g. to flatten mound-shaped patches.
@export var vertical_scale: float = 1.0
## Colour multiplied into every copy (to match the terrain palette).
@export var base_tint: Color = Color.WHITE
## Blend the model's green base toward the terrain grass (0 = off, 1 = full).
@export_range(0.0, 1.0) var ground_blend: float = 0.0
## Height (0-1 of the model) up to which the blend applies.
@export_range(0.0, 1.0) var ground_blend_height: float = 0.35
## Random brightness/warmth variation so copies don't look identical.
@export_range(0.0, 0.5) var tint_variation: float = 0.1

@export_group("Collision")
## Trunk radius as a fraction of the plant's scale (0 = walk through).
@export var collision_radius: float = 0.0
@export var collision_height: float = 0.5

@export_group("Woodcutting")
## Trees you can fell with an axe (ForestService). Off for bushes, rocks and small plants.
@export var choppable: bool = false
## Axe swings to fell one (a sharper axe needs fewer).
@export var chop_hits: int = 5
## Logs a felled tree is cut into (min, max).
@export var log_yield: Vector2i = Vector2i(3, 5)

@export_group("Rendering")
## Keep the model's own material (normal maps etc.) instead of the swaying foliage shader.
## Use for rocks and other solid props. Tint is not applied in this mode.
@export var use_model_material: bool = false
@export var cast_shadows: bool = true
## Hide beyond this distance (0 = always visible). Used for small ground cover.
@export var visibility_range: float = 0.0
@export var wind_strength: float = 0.04
## Height fraction (0-1) where swaying starts; trunks below it stay still.
@export_range(0.0, 1.0) var sway_start: float = 0.3

## Leaves turn orange and red in autumn (false for evergreens like pines and palms).
@export var autumn_leaves: bool = true
