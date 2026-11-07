extends SceneTree

# Saves the shared menu look (scripts/ui_style.gd) at the usual text size as res://ui/theme.tres, the project's theme
# (project.godot, gui/theme/custom), so every Control that doesn't set its own theme wears it, in the editor too.
# Re-run after changing UiStyle:
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/make_ui_theme.gd

func _initialize() -> void:
	var t := UiStyle.theme(1.0, false, false)
	var err := ResourceSaver.save(t, "res://ui/theme.tres")
	print("Saved res://ui/theme.tres: ", error_string(err))
	quit(0 if err == OK else 1)
