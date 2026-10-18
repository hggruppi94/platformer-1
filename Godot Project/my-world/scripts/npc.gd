extends Node3D

# A townsperson who stands in one spot playing one looping animation from their model (scenes/town/characters.tscn).
# With a daily routine (scripts/routine.gd) under them, the routine moves them about and picks their animations.

@export var animation := "idle"
var talking := false                    # set by their talk spot (scripts/talker.gd); a routine waits while it's on


func _ready() -> void:
	var anim_player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		push_warning("%s: no AnimationPlayer in its model" % name)
		return
	if not anim_player.has_animation(animation):
		push_warning("%s: model has no '%s' animation (has %s)" % [name, animation, anim_player.get_animation_list()])
		return
	anim_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	anim_player.play(animation)
