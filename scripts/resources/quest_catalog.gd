class_name QuestCatalog
extends Resource
## All quests in the game (data/quests/quest_catalog.tres).

@export var quests: Array[QuestData] = []


func get_quest(quest_id: StringName) -> QuestData:
	for quest in quests:
		if quest.id == quest_id:
			return quest
	return null
