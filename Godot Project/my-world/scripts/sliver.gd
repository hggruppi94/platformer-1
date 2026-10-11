extends Node3D

# A Sliver: a narrow shimmering slit into a secret area. Sealed until the player's MP level is high enough.
# Expects children: Blocker (StaticBody3D with a CollisionShape3D), Glow (MeshInstance3D), Sense (Area3D), Sign (Label3D).

@export var required_mp_level := 3

@onready var blocker: CollisionShape3D = $Blocker.get_child(0)
@onready var glow: MeshInstance3D = $Glow
@onready var sign: Label3D = $Sign
var glow_mat: StandardMaterial3D
var t := 0.0


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
	glow_mat.emission_energy_multiplier = (3.0 if open else 0.8) + sin(t * (4.0 if open else 1.5)) * (1.0 if open else 0.3)
	glow_mat.albedo_color.a = 0.2 if open else 0.95          # open: a see-through shimmer; sealed: solid silver


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not is_open():
		Game.message("The Sliver is sealed. It opens at MP Lv %d (you're MP Lv %d)." % [required_mp_level, Game.mp_level])
