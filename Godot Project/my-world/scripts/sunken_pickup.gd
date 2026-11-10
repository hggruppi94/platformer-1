extends Node3D

# One sunken secret on the bottom of deep water (scripts/sunken_secrets.gd puts them in): it turns and bobs slowly
# and glows, so it shows from the top. Swim down to it and it's yours. The same script, with no id, is the "reader"
# a found secret is read out by (Dialogue.say needs a talker with begin_talk() and end_talk()).

var id := ""
var owner_node: Node
var _t := 0.0


func _ready() -> void:
	_t = randf() * TAU


func _process(delta: float) -> void:
	if id == "":
		return
	_t += delta
	var m := get_child(0) as Node3D if get_child_count() > 0 else null
	if m:
		m.rotation.y = _t * 0.8
		m.position.y = sin(_t * 1.5) * 0.08
	if owner_node and owner_node.reached(self):
		owner_node.pick_up(id, global_position)
		queue_free()


func begin_talk() -> void:
	pass


func end_talk() -> void:
	pass
