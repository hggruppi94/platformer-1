extends StaticBody3D

# A Glitch Crystal shielding the Agent of Chaos's clock (scripts/chaos_trials.gd, Dash's section). It's in the
# "enemies" group so gadgets and hip fire find it; Star Popper bubbles bounce off, any other gadget shatters it
# (a crystal the Plushinator turned into a toy pops at any touch, like every plushie).

var trials: Node
var defeated := false
var size := 1.0


func shot(_power: int, _point: Vector3, _dir: Vector3) -> String:
	if trials == null:
		return "miss"
	return str(trials.call("crystal_shot", self))



var plushed := false                                  # the Plushinator got it: the next touch pops it


func _process(_delta: float) -> void:
	if not plushed and Arsenal.is_plush(self):
		plushed = true
