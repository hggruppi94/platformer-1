extends Area3D

# A happy place: a safe, calm spot from the show. Walking into one fills HP and MP and saves the game. The first visit
# counts it as found (stored in Game.items as "happy_place:<id>") and says how many of them she has found.

@export var place_id := ""
@export var place_name := ""
@export var total := 6

const REST_COOLDOWN := 8.0

var _cooldown := 0.0
var _t := 0.0
@onready var _glow: Node3D = get_node_or_null("Glow")


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_t += delta
	if _glow:
		_glow.position.y = 1.4 + sin(_t * 1.6) * 0.15
		_glow.rotation.y = _t * 0.6


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or _cooldown > 0.0:
		return
	_cooldown = REST_COOLDOWN
	Game.hp = Game.max_hp
	Game.mp = Game.max_mp
	Game.stats_changed.emit()
	var key := "happy_place:" + place_id
	if not Game.has_item(key):
		Game.items.append(key)
		var found := Game.items.filter(func(i: String) -> bool: return i.begins_with("happy_place:")).size()
		Game.message("Happy place found: %s (%d/%d). Breathe in... and out. You feel calm. +%d sparkles" % [place_name,
			found, total, Game.HAPPY_PLACE_SPARKLES])
		Game.add_sparkles(Game.HAPPY_PLACE_SPARKLES)
		Audio.play("pickup")
	else:
		Game.message("You rest at the %s. You feel calm." % place_name)
	Game.save_game()
