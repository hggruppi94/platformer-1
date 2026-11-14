extends SceneTree

# Checks the cut-off-words checker itself (tools/ui_watch.gd, used by tools/audit_ui.gd and tools/playthrough.gd
# --ui-watch): it has to catch words that really are cut off, and stay quiet about ones that fit.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_ui_watch.gd

const UI_WATCH := preload("res://tools/ui_watch.gd")

var failures := 0
var layer: CanvasLayer


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	layer = CanvasLayer.new()
	root.add_child(layer)
	for i in 3:
		await process_frame

	# A window whose words fit
	var ok := _window(Vector2(80, 80), Vector2(400, 0), "A short line that fits.")
	await _settle()
	check(UI_WATCH.scan(root).is_empty(), "words that fit aren't flagged (%s)" % str(UI_WATCH.scan(root)))
	ok.queue_free()

	# A window off the right edge of the screen
	var vp := root.get_visible_rect().size
	var off := _window(Vector2(vp.x - 100, 80), Vector2(300, 0), "Half of me is off the screen.")
	await _settle()
	check(_has(UI_WATCH.scan(root), "off the screen"), "a window off the edge is flagged")
	off.queue_free()

	# Words in a fixed-height box that's too short for them (wrapping onto lines that hang out of the window)
	var short := PanelContainer.new()
	short.position = Vector2(80, 80)
	layer.add_child(short)
	var c := Control.new()
	c.custom_minimum_size = Vector2(260, 40)
	short.add_child(c)
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = "These words go on and on, much longer than the little box they've been given, so they hang out of it."
	l.size = Vector2(260, 40)
	c.add_child(l)
	await _settle()
	var found := UI_WATCH.scan(root)
	check(_has(found, "don't fit") or _has(found, "spills out"), "words too long for their box are flagged (%s)" % str(found))
	short.queue_free()

	# A button squeezed narrower than its word, with "..." trimming
	var b := Button.new()
	b.text = "A really very long button"
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.position = Vector2(80, 300)
	b.size = Vector2(60, 40)
	layer.add_child(b)
	await _settle()
	check(_has(UI_WATCH.scan(root), "don't fit"), "a trimmed button is flagged")
	b.queue_free()

	# Words in a scroll list, scrolled out of sight: that's fine
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 80)
	scroll.size = Vector2(300, 100)
	layer.add_child(scroll)
	var v := VBoxContainer.new()
	scroll.add_child(v)
	for i in 20:
		var row := Label.new()
		row.text = "Row %d" % i
		v.add_child(row)
	await _settle()
	check(UI_WATCH.scan(root).is_empty(), "rows scrolled out of a list aren't flagged")
	scroll.queue_free()

	await _settle()
	print("\nRESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _window(at: Vector2, size: Vector2, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = at
	p.custom_minimum_size = size
	layer.add_child(p)
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	p.add_child(l)
	return p


func _has(found: Array[String], what: String) -> bool:
	for f in found:
		if what in f:
			return true
	return false


func _settle() -> void:
	for i in 4:
		await process_frame
