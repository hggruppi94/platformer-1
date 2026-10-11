extends Node

# Autoload "Game": the player's progress (level, XP, HP, MP) and scene changes. Lives across every scene.

signal stats_changed
signal message_posted(text: String)

var next_spawn := ""             # spawn marker name to appear at after a scene change

var level := 1
var xp := 0
var max_hp := 10
var hp := 10
var max_mp := 5
var mp := 5
var mp_level := 1                # gates MP-locked places like the Slivers

signal equipment_changed
var items: Array[String] = []    # things the player owns, e.g. "skateboard"
var riding := false              # skateboard equipped


func has_item(item: String) -> bool:
	return item in items


func give_item(item: String) -> void:
	if has_item(item):
		return
	items.append(item)
	if item == "skateboard":
		message("You got a Skateboard! Press E to ride, E again to step off.")


func toggle_skateboard() -> void:
	if not has_item("skateboard"):
		message("You don't have a skateboard yet. There's one at the Skate Park!")
		return
	riding = not riding
	equipment_changed.emit()


func xp_to_next() -> int:
	return 10 * level


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		_level_up()
	stats_changed.emit()


func _level_up() -> void:
	level += 1
	max_hp += 5
	hp = max_hp
	max_mp += 3
	mp = max_mp
	mp_level += 1
	message("Level up! You're now Lv %d (MP Lv %d)." % [level, mp_level])


func message(text: String) -> void:
	message_posted.emit(text)


func go(scene_path: String, spawn: String, place_name := "") -> void:
	if not ResourceLoader.exists(scene_path):
		message(("The %s isn't open yet." % place_name) if place_name != "" else "This door doesn't open yet.")
		return
	next_spawn = spawn
	get_tree().call_deferred("change_scene_to_file", scene_path)


func _unhandled_input(event: InputEvent) -> void:
	# Temporary until enemies drop XP: press X for 10 XP
	if event.is_action_pressed("debug_xp"):
		add_xp(10)
	if event.is_action_pressed("toggle_skateboard"):
		toggle_skateboard()
