extends Node3D

# A named place that shows on the town map (M and the Tab sheet) as a dot with its name, for places added at runtime
# rather than built into the town (the Goblin Clockyard, scripts/bosses.gd). The map reads the "map_landmarks" group.

@export var label := ""


func _ready() -> void:
	add_to_group("map_landmarks")


func map_name() -> String:
	return label
