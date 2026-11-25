extends SceneTree

# Checks the enemies' baked look (25 Nov 2026, tools/build_prop_surfaces.py reptile_scales|goblin_skin|tweed and
# scripts/detail_props.gd dress_crocodillo, dress_goblin_skin, dress_bog_wailer, dress_peeper): a Crocodillo's hide,
# belly and hands wear the reptile scales and its shell the beetle-shell skin; a Time Goblin's (and Tock's) teal skin
# the pebbly goblin skin and its clothes the woven cloth; a Bog Wailer's head the toad warts, its moss the fuzz and its
# body the goblin skin; a Peeper's fluff the moth fuzz. Two of a kind share their patched materials (so they still
# draw together), dressing again changes nothing, the cousins that strip the look (the Stormram, the Dawn Snatcher)
# are left alone, and with detail off nothing changes.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_enemy_detail.gd
#
# Only makes the enemies in an empty scene: no save or setting is touched.

const DP := preload("res://scripts/detail_props.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _drawn(mi: Node) -> bool:
	return mi is GeometryInstance3D and (mi as GeometryInstance3D).visible and (mi as VisualInstance3D).layers != 0


func _patch(m: Node) -> String:
	var mat := (m as MeshInstance3D).material_override
	return str(mat.get_meta(DP.SURFACE_META, "")) if mat else ""


func _has_maps(m: Node) -> bool:
	var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
	return mat != null and mat.albedo_texture != null and mat.normal_texture != null and mat.uv1_triplanar


func _make(what: String) -> Node3D:
	var n: Node3D
	match what:
		"croc":
			n = (load("res://scenes/enemies/crocodillo.tscn") as PackedScene).instantiate()
		"pebble":
			n = (load("res://scenes/enemies/crocodillo.tscn") as PackedScene).instantiate()
			n.set("size", 0.6)
		"boulder":
			n = (load("res://scenes/enemies/crocodillo.tscn") as PackedScene).instantiate()
			n.set_script(load("res://scripts/crocodillo_boss.gd"))
			n.set("size", 2.6)
		"stormram":
			n = (load("res://scenes/enemies/crocodillo.tscn") as PackedScene).instantiate()
			n.set_script(load("res://scripts/stormram.gd"))
			n.set("size", 2.2)
		"goblin":
			n = (load("res://scenes/enemies/time_goblin.tscn") as PackedScene).instantiate()
		"tock":
			n = (load("res://scenes/enemies/time_goblin_boss.tscn") as PackedScene).instantiate()
		"snatcher":
			n = (load("res://scenes/enemies/time_goblin_boss.tscn") as PackedScene).instantiate()
			n.set_script(load("res://scripts/dawn_snatcher.gd"))
			n.set("size", 2.4)
		"wailer":
			n = CharacterBody3D.new()
			n.set_script(load("res://scripts/bog_wailer.gd"))
		"peeper":
			n = Node3D.new()
			n.set_script(load("res://scripts/peeper.gd"))
	n.position = Vector3(randf_range(-50, 50), 200, randf_range(-50, 50))
	root.add_child(n)
	return n


func _worn(n: Node, kind: String) -> Array:
	return n.find_children("*", "MeshInstance3D", true, false).filter(func(m): return _patch(m) == kind)


func _plain_scales(m: Node) -> bool:
	var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
	return mat != null and mat.resource_name == "Croc Scales" and not mat.has_meta(DP.SURFACE_META)


func _is_plain(n: Node) -> bool:
	return _skins(n).is_empty() and _worn(n, "reptile_scales").is_empty() and _worn(n, "goblin_skin").is_empty() \
		and _worn(n, "tweed").is_empty()


func _mats(parts: Array) -> Array:
	var ids := []
	for m in parts:
		var id := (m as MeshInstance3D).material_override.get_instance_id()
		if not id in ids:
			ids.append(id)
	ids.sort()
	return ids


func _skins(n: Node) -> Array:
	return n.find_children("Detailed Skin", "MeshInstance3D", true, false)


func _settle(nodes: Array) -> void:
	for i in 4:
		await process_frame
	for n in nodes:
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED


func _run() -> void:
	var wd: Node = root.get_node_or_null("WorldDetail")
	check(wd != null and DP.on(), "the detail pipeline is on")
	var made := {}
	for w in ["croc", "croc2", "pebble", "boulder", "stormram", "goblin", "goblin2", "tock", "snatcher", "wailer",
			"peeper"]:
		made[w] = _make(w.trim_suffix("2"))
	await _settle(made.values())

	# The Crocodillos
	for w in ["croc", "pebble", "boulder"]:
		var c: Node = made[w]
		var scales := _worn(c, "reptile_scales")
		check(scales.size() >= 6, "%s: %d parts wear the reptile scales" % [w, scales.size()])
		check(scales.size() > 0 and scales.all(_has_maps), "%s: the scales have their baked maps" % w)
		var shell := _skins(c)
		check(shell.size() >= 1 and shell.all(func(s): return _drawn(s) and not _drawn(s.get_parent())),
			"%s: its shell ball wears the baked shell skin (%d), the plain ball isn't drawn" % [w, shell.size()])
	var plain_left := (made.croc as Node).find_children("*", "MeshInstance3D", true, false).filter(_plain_scales)
	check(plain_left.is_empty(), "no Crocodillo part is left in the plain scales")
	var a: Array = _worn(made.croc, "reptile_scales")
	var b: Array = _worn(made.croc2, "reptile_scales")
	check(a.size() > 0 and _mats(a) == _mats(b), "two Crocodillos share their scaled materials")
	var before := a.size()
	check(DP.dress_crocodillo(made.croc) >= 0 and _worn(made.croc, "reptile_scales").size() == before
		and _skins(made.croc).size() == _skins(made.croc2).size(), "dressing a Crocodillo again changes nothing")
	check((made.boulder as Node).find_children("Detailed *Boulder*", "", true, false).size() > 0,
		"the Boulderdillo still wears its baked boulders too")
	check(_worn(made.stormram, "reptile_scales").all(_drawn) and _skins(made.stormram).all(
		func(k): return (k.get_parent() as MeshInstance3D).mesh != null),
		"the Stormram's stripped parts stay stripped (only parts it kept are scaled)")

	# The Time Goblins
	for w in ["goblin", "tock"]:
		var g: Node = made[w]
		var skin := _worn(g, "goblin_skin")
		var cloth := _worn(g, "tweed")
		check(skin.size() >= 6, "%s: %d parts wear the goblin skin" % [w, skin.size()])
		check(cloth.size() >= 2, "%s: %d parts wear the woven cloth" % [w, cloth.size()])
		check((skin + cloth).all(_has_maps), "%s: they have their baked maps" % w)
	var ga: Array = _worn(made.goblin, "goblin_skin")
	var gb: Array = _worn(made.goblin2, "goblin_skin")
	check(ga.size() > 0 and _mats(ga) == _mats(gb), "two Time Goblins share their patched materials")
	check(DP.dress_goblin_skin(made.goblin) == 0, "dressing a goblin again changes nothing")
	check(_worn(made.snatcher, "goblin_skin").is_empty() and _worn(made.snatcher, "tweed").is_empty(),
		"the Dawn Snatcher (its own look) gets no goblin skin")

	# The Bog Wailer and the Peeper
	var w_skins := _skins(made.wailer)
	check(w_skins.size() >= 6, "the Bog Wailer's head and moss wear baked skins (%d)" % w_skins.size())
	check(_worn(made.wailer, "goblin_skin").size() >= 3, "its body wears the goblin skin (%d)" %
		_worn(made.wailer, "goblin_skin").size())
	var mouth := (made.wailer as Node).find_child("Mouth", true, false)
	check(mouth != null and _drawn(mouth), "its mouth is still drawn (it opens to wail)")
	var p_skins := _skins(made.peeper)
	check(p_skins.size() >= 6, "the Peeper's fluff wears the moth fuzz (%d)" % p_skins.size())
	check((made.peeper as Node).find_children("Eye", "MeshInstance3D", true, false).all(_drawn),
		"the Peeper's eyes stay as they were")

	# Detail off: a new one is left as built
	if wd:
		wd.set("detail_props", false)
		var plain := [_make("croc"), _make("goblin"), _make("wailer"), _make("peeper")]
		await _settle(plain)
		check(plain.all(_is_plain), "with detail off every enemy keeps its plain look")
		wd.set("detail_props", true)

	print("\nRESULT %s (%d failed)" % ["FAILED" if failures else "PASSED", failures])
	quit(1 if failures else 0)
