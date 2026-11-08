extends StaticBody3D

# One of the Thornknot's three knots in the Rootmind (scripts/rootmind.gd). A bubble from the Star Popper finds it
# through shot() (scripts/star_bubble.gd looks for that), and the world says whether it was in step with the hive
# just then ("hit": it calms) or not ("bounce").

var world: Node
var index := 0


func shot(_power: int, _at: Vector3, _dir: Vector3) -> String:
	return str(world.knot_hit(index)) if world else "bounce"
