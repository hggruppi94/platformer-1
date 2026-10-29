extends SceneTree

# Checks that clothes fit everyone (scripts/clothes.gd): each hero body, secret ones too (with and without a hairstyle)
# and each friend who can be dressed tries on every hat and every piece, one at a time, and each piece has to touch
# them (no hats hovering over hair, no capes or jetpacks floating off a back). Then what's worn over a part hides it:
# a hat goes on instead of Dash's cap and Nina's bow, new glasses instead of Dash's and Mr. Palmer's own, a cap or
# beanie tucks a hairstyle's buns and mohawk away; headphones sit outside the head, and a hat goes on top of a
# hairstyle, not inside it.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_clothing_fit.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const FRIENDS := {
	"nina": "res://models/characters/nina.glb", "dash": "res://models/characters/bike_boy.glb",
	"rook": "res://models/characters/rook.glb", "pip": "res://models/characters/moth_kid.glb",
	"bramble": "res://models/characters/cattle_girl.glb", "green_man": "res://models/characters/green_man.glb",
	"mr_palmer": "res://models/characters/mr_palmer_alien.glb", "rex": "res://models/characters/wolf.glb",
}
const TOUCH := 0.05            # how far off them the nearest bit of a piece may be

var failures := 0
var stage: Node3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	root.get_node("Game")._resume = {}
	stage = Node3D.new()
	root.add_child(stage)
	var shop := root.get_node("Shop")
	var pieces := []                     # [slot, id] for everything that's a piece rather than a restyle
	for i in shop.items.values():
		var slot: String = "head" if i.kind == "hat" else str(i.get("slot", ""))
		if i.kind in ["hat", "clothes"]:
			var p := Clothes.hat_or_piece(slot, i.id)
			if p:
				pieces.append([slot, i.id])
				p.free()
	check(pieces.size() >= 19, "%d hats and pieces to try on" % pieces.size())

	# --- Every piece touches everyone it's on ---
	var wearers := []
	for body in Hero.BODY_ORDER + Hero.SECRET_ORDER:
		for style in [0, 4]:                              # their own hair, and space buns
			var hero := Hero.blank()
			hero.body = body
			hero.hairstyle = style
			wearers.append(["hero %s%s" % [body, " (space buns)" if style else ""], hero, ""])
	for who in FRIENDS:
		wearers.append([who, null, who])
	for w in wearers:
		var off := []
		var tried := 0
		var most := 0.0
		for p in pieces:
			if w[2] != "" and not Clothes.can_wear(w[2], p[0]):
				continue
			var m := await _dress(w, {p[0]: p[1]})
			var gap := _gap(m)
			tried += 1
			most = maxf(most, gap)
			if gap > TOUCH:
				off.append("%s %.2f m" % [p[1], gap])
			m.free()
		check(off.is_empty(), "%s: all %d pieces touch them (furthest off %.3f m)%s" % [w[0], tried, most,
			"" if off.is_empty() else ": " + ", ".join(off)])

	# --- What's worn over a part hides it ---
	var dash := await _dress(wearers.filter(func(w: Array) -> bool: return w[2] == "dash")[0],
		{"head": "propeller_cap", "face": "star_glasses"})
	check(_hidden(dash, "Cap") and _hidden(dash, "Glasses"), "a hat goes on instead of Dash's cap, new glasses instead of his shades")
	dash.free()
	var nina := await _dress(["nina", null, "nina"], {"head": "flower_crown"})
	check(_hidden(nina, "Bow"), "a hat goes on instead of Nina's bow")
	nina.free()
	var palmer := await _dress(["mr_palmer", null, "mr_palmer"], {"face": "heart_shades"})
	check(_hidden(palmer, "Glasses"), "Mr. Palmer's own glasses come off for the heart shades")
	palmer.free()
	var plain := await _dress(["mr_palmer", null, "mr_palmer"], {})
	check(not _hidden(plain, "Glasses"), "...and he has them back with nothing on his face")
	plain.free()

	# --- Hats and hairstyles ---
	var buns := Hero.blank()
	buns.hairstyle = 4
	var capped := await _dress(["", buns, ""], {"head": "sk8_beanie"})
	check(_count_hair(capped, "up") == 0 and _count_hair(capped, "crown") > 0, "a beanie tucks space buns away (the hair's still there)")
	capped.free()
	var crowned := await _dress(["", buns, ""], {"head": "flower_crown"})
	check(_count_hair(crowned, "up") == 2, "...but a flower crown leaves them out")
	crowned.free()
	for body in Hero.BODY_ORDER + Hero.SECRET_ORDER:
		var hero := Hero.blank()
		hero.body = body
		hero.hairstyle = 1
		var m := await _dress(["", hero, ""], {"head": "propeller_cap"})
		var hat := _box(m, func(n: Node) -> bool: return _under(n, "Hat"))
		var hair := _box(m, func(n: Node) -> bool: return _under(n, "Hairstyle"))
		check(hat.end.y > hair.end.y + 0.02 and hat.position.y > hair.position.y,
			"hero %s: the propeller cap sits on top of a short crop (%.2f over it)" % [body, hat.end.y - hair.end.y])
		m.free()

	# --- Headphones sit outside the head, on both sides ---
	for w in wearers:
		if str(w[0]).ends_with("(space buns)"):
			continue
		var m := await _dress(w, {"head": "headphones"})
		var fit := Clothes.fit_of(m, Clothes.UNDER.head)
		var ok := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			if str(mi.get_meta("fit", "")) == "cup":
				var at := _in_model(m, mi as Node3D).origin
				var side := signf(at.x - fit.eyes.x)
				ok = ok and side * (at.x - Clothes._head_edge(fit, at.y, side)) > 0.0
		check(ok, "%s: headphones' cups are outside their head" % w[0])
		m.free()
	_end()


