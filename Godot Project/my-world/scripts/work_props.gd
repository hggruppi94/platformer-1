extends RefCounted

# The things people use at their jobs (scripts/work_job.gd): what stands at a workplace (a library ladder, a book cart,
# a baker's kneading table, café tables, a sawhorse, flower boxes...) and what they hold in their hands while they work
# (a book, a pie, a broom, a watering can, a crate...). All made from simple shapes here, like the townsfolk's extras
# (scripts/townsfolk.gd), so nothing needs a builder run or a new model.
#
# Scene props are made in their workplace's frame: local +Z is the side a worker faces them from, unless said.
# Held things come in two kinds: one-handed (in the right hand, carried by its bone) and two-handed (held in front of
# the chest, carried by the body: a tray, a crate), which also says which pose to walk with (hold_pose()).

const SOLID_LAYER := 1

static var _mats := {}


static func mat(c: Color, rough := 0.7, glow := 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [c.to_html(), rough, glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func _mesh(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO, rough := 0.7, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c, rough, glow)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _cyl(top: float, bottom: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _ball(r: float, seg := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


static func _solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	# Something you bump into, like the builders' furniture
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = SOLID_LAYER
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
	parent.add_child(body)


static func _label(parent: Node3D, text: String, pos: Vector3, size := 28, c := Color(1, 1, 1)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = c
	l.outline_size = 0
	l.position = pos
	parent.add_child(l)
	return l


const WOOD := Color(0.5, 0.33, 0.2)
const DARK_WOOD := Color(0.36, 0.23, 0.14)
const BOOKS := [Color(0.6, 0.15, 0.15), Color(0.15, 0.3, 0.5), Color(0.2, 0.42, 0.25), Color(0.75, 0.6, 0.25), Color(0.45, 0.2, 0.45)]
const PIE_CRUST := Color(0.85, 0.6, 0.3)
const DOUGH := Color(0.96, 0.9, 0.75)


# -----------------------------------------------------------------------------
# What stands at a workplace
# -----------------------------------------------------------------------------
static func kinds() -> Array:
	return ["ladder", "book_cart", "kneading_table", "cafe_table", "chalkboard", "crates", "sawhorse", "bucket",
		"window_box", "produce_stand", "grandfather_clock", "lamp_table", "flower_bed", "can_rest", "tidy_shelf"]


static func make(kind: String, data := {}) -> Node3D:
	var g := Node3D.new()
	g.name = "Work " + kind.capitalize()
	match kind:
		"ladder":                      # a library ladder leaning on the shelf behind it (local -Z), rails, rungs, wheels
			var h := float(data.get("height", 2.8))
			var lean := 0.32
			var tilt := atan2(lean, h)
			for sx in [-0.24, 0.24]:
				_mesh(g, _box(Vector3(0.06, h + 0.1, 0.06)), DARK_WOOD, Vector3(sx, h / 2.0, -lean / 2.0), Vector3(-tilt, 0, 0))
				_mesh(g, _cyl(0.05, 0.05, 0.05, 10), Color(0.75, 0.6, 0.3), Vector3(sx, h + 0.02, -lean - 0.02), Vector3(0, 0, PI / 2), 0.3)
				_mesh(g, _cyl(0.05, 0.05, 0.04, 10), Color(0.2, 0.2, 0.22), Vector3(sx, 0.05, 0.0), Vector3(0, 0, PI / 2), 0.5)
			var rungs := int(h / 0.3)
			for k in rungs:
				var y := 0.3 + k * 0.3
				_mesh(g, _box(Vector3(0.48, 0.04, 0.07)), WOOD, Vector3(0, y, -lean * y / h))
		"book_cart":                   # a wooden cart of books to put back, two shelves on little wheels
			_mesh(g, _box(Vector3(1.0, 0.05, 0.5)), WOOD, Vector3(0, 0.3, 0))
			_mesh(g, _box(Vector3(1.0, 0.05, 0.5)), WOOD, Vector3(0, 0.72, 0))
			for sx in [-0.48, 0.48]:
				_mesh(g, _box(Vector3(0.05, 0.75, 0.5)), WOOD, Vector3(sx, 0.48, 0))
				for sz in [-0.2, 0.2]:
					_mesh(g, _cyl(0.06, 0.06, 0.04, 10), Color(0.15, 0.15, 0.17), Vector3(sx, 0.07, sz), Vector3(0, 0, PI / 2))
			for row in [0.33, 0.75]:
				var x := -0.42
				var k := 0
				while x < 0.4:
					var w := 0.07 + 0.03 * ((k * 7) % 3)
					var bh := 0.22 + 0.04 * ((k * 5) % 3)
					_mesh(g, _box(Vector3(w, bh, 0.34)), BOOKS[k % BOOKS.size()], Vector3(x + w / 2.0, row + 0.03 + bh / 2.0, 0))
					x += w + 0.015
					k += 1
			_solid(g, Vector3(1.0, 0.95, 0.5), Vector3(0, 0.48, 0))
		"kneading_table":              # a floury table with a ball of dough, a rolling pin, a bowl and a sack of flour
			var top := 0.9
			var size := Vector2(float(data.get("w", 1.4)), float(data.get("d", 0.8)))
			_mesh(g, _box(Vector3(size.x, 0.06, size.y)), Color(0.9, 0.82, 0.68), Vector3(0, top, 0))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_mesh(g, _box(Vector3(0.07, top, 0.07)), WOOD, Vector3(sx * (size.x / 2 - 0.08), top / 2.0, sz * (size.y / 2 - 0.08)))
			_mesh(g, _box(Vector3(size.x * 0.7, 0.01, size.y * 0.6)), Color(0.98, 0.97, 0.94), Vector3(0, top + 0.035, 0))   # flour dust
			var dough := _mesh(g, _ball(0.16, 12), DOUGH, Vector3(0, top + 0.1, 0.05))
			dough.scale = Vector3(1.3, 0.55, 1.1)
			dough.name = "Dough"
			_mesh(g, _cyl(0.04, 0.04, 0.5, 10), Color(0.8, 0.62, 0.4), Vector3(-0.42, top + 0.07, 0.1), Vector3(0, 0, PI / 2))
			_mesh(g, _cyl(0.17, 0.11, 0.14, 14), Color(0.55, 0.75, 0.85), Vector3(0.45, top + 0.1, -0.1), Vector3.ZERO, 0.3)
			var sack := _mesh(g, _cyl(0.2, 0.24, 0.55, 10), Color(0.92, 0.88, 0.8), Vector3(size.x / 2 + 0.3, 0.28, -0.1), Vector3.ZERO, 0.95)
			sack.name = "Flour Sack"
			_label(g, "FLOUR", Vector3(size.x / 2 + 0.3, 0.32, 0.12), 22, Color(0.35, 0.3, 0.25))
			_solid(g, Vector3(size.x, top, size.y), Vector3(0, top / 2.0, 0))
		"cafe_table":                  # a little round table outside, two chairs, a cup and a sugar pot
			_mesh(g, _cyl(0.42, 0.42, 0.04, 18), Color(0.95, 0.95, 0.92), Vector3(0, 0.74, 0), Vector3.ZERO, 0.4)
			_mesh(g, _cyl(0.04, 0.05, 0.72, 8), Color(0.15, 0.15, 0.17), Vector3(0, 0.37, 0), Vector3.ZERO, 0.4)
			_mesh(g, _cyl(0.22, 0.25, 0.03, 14), Color(0.15, 0.15, 0.17), Vector3(0, 0.015, 0), Vector3.ZERO, 0.4)
			_mesh(g, _cyl(0.05, 0.04, 0.09, 10), Color(0.95, 0.4, 0.35), Vector3(0.12, 0.8, 0.05), Vector3.ZERO, 0.4)
			_mesh(g, _cyl(0.04, 0.04, 0.07, 10), Color(0.95, 0.95, 0.95), Vector3(-0.15, 0.8, -0.08), Vector3.ZERO, 0.3)
			for sx in [-1.0, 1.0]:
				var ch := Node3D.new()
				ch.position = Vector3(sx * 0.7, 0, 0)
				ch.rotation.y = sx * -PI / 2
				g.add_child(ch)
				_mesh(ch, _box(Vector3(0.4, 0.04, 0.4)), Color(0.2, 0.45, 0.35), Vector3(0, 0.45, 0))
				_mesh(ch, _box(Vector3(0.4, 0.4, 0.04)), Color(0.2, 0.45, 0.35), Vector3(0, 0.67, -0.18))
				for lx in [-0.16, 0.16]:
					for lz in [-0.16, 0.16]:
						_mesh(ch, _box(Vector3(0.03, 0.45, 0.03)), Color(0.15, 0.15, 0.17), Vector3(lx, 0.22, lz))
			_solid(g, Vector3(0.8, 0.76, 0.8), Vector3(0, 0.38, 0))
		"chalkboard":                  # an A-frame menu board on the sidewalk, today's specials in chalk
			for sz in [-1.0, 1.0]:
				_mesh(g, _box(Vector3(0.7, 0.95, 0.04)), DARK_WOOD, Vector3(0, 0.5, sz * 0.12), Vector3(sz * -0.2, 0, 0))
				_mesh(g, _box(Vector3(0.6, 0.8, 0.01)), Color(0.12, 0.16, 0.14), Vector3(0, 0.52, sz * 0.145), Vector3(sz * -0.2, 0, 0), 0.95)
			var words := _label(g, str(data.get("text", "TODAY\nPie & Cocoa")), Vector3(0, 0.56, 0.17), 30, Color(0.97, 0.97, 0.92))
			words.rotation.x = -0.2
		"crates":                      # a stack of wooden crates (a delivery), apples on the top one
			for k in 3:
				var p := Vector3([0.0, 0.62, 0.3][k], 0.2 + [0.0, 0.0, 0.4][k], [0.0, 0.05, 0.0][k])
				_mesh(g, _box(Vector3(0.58, 0.4, 0.45)), Color(0.72, 0.56, 0.36), p)
				for sx in [-0.3, 0.3]:
					_mesh(g, _box(Vector3(0.03, 0.4, 0.47)), Color(0.55, 0.4, 0.25), p + Vector3(sx * 0.96, 0, 0))
			for k in 5:
				_mesh(g, _ball(0.07, 8), Color(0.85, 0.15, 0.15), Vector3(0.18 + k * 0.1, 0.83, (k % 2) * 0.1 - 0.05))
			_solid(g, Vector3(1.2, 0.8, 0.5), Vector3(0.3, 0.4, 0))
		"sawhorse":                    # two A-frame legs, a plank across them and sawdust underneath
			for sx in [-0.5, 0.5]:
				for sz in [-1.0, 1.0]:
					_mesh(g, _box(Vector3(0.06, 0.75, 0.06)), Color(0.75, 0.6, 0.4), Vector3(sx, 0.36, sz * 0.12), Vector3(sz * 0.3, 0, 0))
			_mesh(g, _box(Vector3(1.3, 0.06, 0.1)), Color(0.75, 0.6, 0.4), Vector3(0, 0.72, 0))
			_mesh(g, _box(Vector3(1.6, 0.04, 0.24)), Color(0.88, 0.75, 0.55), Vector3(0.1, 0.77, 0))
			_mesh(g, _cyl(0.45, 0.5, 0.01, 16), Color(0.93, 0.83, 0.62), Vector3(0, 0.01, 0), Vector3.ZERO, 1.0)
			_solid(g, Vector3(1.6, 0.8, 0.4), Vector3(0, 0.4, 0))
		"bucket":                      # a bucket of suds and a hose coiled beside it
			_mesh(g, _cyl(0.2, 0.16, 0.32, 14), Color(0.6, 0.62, 0.66), Vector3(0, 0.16, 0), Vector3.ZERO, 0.3)
			_mesh(g, _cyl(0.18, 0.18, 0.02, 14), Color(0.97, 0.97, 1.0), Vector3(0, 0.3, 0), Vector3.ZERO, 0.2)
			for k in 4:
				_mesh(g, _ball(0.06, 6), Color(1, 1, 1), Vector3(0.08 * cos(k * 1.7), 0.33, 0.08 * sin(k * 1.7)), Vector3.ZERO, 0.2)
			var hose := TorusMesh.new()
			hose.inner_radius = 0.22
			hose.outer_radius = 0.28
			for k in 3:
				_mesh(g, hose, Color(0.2, 0.55, 0.3), Vector3(0.55, 0.03 + k * 0.05, 0), Vector3.ZERO, 0.6)
		"window_box":                  # a planter box under a window, full of flowers (put at the wall, y up its height)
			_mesh(g, _box(Vector3(1.5, 0.25, 0.3)), Color(0.4, 0.55, 0.38), Vector3(0, 0, 0))
			_mesh(g, _box(Vector3(1.4, 0.04, 0.24)), Color(0.36, 0.24, 0.16), Vector3(0, 0.12, 0), Vector3.ZERO, 1.0)
			var cols := [Color(0.95, 0.4, 0.5), Color(0.98, 0.85, 0.3), Color(0.7, 0.45, 0.85), Color(0.98, 0.98, 0.95)]
			for k in 9:
				var x := -0.6 + k * 0.15
				_mesh(g, _cyl(0.012, 0.012, 0.2, 5), Color(0.3, 0.55, 0.25), Vector3(x, 0.22, 0.02 * (k % 2)))
				_mesh(g, _ball(0.07, 8), cols[k % cols.size()], Vector3(x, 0.33, 0.02 * (k % 2)), Vector3.ZERO, 0.6)
		"produce_stand":               # a slanted stand of fruit and veg crates outside the market, with a price sign
			_mesh(g, _box(Vector3(1.6, 0.06, 0.8)), WOOD, Vector3(0, 0.75, 0), Vector3(0.3, 0, 0))
			for sx in [-0.75, 0.75]:
				_mesh(g, _box(Vector3(0.06, 0.95, 0.06)), WOOD, Vector3(sx, 0.48, -0.3))
				_mesh(g, _box(Vector3(0.06, 0.6, 0.06)), WOOD, Vector3(sx, 0.3, 0.3))
			var fruit := [Color(0.85, 0.15, 0.15), Color(0.98, 0.6, 0.15), Color(0.45, 0.75, 0.25), Color(0.6, 0.25, 0.55)]
			for k in 4:
				var x := -0.6 + k * 0.4
				_mesh(g, _box(Vector3(0.36, 0.12, 0.7)), Color(0.72, 0.56, 0.36), Vector3(x, 0.84, 0), Vector3(0.3, 0, 0))
				for q in 6:
					_mesh(g, _ball(0.06, 6), fruit[k], Vector3(x - 0.1 + (q % 2) * 0.2, 0.93 - (q / 2) * 0.07, -0.22 + (q / 2) * 0.22),
						Vector3.ZERO, 0.6)
			_label(g, str(data.get("text", "FRESH TODAY")), Vector3(0, 1.25, -0.1), 26, Color(0.2, 0.15, 0.1)).modulate = Color(0.25, 0.18, 0.1)
			_mesh(g, _box(Vector3(0.8, 0.22, 0.03)), Color(0.98, 0.95, 0.85), Vector3(0, 1.25, -0.12))
			_solid(g, Vector3(1.6, 0.9, 0.8), Vector3(0, 0.45, 0))
		"grandfather_clock":           # a tall old clock out on the antique shop's sidewalk display
			_mesh(g, _box(Vector3(0.55, 1.9, 0.38)), Color(0.4, 0.22, 0.12), Vector3(0, 0.95, 0), Vector3.ZERO, 0.45)
			_mesh(g, _box(Vector3(0.62, 0.12, 0.44)), Color(0.32, 0.17, 0.1), Vector3(0, 1.95, 0), Vector3.ZERO, 0.45)
			_mesh(g, _cyl(0.2, 0.2, 0.03, 18), Color(0.96, 0.92, 0.8), Vector3(0, 1.6, 0.2), Vector3(PI / 2, 0, 0), 0.4)
			_mesh(g, _box(Vector3(0.02, 0.14, 0.01)), Color(0.1, 0.1, 0.1), Vector3(0, 1.64, 0.22))
			_mesh(g, _box(Vector3(0.1, 0.02, 0.01)), Color(0.1, 0.1, 0.1), Vector3(0.04, 1.6, 0.22))
			_mesh(g, _box(Vector3(0.3, 0.8, 0.02)), Color(0.75, 0.85, 0.9), Vector3(0, 0.95, 0.195), Vector3.ZERO, 0.1)
			_mesh(g, _cyl(0.08, 0.08, 0.02, 12), Color(0.85, 0.65, 0.25), Vector3(0, 0.75, 0.18), Vector3(PI / 2, 0, 0), 0.25)
			_solid(g, Vector3(0.6, 2.0, 0.4), Vector3(0, 1.0, 0))
		"lamp_table":                  # a little table with an old brass lamp, and a rocking chair beside it
			_mesh(g, _cyl(0.3, 0.3, 0.04, 14), DARK_WOOD, Vector3(0, 0.66, 0))
			_mesh(g, _cyl(0.04, 0.05, 0.64, 8), DARK_WOOD, Vector3(0, 0.33, 0))
			_mesh(g, _cyl(0.07, 0.1, 0.3, 10), Color(0.85, 0.65, 0.25), Vector3(0, 0.83, 0), Vector3.ZERO, 0.25)
			_mesh(g, _cyl(0.1, 0.2, 0.2, 12), Color(0.95, 0.85, 0.65), Vector3(0, 1.05, 0), Vector3.ZERO, 0.6, 0.4)
			var rock := Node3D.new()
			rock.position = Vector3(0.75, 0, -0.1)
			rock.rotation.y = -0.4
			g.add_child(rock)
			_mesh(rock, _box(Vector3(0.48, 0.05, 0.45)), DARK_WOOD, Vector3(0, 0.45, 0))
			_mesh(rock, _box(Vector3(0.48, 0.65, 0.05)), DARK_WOOD, Vector3(0, 0.8, -0.22), Vector3(-0.15, 0, 0))
			for sx in [-0.22, 0.22]:
				_mesh(rock, _box(Vector3(0.04, 0.05, 0.75)), DARK_WOOD, Vector3(sx, 0.04, 0), Vector3.ZERO)
				_mesh(rock, _box(Vector3(0.04, 0.42, 0.04)), DARK_WOOD, Vector3(sx, 0.24, 0.15))
				_mesh(rock, _box(Vector3(0.04, 0.42, 0.04)), DARK_WOOD, Vector3(sx, 0.24, -0.15))
			_solid(g, Vector3(0.6, 0.7, 0.6), Vector3(0, 0.35, 0))
		"flower_bed":                  # a round bed of Void flowers (glowing caps on curly stems) with seedlings coming up
			var r := float(data.get("radius", 1.0))
			_mesh(g, _cyl(r, r + 0.08, 0.12, 20), Color(0.3, 0.2, 0.25), Vector3(0, 0.04, 0), Vector3.ZERO, 1.0)
			var cols := [Color(1.0, 0.45, 0.8), Color(0.55, 0.95, 1.0), Color(0.75, 0.55, 1.0), Color(1.0, 0.9, 0.35)]
			var n := int(r * 10.0)
			for k in n:
				var a := k * TAU / n + 0.3 * (k % 2)
				var rr := r * (0.35 + 0.5 * float((k * 7) % 5) / 4.0)
				var p := Vector3(cos(a) * rr, 0, sin(a) * rr)
				if k % 3 == 2:
					_mesh(g, _ball(0.05, 6), Color(0.45, 0.95, 0.4), p + Vector3(0, 0.14, 0), Vector3.ZERO, 0.6)     # a seedling
					continue
				_mesh(g, _cyl(0.015, 0.02, 0.4, 5), Color(0.35, 0.85, 0.5), p + Vector3(0, 0.3, 0), Vector3(0.15 * sin(a), 0, 0.15 * cos(a)))
				_mesh(g, _ball(0.1, 8), cols[k % cols.size()], p + Vector3(0, 0.52, 0), Vector3.ZERO, 0.5, 0.6)
		"can_rest":                    # where the watering can and a trowel wait between jobs
			_mesh(g, _cyl(0.32, 0.36, 0.06, 12), Color(0.35, 0.25, 0.3), Vector3(0, 0.03, 0), Vector3.ZERO, 1.0)
			var can := hand("can")
			can.position = Vector3(-0.08, 0.22, 0)
			g.add_child(can)
			can.name = "Can"
			_mesh(g, _box(Vector3(0.05, 0.03, 0.3)), Color(0.75, 0.55, 1.0), Vector3(0.15, 0.08, 0.05), Vector3(0, 0.4, 0), 0.4)
		"tidy_shelf":                  # (nothing to add: a spot on an existing shelf, for the test to know it's a shelf)
			pass
	return g


# -----------------------------------------------------------------------------
# What they hold
# -----------------------------------------------------------------------------
static func two_handed(kind: String) -> bool:
	return kind in ["crate", "tray", "basket", "pie_tray"]


static func hold_pose(kind: String) -> String:
	# The pose to walk about with while carrying it: two hands for big things, nothing special for small ones
	match kind:
		"crate", "basket":
			return "carry_low"
		"tray", "pie_tray":
			return "carry"
	return ""


static func hand(kind: String) -> Node3D:
	# Made with its grip at the origin; a one-handed thing hangs down from a hand hanging at the side (it turns with
	# the hand as the arm moves), a two-handed one sits level in front of the chest
	var g := Node3D.new()
	g.name = "Holding " + kind
	match kind:
		"book":
			_mesh(g, _box(Vector3(0.04, 0.22, 0.16)), BOOKS[randi() % BOOKS.size()], Vector3(0, -0.07, 0.02))
			_mesh(g, _box(Vector3(0.035, 0.2, 0.145)), Color(0.97, 0.94, 0.85), Vector3(0.006, -0.07, 0.025))
		"stamp":
			_mesh(g, _cyl(0.025, 0.025, 0.08, 8), DARK_WOOD, Vector3(0, -0.03, 0))
			_mesh(g, _box(Vector3(0.07, 0.03, 0.05)), Color(0.75, 0.15, 0.15), Vector3(0, -0.085, 0))
		"broom":
			_mesh(g, _cyl(0.018, 0.018, 1.25, 6), Color(0.75, 0.6, 0.4), Vector3(0, -0.45, 0.05))
			_mesh(g, _cyl(0.04, 0.14, 0.3, 8), Color(0.9, 0.78, 0.45), Vector3(0, -1.12, 0.05), Vector3.ZERO, 1.0)
		"can":
			_mesh(g, _cyl(0.09, 0.1, 0.2, 12), Color(0.75, 0.55, 1.0), Vector3(0, -0.12, 0.04), Vector3.ZERO, 0.35)
			_mesh(g, _cyl(0.015, 0.025, 0.24, 6), Color(0.75, 0.55, 1.0), Vector3(0, -0.06, 0.2), Vector3(-1.0, 0, 0), 0.35)
			_mesh(g, _cyl(0.035, 0.02, 0.04, 8), Color(0.85, 0.7, 1.0), Vector3(0, 0.03, 0.3), Vector3(-1.0, 0, 0), 0.35)
			var handle := TorusMesh.new()
			handle.inner_radius = 0.05
			handle.outer_radius = 0.07
			_mesh(g, handle, Color(0.6, 0.4, 0.9), Vector3(0, 0.0, -0.02), Vector3(0, 0, PI / 2), 0.35)
		"duster":
			_mesh(g, _cyl(0.015, 0.015, 0.35, 6), DARK_WOOD, Vector3(0, -0.05, 0.12), Vector3(-1.2, 0, 0))
			for k in 6:
				_mesh(g, _ball(0.06, 6), [Color(0.95, 0.45, 0.6), Color(0.6, 0.45, 0.85), Color(0.98, 0.9, 0.5)][k % 3],
					Vector3(0.04 * cos(k), 0.02 + 0.04 * sin(k), 0.32), Vector3.ZERO, 1.0)
		"sponge", "cloth":
			var c := Color(1.0, 0.85, 0.3) if kind == "sponge" else Color(0.95, 0.95, 0.98)
			_mesh(g, _box(Vector3(0.12, 0.06, 0.09)), c, Vector3(0, -0.06, 0.03), Vector3.ZERO, 1.0)
		"saw":
			_mesh(g, _box(Vector3(0.04, 0.1, 0.1)), Color(0.75, 0.25, 0.2), Vector3(0, -0.05, 0))
			_mesh(g, _box(Vector3(0.01, 0.1, 0.42)), Color(0.75, 0.77, 0.8), Vector3(0, -0.08, 0.26), Vector3.ZERO, 0.25)
		"hammer":
			_mesh(g, _cyl(0.018, 0.018, 0.3, 6), Color(0.75, 0.6, 0.4), Vector3(0, -0.1, 0.06), Vector3(-0.6, 0, 0))
			_mesh(g, _box(Vector3(0.05, 0.05, 0.14)), Color(0.35, 0.36, 0.4), Vector3(0, -0.22, 0.14), Vector3(-0.6, 0, 0), 0.3)
		"toy":
			_mesh(g, _box(Vector3(0.12, 0.12, 0.12)), [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 0.95), Color(0.98, 0.85, 0.25)][randi() % 3],
				Vector3(0, -0.07, 0.04), Vector3.ZERO, 0.5)
		"chalk":
			_mesh(g, _cyl(0.01, 0.01, 0.07, 6), Color(0.98, 0.98, 0.95), Vector3(0, -0.04, 0.03), Vector3(-1.0, 0, 0), 1.0)
		"papers":
			_mesh(g, _box(Vector3(0.02, 0.3, 0.22)), Color(0.55, 0.38, 0.22), Vector3(0, -0.1, 0.06))
			_mesh(g, _box(Vector3(0.022, 0.26, 0.2)), Color(0.98, 0.98, 0.95), Vector3(0.004, -0.1, 0.06))
		"flowers":                     # a bouquet of Void flowers
			for k in 5:
				var a := k * TAU / 5.0
				_mesh(g, _cyl(0.01, 0.01, 0.28, 5), Color(0.35, 0.85, 0.5), Vector3(0.02 * cos(a), -0.02, 0.12 + 0.02 * sin(a)), Vector3(-1.1, 0, 0))
				_mesh(g, _ball(0.05, 8), [Color(1.0, 0.45, 0.8), Color(0.55, 0.95, 1.0), Color(1.0, 0.9, 0.35)][k % 3],
					Vector3(0.05 * cos(a), 0.06 + 0.04 * sin(a), 0.26), Vector3.ZERO, 0.5, 0.5)
		"seedling":
			_mesh(g, _cyl(0.05, 0.04, 0.07, 8), Color(0.55, 0.3, 0.2), Vector3(0, -0.06, 0.03))
			_mesh(g, _ball(0.05, 6), Color(0.45, 0.95, 0.4), Vector3(0, 0.0, 0.03), Vector3.ZERO, 0.6)
		"crate":
			_mesh(g, _box(Vector3(0.5, 0.32, 0.38)), Color(0.72, 0.56, 0.36), Vector3.ZERO)
			for k in 4:
				_mesh(g, _ball(0.06, 6), Color(0.85, 0.15, 0.15) if k % 2 == 0 else Color(0.98, 0.6, 0.15),
					Vector3(-0.15 + k * 0.1, 0.17, 0.0))
		"basket":
			_mesh(g, _cyl(0.2, 0.15, 0.2, 12), Color(0.75, 0.58, 0.32), Vector3.ZERO, Vector3.ZERO, 1.0)
			for k in 5:
				_mesh(g, _ball(0.06, 6), Color(0.85, 0.15, 0.15), Vector3(0.1 * cos(k * 1.3), 0.11, 0.1 * sin(k * 1.3)))
		"tray":                        # a tray with two cups of cocoa and a slice of pie
			_mesh(g, _cyl(0.24, 0.24, 0.02, 16), Color(0.75, 0.75, 0.78), Vector3.ZERO, Vector3.ZERO, 0.3)
			_mesh(g, _cyl(0.04, 0.035, 0.08, 10), Color(0.98, 0.98, 0.98), Vector3(-0.09, 0.05, 0.03), Vector3.ZERO, 0.3)
			_mesh(g, _cyl(0.04, 0.035, 0.08, 10), Color(0.98, 0.98, 0.98), Vector3(0.0, 0.05, -0.1), Vector3.ZERO, 0.3)
			_mesh(g, _box(Vector3(0.14, 0.05, 0.1)), PIE_CRUST, Vector3(0.1, 0.035, 0.05))
		"pie_tray":                    # a pie in its dish (raw dough or baked: the job says which by "raw")
			_mesh(g, _cyl(0.2, 0.17, 0.06, 16), Color(0.6, 0.62, 0.66), Vector3.ZERO, Vector3.ZERO, 0.3)
			_mesh(g, _cyl(0.18, 0.18, 0.04, 16), PIE_CRUST, Vector3(0, 0.03, 0)).name = "Pie"
	return g
