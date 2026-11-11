extends SceneTree
## Verifies that the actual vertical-slice scene can be instantiated headlessly.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, title: String) -> void:
	if ok:
		print("PASS UI: ", title)
	else:
		failures += 1
		push_error("FAIL UI: " + title)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/vertical_slice.tscn")
	check(packed != null, "Vertical-slice scene loads")
	if packed == null:
		quit(1)
		return
	var ui: Control = packed.instantiate()
	root.add_child(ui)
	check(ui.game.registry.records("maps").size() == 2, "Scene initializes data registry")
	check(ui.textures.size() == 8, "All eight generated PNG images decode")
	check(ui.theme != null and ui.theme.default_font != null, "Embedded Japanese font is loaded")
	if ui.theme != null and ui.theme.default_font != null:
		check(ui.theme.default_font.has_char(0x59CB) and ui.theme.default_font.has_char(0x307E), "Japanese Kanji and Hiragana glyphs are present")
	if ui.textures.has("ground"):
		var ground: Texture2D = ui.textures["ground"]
		check(ground.get_width() < 32 and ground.get_height() < 32, "Ground padding was cropped away")
	check(ui.map_grid.get_child_count() == 70, "Map builds 10x7 visible tiles")
	check(ui.description_label.text.contains("草原"), "Field visible on startup")
	ui._walk(1, 0)
	check(ui.tile_pos == Vector2i(2, 4), "Mobile movement updates tile")
	ui._begin_battle("slime")
	check(ui.battle_active, "Encounter enters battle scene")
	check(ui.battle_panel.visible, "Side-view combat panel is visible")
	check(ui.battle.allies.size() == 1, "Unrecruited run uses hero")
	ui._choose_battle("skill")
	check(ui.battle.round_number == 2, "One turn command resolves")
	ui.battle_active = false
	ui._refresh()
	check(ui.direction_controls.visible, "Controls recover after battle")
	root.remove_child(ui)
	ui.queue_free()
	print("PHASE 3 UI SMOKE FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
