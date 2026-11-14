extends Node3D

# A Sliver: a narrow shimmering slit into a secret area. Sealed until the player's MP level is high enough.
# Expects children: Blocker (StaticBody3D with a CollisionShape3D), Glow (MeshInstance3D), Sense (Area3D), Sign (Label3D).
#
# Every time she squeezes in through an open Sliver, the centipede that lives Behind the Walls gives her a little
# jumpscare (Hayden, 14 Nov 2026: "Anytime you go into the sliver, the centipede should give you a little
# jumpscare"): its head drops down on the far side right in front of her with a "BOO!", a sting, a jolt of the
# camera and a rumble, then zips back up. Kid-sized: no damage, no stopping her, over in about a second.

@export var required_mp_level := 3

@onready var blocker: CollisionShape3D = $Blocker.get_child(0)
@onready var glow: MeshInstance3D = $Glow
@onready var sign: Label3D = $Sign
var glow_mat: StandardMaterial3D
var t := 0.0
const SCARE_AGAIN := 3.0         # seconds before the same Sliver can scare her again (so stepping back and forth doesn't)
var scares := 0                  # how many times it's jumped out (tests read it)
var scare: Node3D                # the head while it's out
var _last_scare := -100.0


func _ready() -> void:
	glow_mat = (glow.material_override as StandardMaterial3D).duplicate()
	glow.material_override = glow_mat
	$Sense.body_entered.connect(_on_body_entered)
	Game.stats_changed.connect(_refresh)
	_refresh()


func is_open() -> bool:
	return Game.mp_level >= required_mp_level


func _refresh() -> void:
	var open := is_open()
	blocker.set_deferred("disabled", open)
	sign.text = "Sliver" if open else "Sliver\nMP Lv %d" % required_mp_level


func _process(delta: float) -> void:
	t += delta
	var open := is_open()
	var pulse := 0.25 if Settings.reduce_flashing or Settings.reduce_motion else 1.0
	glow_mat.emission_energy_multiplier = (3.0 if open else 0.8) + sin(t * (4.0 if open else 1.5)) * (1.0 if open else 0.3) * pulse
	glow_mat.albedo_color.a = 0.2 if open else 0.95          # open: a see-through shimmer; sealed: solid silver


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if is_open():
		Audio.play_at("sliver_open", global_position + Vector3(0, 1.5, 0))
		if _going_in(body):
			jumpscare(body)
	else:
		Audio.play_at("sliver_sealed", global_position + Vector3(0, 1.5, 0))
		Game.message("The Sliver is sealed. It opens at MP Lv %d (you're MP Lv %d)." % [required_mp_level, Game.mp_level])


func behind_dir() -> Vector3:
	# Which way is Behind the Walls from this Sliver: the side away from the middle of the school
	var across := global_transform.basis.z
	across.y = 0.0
	across = across.normalized()
	var out := global_position * Vector3(1, 0, 1)
	return across if across.dot(out) > 0.0 else -across


func _going_in(body: Node3D) -> bool:
	# Coming from the hallway side, not on the way back out
	return (body.global_position - global_position).dot(behind_dir()) < 0.0


func jumpscare(body: Node3D) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_scare < SCARE_AGAIN or (scare and is_instance_valid(scare)):
		return
	_last_scare = now
	scares += 1
	var behind := behind_dir()
	scare = Node3D.new()
	scare.name = "Jumpscare"
	add_child(scare)
	var whole := (load("res://scenes/creatures/centipede.tscn") as PackedScene).instantiate()
	var head := whole.get_node("Head") as Node3D           # only its head: the rest never enters the tree
	whole.remove_child(head)
	whole.free()
	head.position = Vector3.ZERO
	head.rotation = Vector3.ZERO
	scare.add_child(head)
	var boo := Label3D.new()
	boo.text = "BOO!"
	boo.font_size = 96
	boo.pixel_size = 0.01
	boo.outline_size = 14
	boo.modulate = Color(1.0, 0.85, 0.3)
	boo.outline_modulate = Color(0.2, 0.05, 0.25)
	boo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	boo.no_depth_test = true
	boo.position = Vector3(0, 1.1, 0)
	scare.add_child(boo)
	# It drops down from over the slit on her side of it (behind the shimmer it would be washed out), face to face with her
	var top := global_position - behind * 0.35 + Vector3(0, 4.6, 0)
	var face := global_position - behind * 0.35 + Vector3(0, 1.6, 0)
	scare.global_position = top
	var to := body.global_position - face
	scare.global_rotation = Vector3(0, atan2(to.x, to.z), 0)        # the head faces +Z
	scare.scale = Vector3.ONE * 0.6
	var tw := scare.create_tween()
	tw.tween_property(scare, "global_position", face, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(scare, "scale", Vector3.ONE * 1.15, 0.14)
	tw.tween_property(scare, "scale", Vector3.ONE, 0.12)
	tw.tween_interval(0.75)
	tw.tween_property(scare, "global_position", top, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(scare.queue_free)
	Audio.play_at("centipede_skitter", face, 4.0)
	Audio.play_at("centipede_whisper", face, 2.0, 0.05)
	Juice.blip("boink", 0.7, -2.0)
	Juice.blip("whoosh", 1.4, -4.0)
	Juice.shake(0.35)
	Juice.kick(Vector2.UP, 0.6)
	Juice.rumble(0.5, 0.25, 0.4)
