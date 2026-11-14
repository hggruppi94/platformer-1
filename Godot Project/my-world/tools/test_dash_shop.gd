extends SceneTree

# Checks Hayden's 13 Nov 2026 playtest fixes to Dash's gadget stall, the menus and the Star Popper:
# - The Star Popper holds a tank of bubbles (no more endless ammo): each shot uses one, empty it won't fire, a refill at
#   Dash's stall fills it, an ammo bubble or crate tops it up, and when it's nearly empty and she isn't shooting it
#   slowly mixes a few new bubbles (up to Arsenal.POPPER_TOP_UP, never more). It runs low and says so once. An old
#   save's endless -1 comes back full. The readout in the corner shows it from the first gadget.
# - Dash's window opens at the top of its list (it opened scrolled to the bottom), and a buy stays on that row.
# - Every scrolling menu shows a scroll bar you can see (UiStyle.scroll_bar).
# - Dash walks you round his stall the first time it opens (scripts/shop_tour.gd): each step points at its part of the
#   window, Next and Skip work, closing the shop ends it, it's remembered, and "How does it work?" shows it again.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_dash_shop.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.dash_shop_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.dash_shop_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var settings: Node
var arsenal: Node
var shop: Node
var dialogue: Node
var _had_save := false


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
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	arsenal = root.get_node("Arsenal")
	shop = root.get_node("Shop")
	dialogue = root.get_node("Dialogue")
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	arsenal.reset()
	for e in root.get_node("Schematics").LIST:
		dialogue.set_flag("schematic_" + str(e.id))
	dialogue.flags.erase(shop.TOUR_FLAG)

	change_scene_to_file(TOWN)
	await _frames(8)
	var town := current_scene
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var popper = p.get("popper")
	for g in town.find_children("Gloop *", "", true, false) + town.find_children("Crocodillo *", "", true, false):
		(g as Node3D).set_physics_process(false)
		(g as Node3D).global_position += Vector3(0, -300, 0)

	# --- Dash's tour, the first time his stall opens ---
	game.sparkles = 50
	shop.auto_tour = true
	shop.open("Gadget")
	await _frames(3)
	var tour = shop.tour
	check(tour.is_on() and tour.index == 0, "the first time Dash's stall opens, he starts showing you round")
	var sc := shop._scroll as ScrollContainer
	var seen_targets := []
	var all_on_screen := true
	var vp: Vector2 = root.get_visible_rect().size
	for i in tour.STEPS.size():
		await _frames(2)
		var t: Control = tour.target()
		seen_targets.append(t)
		var bubble: Rect2 = tour._bubble.get_global_rect()
		if not Rect2(Vector2.ZERO, vp).grow(2.0).encloses(bubble):
			all_on_screen = false
		if i < tour.STEPS.size() - 1:
			tour._next.pressed.emit()
	check(seen_targets[0] == shop._title and seen_targets[1] == shop._wallet, "...his sparkles step points at your sparkles")
	check(seen_targets[2] != null and str(seen_targets[2].name) == "Row star_popper", "...then at a gadget and its blueprint")
	check(seen_targets[3] != null and str(seen_targets[3].name) == "Button star_popper", "...then at its Get it! button")
	check(seen_targets[5] == shop._help and seen_targets[6] == shop._close, "...then How does it work? and Bye!")
	check(all_on_screen, "...and his bubble stays on the screen every step")
	check(tour._next.text == "Done!" and not tour._skip.visible, "the last step says Done!")
	tour._next.pressed.emit()
	await _frames(2)
	check(not tour.is_on() and dialogue.flags.has(shop.TOUR_FLAG), "...and it's remembered once it's done")
	shop.close()
	shop.open("Gadget")
	await _frames(3)
	check(not tour.is_on(), "it doesn't start by itself the next time")
	check(shop._help.visible, "...but the stall has a How does it work? button")
	shop._help.pressed.emit()
	await _frames(2)
	check(tour.is_on(), "...that shows it again")
	tour._skip.pressed.emit()
	await _frames(2)
	check(not tour.is_on(), "Skip ends it")
	shop._help.pressed.emit()
	await _frames(2)
	shop.close()
	await _frames(2)
	check(not tour.is_on(), "closing the shop ends it too")
	shop.open("Bakery")
	await _frames(2)
	check(not shop._help.visible and not tour.is_on(), "other stalls have no tour")
	shop.close()

	# --- Buying the Star Popper; the window starts at the top ---
	shop.open("Gadget")
	await _frames(4)
	check(sc.scroll_vertical == 0, "Dash's window opens at the top of the list (scrolled %d)" % sc.scroll_vertical)
	var focus := root.gui_get_focus_owner()
	check(focus != null and str(focus.name) == "Button star_popper", "...with the top row picked (%s)" % (focus.name if focus else "nothing"))
	check(shop.buy("star_popper") and arsenal.owns("popper"), "buying the Star Popper")
	await _frames(3)
	focus = root.gui_get_focus_owner()
	check(focus != null and str(focus.name) == "Button star_popper", "...the window stays on that row after the buy")
	var bar := sc.get_v_scroll_bar()
	await _frames(2)
	var long_list: bool = (shop._rows as Control).get_combined_minimum_size().y > sc.size.y + 1.0
	check(not long_list or bar.visible, "a long list shows its scroll bar (list %.0f, box %.0f)"
		% [(shop._rows as Control).get_combined_minimum_size().y, sc.size.y])
	var track := bar.get_theme_stylebox("scroll") as StyleBoxFlat
	check(track != null and track.bg_color.a >= 0.4 and bar.get_combined_minimum_size().x >= 12.0,
		"...and you can see it (%.0f px wide)" % bar.get_combined_minimum_size().x)
	shop.close()

	# --- Scroll bars everywhere ---
	var pm := root.get_node_or_null("PlayerMenu")
	if pm:
		pm.call("open")
		await _frames(3)
		var any := false
		for s in pm.find_children("*", "ScrollContainer", true, false):
			var st := (s as ScrollContainer).get_v_scroll_bar().get_theme_stylebox("scroll") as StyleBoxFlat
			any = st != null and st.bg_color.a >= 0.4
		check(any, "the player menu's pages have the same scroll bar")
		pm.call("close")
		await _frames(2)

	# --- The Star Popper's ammo ---
	var full: int = arsenal.max_ammo("popper")
	check(full == 40 and arsenal.ammo_of("popper") == full, "the Star Popper comes with %d bubbles" % full)
	popper.set("_cooldown", 0.0)
	var b = popper.shoot(false)
	check(b != null and arsenal.ammo_of("popper") == full - 1, "each bubble uses one (%d left)" % arsenal.ammo_of("popper"))
	arsenal.ammo["popper"] = 9
	arsenal._told_low.erase("popper")
	game.pending_message = ""
	arsenal.use_ammo("popper")
	check(arsenal.low("popper") and arsenal._told_low.has("popper"), "running low, she's told once")
	arsenal.ammo["popper"] = 0
	popper.set("_cooldown", 0.0)
	await _physics(2)
	check(popper.shoot(false) == null and arsenal.ammo_of("popper") == 0, "empty, it won't blow a bubble")
	# The top-up: nothing for a moment, then a bubble a second, never past POPPER_TOP_UP
	arsenal._popper_rest = 0.0
	await create_timer(1.5, true, false, true).timeout
	check(arsenal.ammo_of("popper") == 0, "...it waits a moment after the last shot before mixing more")
	arsenal._process(arsenal.POPPER_TOP_UP_WAIT)        # (the wait's over)
	for i in 30:
		arsenal._process(arsenal.POPPER_TOP_UP_EVERY + 0.01)
	check(arsenal.ammo_of("popper") == arsenal.POPPER_TOP_UP,
		"...then mixes a few new bubbles, but only up to %d (%d)" % [arsenal.POPPER_TOP_UP, arsenal.ammo_of("popper")])
	arsenal.use_ammo("popper")
	arsenal._process(arsenal.POPPER_TOP_UP_EVERY + 0.01)
	check(arsenal.ammo_of("popper") == arsenal.POPPER_TOP_UP - 1, "...and a shot starts the wait again")
	# Filling it up
	check(shop.can_buy("popper_refill") == "", "Dash sells a Bubble Refill")
	var had: int = game.sparkles
	check(shop.buy("popper_refill") and arsenal.ammo_of("popper") == full and game.sparkles == had - 1,
		"...it fills the Star Popper for 1 sparkle")
	check(shop.can_buy("popper_refill") == "It's full", "...not when it's full")
	arsenal.ammo["popper"] = 5
	var crate := town.get_node_or_null("Ammo Crate 1")
	if crate:
		crate.call("shot", 1, Vector3.ZERO, Vector3.ZERO)
	else:
		arsenal.refill("popper", maxi(1, roundi(full / 2.0)))
	check(arsenal.ammo_of("popper") > 5, "an ammo crate tops it up (%d)" % arsenal.ammo_of("popper"))
	check(shop.items.has("upgrade_popper_ammo_1"), "the workbench's Bigger Tank fits the Star Popper now")
	arsenal.upgrade("popper", "ammo")
	check(arsenal.max_ammo("popper") == 50 and arsenal.ammo_of("popper") == 50, "...a Bigger Tank holds more, full")
	# An old save from when it never ran out
	var d: Dictionary = arsenal.save_data().duplicate(true)
	d.ammo["popper"] = -1
	arsenal.load_data(d)
	check(arsenal.ammo_of("popper") == arsenal.max_ammo("popper"), "an old save's endless Star Popper comes back full")
	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	shop.auto_tour = false
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save and FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	quit(1 if failures > 0 else 0)
