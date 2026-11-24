extends SceneTree

# Checks the friends' baked-in detail (24 Nov 2026, tools/build_friend_detail.py): every part of Rex, Dash, Pip,
# Bruno, Melody, Heather and Bramble has the baked tint, normal map and shadows, except the parts kept crisp (eyes,
# mouths, glows), and each model still has its rig, its animations and every material name the game recolours by.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_friend_detail.gd
#
# Only loads the models: no save or setting is touched.

const FRIENDS := {
	"wolf": {"flat": ["Eye White", "Iris", "Iris Light", "Pupil", "Eye Shine", "Mouth", "Teeth"], "parts": 19, "anims": 3},
	"bike_boy": {"flat": ["Eye White", "Pupil", "Mouth", "Lens Shine"], "parts": 21, "anims": 4},
	"moth_kid": {"flat": ["Eye White", "Iris", "Iris Light", "Pupil", "Eye Shine", "Mouth", "Tongue"], "parts": 26, "anims": 4},
	"bruno": {"flat": ["Eye White", "Iris", "Iris Light", "Pupil", "Eye Shine", "Mouth", "Tongue", "Teeth", "Patch Text"],
		"parts": 29, "anims": 8},
	"melody": {"flat": ["Eye White", "Iris", "Iris Light", "Pupil", "Eye Shine", "Mouth", "Tongue"], "parts": 23, "anims": 7},
	"cattle_girl": {"flat": ["Eye White", "Iris", "Iris Light", "Pupil", "Eye Shine", "Mouth", "Glow Teal", "Glow Violet"],
		"parts": 32, "anims": 3},
	"plant_girl": {"flat": ["Lash", "Mouth", "Trap Teeth", "Dew"], "parts": 23, "anims": 10},
}

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	for model in FRIENDS:
		_check_model(model, FRIENDS[model])
	print("\n%s: %d failure(s)" % ["FAILED" if failures else "ALL PASSED", failures])
	quit(1 if failures else 0)


func _check_model(model: String, want: Dictionary) -> void:
	var path := "res://models/characters/%s.glb" % model
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	var mats := {}
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (m as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat:
				mats[mat.resource_name] = mat
	check(mats.size() == want["parts"], "%s keeps all %d parts (has %d)" % [model, want["parts"], mats.size()])
	var bare := []
	var crisp_spoiled := []
	for n in mats:
		var mat: StandardMaterial3D = mats[n]
		var has := mat.albedo_texture != null and mat.normal_enabled and mat.normal_texture != null \
			and mat.ao_enabled and mat.ao_texture != null
		if n in want["flat"]:
			if mat.normal_texture != null or mat.albedo_texture != null:
				crisp_spoiled.append(n)
		elif not has:
			bare.append(n)
	check(bare.is_empty(), "%s: every part has its baked tint, normal map and shadows %s" % [model, bare])
	check(crisp_spoiled.is_empty(), "%s: eyes, mouth and glows stay crisp %s" % [model, crisp_spoiled])
	var tint_path := "res://models/characters/%s_detail_tint.png" % model
	check(ResourceLoader.exists(tint_path), "%s's baked textures are in the project (%s)" % [model, tint_path])
	var skel := scene.find_children("*", "Skeleton3D", true, false)
	check(skel.size() == 1 and (skel[0] as Skeleton3D).get_bone_count() > 10, "%s still has its rig" % model)
	var anim: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	if want["anims"] > 0:
		check(anim != null and anim.get_animation_list().size() >= want["anims"], "%s keeps its animations" % model)
	scene.free()
