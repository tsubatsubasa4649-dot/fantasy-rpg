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
	check(ui.textures.size() >= 16, "Original eight images plus eight unique party sprites decode")
	check(ui.textures.has("ricky_field") and ui.textures.has("meri_battle") and ui.textures.has("goro_battle"), "Three companion sprites are available in both game modes")
	check(ui.theme != null and ui.theme.default_font != null, "Imported Japanese font resource is loaded")
	check(ThemeDB.fallback_font == ui.theme.default_font, "Global UI fallback matches bundled Japanese font")
	if ui.theme != null and ui.theme.default_font != null:
		check(ui.theme.default_font.has_char(0x59CB) and ui.theme.default_font.has_char(0x307E), "Japanese Kanji and Hiragana glyphs are present")
	if ui.textures.has("house"):
		var house_image: Image = ui.textures["house"].get_image()
		check(house_image.get_pixel(0, 0).a < 0.1, "House background edge is transparent")
	if ui.textures.has("ground"):
		var ground: Texture2D = ui.textures["ground"]
		check(ground.get_width() < 32 and ground.get_height() < 32, "Ground padding was cropped away")
	check(ui.map_grid.get_child_count() == 70, "Map builds 10x7 visible tiles")
	check(ui.description_label.text.contains("草原"), "Field visible on startup")
	var walk_start: Vector2 = ui.hero_overlay.position
	ui._walk(1, 0)
	check(ui.walk_sprite_frame == 0, "First step pose appears immediately")
	check(ui.tile_pos == Vector2i(2, 4), "Mobile movement updates logical tile")
	check(ui.hero_overlay.position.distance_to(walk_start) < 1.0, "Hero does not teleport to target on first input")
	await create_timer(0.17).timeout
	var halfway: float = ui.hero_overlay.position.distance_to(walk_start)
	check(halfway > 2.0 and halfway < float(ui.cell_size) - 2.0, "Hero smoothly moves between neighboring tile coordinates")
	check(ui.walking, "Movement remains animated after logical grid step")
	check(ui.hero_overlay != null and ui.hero_overlay.texture != null, "Hero is persistent independent of terrain tiles")
	check(ui.walk_textures.size() == 4, "Walking animation has all four directions")
	for direction in range(4):
		check(ui.walk_textures[direction].size() == 3, "Direction " + str(direction) + " has idle and two steps")
		for frame in range(3):
			var sprite: AtlasTexture = ui.walk_textures[direction][frame]
			check(sprite.region == Rect2(frame * 48, direction * 56, 48, 56), "Frame atlas region is correct")
	check(ui._face_row(Vector2i(0, 1)) == 0, "Down uses front sprite row")
	check(ui._face_row(Vector2i(-1, 0)) == 1, "Left uses side sprite row")
	check(ui._face_row(Vector2i(1, 0)) == 2, "Right uses opposite side sprite row")
	check(ui._face_row(Vector2i(0, -1)) == 3, "Up uses back sprite row")
	check(ui.walk_sprite_direction == 2, "Right walk selects right-facing character artwork")
	check(not ui.action_scroll.visible, "Choices stay hidden until explicit interaction")
	await create_timer(0.37).timeout
	check(not ui.walking, "Smooth movement finishes after tween")
	check(ui.walk_sprite_frame == 1, "Idle pose restored after walking")
	ui._interact()
	check(ui.action_scroll.visible, "Talking reveals choices directly below dialogue")
	check(ui.action_list.get_child_count() >= 1, "Talk options appear within choice panel")
	ui._interact()
	check(not ui.action_scroll.visible, "Second interaction closes choices")
	check(ui.direction_controls.get_child_count() == 2, "Large D-pad and separate action button exist")
	check(ui.root_column.size.y >= 800, "Full-screen UI root fills portrait viewport")
	check(ui.direction_controls.position.y + ui.direction_controls.size.y <= ui.get_viewport_rect().size.y + 1, "D-pad fully inside viewport")
	check(ui.action_scroll.position.y + ui.action_scroll.size.y < ui.direction_controls.position.y, "Dialogue choices do not overlap controls")
	check(ui.map_frame.position.y + ui.map_frame.size.y < ui.dialogue_panel.position.y, "Map and dialogue are separated")
	check(ui.menu_button.text == "メニュー", "Compact menu replaces permanent button row")
	check(ui.music_player != null and ui.sound_player != null and ui.hit_player != null, "BGM and separate SFX channels exist")
	for track in ["field", "cave", "battle", "step", "confirm", "attack", "hit"]:
		check(ResourceLoader.exists("res://audio/" + track + ".wav"), "Original music track imported: " + track)
	check(ui.management_panel.get_child_count() == 6, "Music and audio test are both in menu")
	ui._audio_diagnostic()
	check(ui.audio_unlocked, "Explicit audio test unlocks the playback path")
	check(ui.current_music_id == "field", "Audio test chooses current region BGM")
	ui._toggle_music()
	check(not ui.music_on and ui.music_toggle_button.text == "音楽 OFF", "Music can be muted")
	ui._toggle_music()
	check(ui.music_on, "Music can be restored")
	check(ui.hud_title.position.x + ui.hud_title.size.x <= ui.menu_button.position.x, "Title does not overlap menu")
	check(ui.status_label.position.x + ui.status_label.size.x <= ui.menu_button.position.x, "Status does not overlap menu")
	check(ui.action_scroll.size.y >= 100.0, "At least two short dialogue choices fit")
	check(not ui.battle_backdrop.visible, "Battle background hidden during exploration")
	ui._toggle_menu()
	check(ui.management_panel.visible, "Menu exposes management commands")
	ui._toggle_menu()
	check(not ui.management_panel.visible, "Menu closes")
	var pad: GridContainer = ui.direction_controls.get_child(0)
	check(pad.get_child_count() == 9, "D-pad has nine cells")
	var up: Button = pad.get_child(1)
	check(up.custom_minimum_size.x >= 90 and up.custom_minimum_size.y >= 80, "Directional touch target is at least 90x80")
	ui._begin_hold(Vector2i(1, 0))
	check(ui.tile_pos == Vector2i(3, 4), "Holding direction moves immediately")
	await create_timer(0.48).timeout
	ui._process(0.25)
	check(ui.tile_pos == Vector2i(4, 4), "Held direction repeats movement")
	await create_timer(0.48).timeout
	ui._end_hold()
	check(ui.held_direction == Vector2i.ZERO, "Releasing direction stops movement")
	check(ui.audio_unlocked, "First input unlocks browser audio")
	check(ui.battle_commands.get_child(0).custom_minimum_size.y >= 70, "Battle command buttons have large touch targets")
	ui._begin_battle("slime")
	check(ui.battle_active, "Encounter enters battle scene")
	check(ui.current_music_id == "battle", "Battle changes original BGM theme")
	check(ui.battle_panel.visible, "Side-view combat panel is visible")
	check(ui.battle_backdrop.visible, "Battle has its own visible framed background")
	check(ui.battle_panel.position.y >= ui.battle_backdrop.position.y, "Battle actors are inside framed region")
	check(ui.battle_panel.position.y + ui.battle_panel.size.y <= ui.battle_backdrop.position.y + ui.battle_backdrop.size.y, "Battle UI fits its region")
	check(not ui.direction_controls.visible and ui.combat_controls.visible, "Battle switches controls instead of stacking layouts")
	check(not ui.map_frame.visible, "Battle replaces the map, not added below it")
	check(ui.battle.allies.size() == 1, "Unrecruited run uses hero")
	check(ui.battle_party_visual.columns == 2, "Battle allies use two-column formation")
	check(ui.battle_party_visual.get_child_count() == 1, "Hero portrait exists")
	var hero_column: VBoxContainer = ui.battle_party_visual.get_child(0)
	var hero_portrait: TextureRect = hero_column.get_child(0)
	check(hero_portrait.custom_minimum_size.x >= 70, "Battle human actor is not tiny beside slime")
	check(ui.battle_enemy_sprite.custom_minimum_size.x <= 100, "Slime no longer dominates battle width")
	check(hero_portrait.custom_minimum_size.y >= 72, "Human combat actor has a larger silhouette than exploration sprite")
	check(ui.game.registry.by_id("characters", "ch_meri").has("battle_sprite_id"), "Character battle artwork is data-driven")
	ui._choose_battle("skill")
	check(ui.battle.round_number == 2, "One turn command resolves")
	ui.battle_active = false
	ui._refresh()
	check(ui.direction_controls.visible, "Controls recover after battle")
	# Full team setup: four distinct party characters must occupy the battle grid.
	ui.game.run_event("help_village")
	ui.game.run_event("recruit_ricky")
	ui.game.run_event("find_forest_clue")
	ui.game.run_event("recruit_meri")
	ui.game.advance_days(20)
	ui.game.run_event("save_refugees")
	ui.game.run_event("recruit_goro")
	check(ui.game.set_party(["ch_ricky", "ch_meri", "ch_goro"]), "Can form a four-person party")
	ui._begin_battle("slime")
	check(ui.battle_party_visual.get_child_count() == 4, "Four unique actor portraits appear in battle formation")
	check(ui.battle_party_visual.columns == 2, "Four characters use compact 2x2 battle layout")
	for ally in ui.battle.allies:
		var char: Dictionary = ui.game.registry.by_id("characters", str(ally["id"]))
		check(ui.textures.has(str(char.get("battle_sprite_id", ""))), "Battle texture exists for " + str(ally["id"]))
	root.remove_child(ui)
	ui.queue_free()
	print("PHASE 3 UI SMOKE FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
