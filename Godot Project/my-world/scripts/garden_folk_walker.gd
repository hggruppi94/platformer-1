extends "res://scripts/wanderer.gd"

# One Tuftling (scripts/garden_folk.gd): wanders about near where they started, now and then trotting, and waves when
# the player comes close. Only goes where the garden says they can stand (garden.can_stand(): out of the lakes and
# streams, off steep banks). Far from the player they rest (garden_folk.gd _process() sets `resting`); while Tumble's
# hiding for his quest, he's put away (`hidden_away`) and can't be talked to.

var garden: Node3D                          # the "Tuftlings" node
var home_node: Node3D                       # their burrow, for the named ones
var resting := false
var hidden_away := false:
	set(v):
		hidden_away = v
		var t := get_node_or_null("Talk") as Area3D
		if t:
			t.monitoring = not v
		var c := get_node_or_null("Body Shape") as CollisionShape3D
		if c:
			c.disabled = v


func _init() -> void:
	wander_radius = 4.5
	walk_speed = 0.5
	run_speed = 1.5
	run_chance = 0.2
	walk_anim_speed = 1.25
	run_anim_speed = 1.3
	react_anim = "wave"
	react_sound = ""
	react_distance = 3.2
	react_cooldown = 14.0
	random_react_chance = 0.05


func _physics_process(delta: float) -> void:
	if resting or hidden_away:
		return
	super(delta)


func _start_move() -> void:
	super()
	# Somewhere they can stand, or stay put a while
	var ok: bool = garden == null or garden.call("can_stand", _target)
	var tries := 0
	while not ok and tries < 8:
		var a := randf() * TAU
		var r := sqrt(randf()) * wander_radius
		_target = _home + Vector3(cos(a) * r, 0.0, sin(a) * r)
		ok = garden.call("can_stand", _target)
		tries += 1
	if not ok:
		_start_idle()
