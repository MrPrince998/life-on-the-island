class_name UpgradeData
extends Resource
## Something to spend coins on, from the General Store's Upgrades tab: better tools,
## furniture for Grandpa's cottage, more garden beds, projects for the village.
##
## Buying one sets the story flag "bought_<id>" (saved with the game). The flag is what
## makes it happen: StoryVariant nodes named after it show new furniture, beds and
## village decorations; tools are read by the systems they change (see UpgradeService).

enum Category { TOOLS, HOME, FARM, VILLAGE }

## Stable ID (saved as the flag "bought_<id>").
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.TOOLS
@export var price: int = 100
## Another upgrade that must be bought first (a better rod after the first one...).
@export var requires_upgrade: StringName = &""
## A story flag needed first (e.g. the market reopened), and how to say so.
@export var requires_flag: StringName = &""
@export var requires_text: String = ""
## Said when it's bought (who brings it, where it is).
@export_multiline var bought_message: String = ""


## The story flag set when this is bought.
func get_flag() -> StringName:
	return StringName("bought_" + String(id))


func get_category_name() -> String:
	return ["Tools", "Home", "Farm", "Village"][category]
