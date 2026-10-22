extends Node3D

# Part of the town that changes for good when a quest gets somewhere: shown once the flag is set (or the quest is
# done), hidden before. With hide_when_done, the other way round (the dim lantern that gets swapped for a lit one).
# tools/build_town.gd puts these in the town (Pip's boardwalk lanterns, Bramble's window boxes).

@export var flag := ""                             # shown once this flag is set...
@export var quest_done := ""                       # ...or once this quest is finished
@export var hide_when_done := false


func _ready() -> void:
	Dialogue.flag_set.connect(func(_f: String) -> void: refresh())
	Quests.changed.connect(func(_q: String) -> void: refresh())
	refresh()


func is_done() -> bool:
	if flag != "" and Dialogue.flags.has(flag):
		return true
	return quest_done != "" and Quests.is_done(quest_done)


func refresh() -> void:
	visible = is_done() != hide_when_done