func _dress(w: Array, outfit: Dictionary) -> Node3D:
	# A model of them in this outfit, standing in the scene (so the bone attachments have moved into place)
	var m: Node3D
	if w[1] != null:
		m = (load(Hero.model_path(w[1])) as PackedScene).instantiate() as Node3D
		stage.add_child(m)
		Hero.apply(m, w[1], outfit)
	else:
		m = (load(FRIENDS[w[2]]) as PackedScene).instantiate() as Node3D
		stage.add_child(m)
		Clothes.dress(m, w[2], outfit, {})
	await process_frame
	await process_frame
	return m


func _in_model(model: Node3D, n: Node3D) -> Transform3D:
	return model.global_transform.affine_inverse() * n.global_transform


func _under(n: Node, name: String) -> bool:
	while n != null:
		if str(n.name) == name:
			return true
		n = n.get_parent()
	return false


func _box(model: Node3D, keep: Callable) -> AABB:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if keep.call(mi) and (mi as MeshInstance3D).skin == null:
			var b: AABB = _in_model(model, mi) * (mi as MeshInstance3D).get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box


func _hidden(model: Node3D, part: String) -> bool:
	var body := Clothes._body(model)
	var found := Clothes._surfaces(body, [part])
	return not found.is_empty() and found.all(func(i: int) -> bool:
		var m := body.get_surface_override_material(i) as StandardMaterial3D
		return m != null and m.albedo_color.a == 0.0)


func _count_hair(model: Node3D, kind: String) -> int:
	return model.find_children("*", "MeshInstance3D", true, false).filter(func(mi: Node) -> bool:
		return str(mi.get_meta("hair", "")) == kind).size()


func _gap(model: Node3D) -> float:
	# How far the closest bit of what they're wearing (not a hairstyle) is from them (their body, any hairstyle):
	# their body's points go in a grid of 5 cm cells, then every corner of every piece looks round its cell
	var c := Clothes._cloud(model)
	var body := Clothes._body(model)
	var gone := {}
	for i in body.mesh.get_surface_count():
		var o := body.get_surface_override_material(i) as StandardMaterial3D
		if o and o.albedo_color.a == 0.0:
			gone[body.mesh.surface_get_material(i).resource_name] = true
	var grid := {}
	var pos: PackedVector3Array = c.pos
	for i in pos.size():
		if not gone.has(c.parts[c.part_of[i]]):
			_put(grid, pos[i])
	var worn := []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin != null:
			continue
		if _under(mi, "Hairstyle"):
			for p in _corners(model, mi):
				_put(grid, p)
		else:
			worn.append(mi)
	var best := INF
	for mi in worn:
		for p in _corners(model, mi):
			best = minf(best, _nearest(grid, p))
	return best


func _corners(model: Node3D, mi: MeshInstance3D) -> PackedVector3Array:
	# The points of a piece's mesh (every vertex), in their model's space
	var t := _in_model(model, mi)
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(t * v)
	return out


func _put(grid: Dictionary, p: Vector3) -> void:
	var k := Vector3i((p / 0.05).floor())
	if not grid.has(k):
		grid[k] = PackedVector3Array()
	grid[k].append(p)


func _nearest(grid: Dictionary, p: Vector3) -> float:
	var k := Vector3i((p / 0.05).floor())
	var best := INF
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var cell = grid.get(k + Vector3i(x, y, z))
				if cell != null:
					for q in (cell as PackedVector3Array):
						best = minf(best, p.distance_to(q))
	return best


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
