extends StaticBody3D

# Something in a world that a Star Popper bubble can hit (scripts/star_bubble.gd looks for shot()): the world hands it
# a Callable that says what happens, "hit" or "bounce". The Frozen Moment's ice shells use it (scripts/frozen_moment.gd).

var on_shot: Callable


func shot(_power: int, _at: Vector3, _dir: Vector3) -> String:
	return str(on_shot.call()) if on_shot.is_valid() else "bounce"
