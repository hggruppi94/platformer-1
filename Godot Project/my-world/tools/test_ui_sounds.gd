extends SceneTree

# Checks the shared menu sounds (scripts/audio.gd _on_node_added): every button clicks when it's pressed and ticks
# softly when you move onto it, a button whose own code already plays a menu sound doesn't play a second one, a
# button can opt out with meta "no_ui_sound", disabled or hidden buttons stay quiet, and a button made later is
# hooked too.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_ui_sounds.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.ui_sounds_backup.json"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var audio := root.get_node("Audio")
	var ui := CanvasLayer.new()
	root.add_child(ui)
	var box := VBoxContainer.new()
	ui.add_child(box)
	var plain := Button.new()
	plain.text = "Plain"
	box.add_child(plain)
	var own := Button.new()
	own.text = "Own sound"
	own.pressed.connect(func() -> void: audio.play("ui_back", -4.0, 0.0))
	box.add_child(own)
	var hushed := Button.new()
	hushed.text = "Hushed"
	hushed.set_meta("no_ui_sound", true)
	box.add_child(hushed)
	var off := Button.new()
	off.text = "Disabled"
	off.disabled = true
	box.add_child(off)
	await _frames(3)

	var n: int = audio.ui_sounds
	plain.pressed.emit()
	await _frames(2)
	check(audio.ui_sounds == n + 1, "pressing a plain button clicks")
	n = audio.ui_sounds
	own.pressed.emit()
	await _frames(2)
	check(audio.ui_sounds == n, "a button with its own menu sound doesn't play a second one")
	n = audio.ui_sounds
	hushed.pressed.emit()
	await _frames(2)
	check(audio.ui_sounds == n, "a button marked no_ui_sound stays quiet")

	await _wait_ms(120)
	n = audio.ui_sounds
	plain.grab_focus()
	await _frames(2)
	check(audio.ui_sounds == n + 1, "moving onto a button ticks")
	n = audio.ui_sounds
	own.grab_focus()
	await _frames(2)
	check(audio.ui_sounds == n, "a second move straight after doesn't rattle (70 ms gap)")
	await _wait_ms(120)
	n = audio.ui_sounds
	off.focus_entered.emit()
	await _frames(2)
	check(audio.ui_sounds == n, "a disabled button doesn't tick")
	plain.visible = false
	n = audio.ui_sounds
	plain.focus_entered.emit()
	await _frames(2)
	check(audio.ui_sounds == n, "a hidden button doesn't tick")
	ui.queue_free()
	await _frames(2)

	var later := Button.new()
	later.text = "Added later"
	root.add_child(later)
	await _frames(2)
	check(_connected(later, audio), "a button added later is hooked too")
	later.queue_free()

	_put_save_back()
	print("RESULT %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(failures)


func _connected(b: Button, audio: Node) -> bool:
	for c in b.pressed.get_connections():
		if (c.callable as Callable).get_object() == audio:
			return true
	return false


func _wait_ms(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await process_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")


func _frames(n: int) -> void:
	for i in n:
		await process_frame
