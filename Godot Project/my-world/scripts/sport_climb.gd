extends SportGame

# Rock Wall Race (scripts/sports.gd), at the Void's Rock Wall with Peak: from the crash mat, jump up the coloured
# ledges to the top and ring the golden bell, as fast as you can. A little glowing star floats over each ledge to show
# the way up. A lower time is better; past TOO_LONG seconds (or wandering right off) the race is off with no harm done.
# Wall crawl (the centipede's move) works here too: that's allowed, it's quick.

const TOO_LONG := 90.0
const WANDER := 26.0                         # this far from the wall and the race is off
const BELL := Vector3(2.6, 9.9, 0.0)         # on the wall's flat top (tools/build_town.gd _rock_wall(): top at 9.9)
const RING_R := 1.7                          # this close to the bell rings it
# The ledges zig-zag up the face (the same sums as _rock_wall())
const LEDGES := [Vector3(-3.0, 1.1, 1.25), Vector3(0.0, 2.4, 1.25), Vector3(-1.5, 3.7, 1.25), Vector3(1.5, 5.0, 1.25),
	Vector3(-3.0, 6.3, 1.25), Vector3(0.0, 7.6, 1.25), Vector3(-1.5, 8.9, 1.25)]

var clock := 0.0
var rung := false
var bell: Node3D
var stars: Array[Node3D] = []


func setup() -> void:
	if Game.riding:
		Game.riding = false
		Game.equipment_changed.emit()
	place_hero(Vector3(0.0, 0.6, 3.4), Vector3(0, 0, 0))
	send_host(to_global(Vector3(-6.4, 0.2, 4.6)), to_global(Vector3(0, 0, 3.0)))
	# The bell on a little gold frame on top
	bell = Node3D.new()
	bell.name = "Race Bell"
	add_child(bell)
	bell.position = BELL
	var gold := mat(Color(1.0, 0.8, 0.3), 0.5, 0.8)
	for s in [-1.0, 1.0]:
		var post := CylinderMesh.new()
		post.top_radius = 0.04
		post.bottom_radius = 0.05
		post.height = 1.6
		mesh_on(bell, post, Vector3(s * 0.45, 0.8, 0), gold)
	var bar := CylinderMesh.new()
	bar.top_radius = 0.035
	bar.bottom_radius = 0.035
	bar.height = 1.0
	mesh_on(bell, bar, Vector3(0, 1.6, 0), gold).rotation.z = PI / 2.0
	var cup := CylinderMesh.new()
	cup.top_radius = 0.12
	cup.bottom_radius = 0.3
	cup.height = 0.45
	var swing := Node3D.new()
	swing.name = "Swing"
	swing.position = Vector3(0, 1.58, 0)
	bell.add_child(swing)
	mesh_on(swing, cup, Vector3(0, -0.25, 0), gold)
	var glow := ring(Color(1.0, 0.85, 0.3), 1.0)
	glow.position = BELL + Vector3(0, 0.05, 0)
	for k in LEDGES.size():                                  # the way up
		var st := Node3D.new()
		st.name = "Way Star %d" % k
		add_child(st)
		st.position = LEDGES[k] + Vector3(0, 0.75, 0.1)
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		mesh_on(st, sm, Vector3.ZERO, mat(Color(1.0, 0.95, 0.6), 1.6))
		stars.append(st)


func go() -> void:
	sports.show_meter(false)
	sports.shout("Climb!", Color(0.7, 0.5, 1.0), 0.6)


func tick(delta: float) -> void:
	super.tick(delta)
	if rung:
		return
	clock += delta
	for k in stars.size():
		stars[k].position.y = LEDGES[k].y + 0.75 + sin(time * 3.0 + k) * 0.08
		stars[k].visible = p.global_position.y < to_global(LEDGES[k]).y + 0.3       # gone once you're past it
	if p.global_position.distance_to(bell.global_position + Vector3(0, 0.6, 0)) <= RING_R:
		ring_bell()
	elif clock >= TOO_LONG:
		sports.over(-1.0, "TIME'S UP!")
	elif Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length() > WANDER:
		sports.over(-1.0, "Race off!")


func ring_bell() -> void:
	rung = true
	var t := snappedf(clock, 0.1)
	var swing := bell.get_node("Swing") as Node3D
	var tw := create_tween()
	for k in 4:
		tw.tween_property(swing, "rotation:z", 0.5 if k % 2 == 0 else -0.5, 0.12)
	tw.tween_property(swing, "rotation:z", 0.0, 0.12)
	Juice.blip("clink", 0.6, 0.0)
	Juice.blip("chime", 0.8)
	Juice.burst(self, bell.global_position + Vector3(0, 1.4, 0), Color(1.0, 0.85, 0.3), 20, 0.1, 3.0, 0.8)
	sports.over(t, "DING!")


func status() -> Array:
	return ["%.1f s" % clock, "Ring the bell!"]
