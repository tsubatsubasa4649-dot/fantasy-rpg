extends SceneTree
const SpriteAnimation = preload("res://scripts/sprite_animation.gd")
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
	check(ui.game.registry.records("maps").size() == 3, "Scene initializes village, overworld and cave")
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
	var initial_location: String = ui.location_id
	ui.location_id = "world_map"
	ui.tile_pos = Vector2i(12, 14)
	ui._refresh()
	check(ui._current_rows().size() == 24, "World map data exceeds viewport height")
	check(ui.map_grid.get_child_count() == 960, "World tiles stay cached for pixel-smooth scrolling")
	check(ui._camera_origin().x > 0 and ui._camera_origin().y > 0, "Overworld camera follows hero away from origin")
	var old_camera: Vector2i = ui._camera_origin()
	ui.tile_pos = Vector2i(30, 16)
	ui._refresh()
	check(ui._camera_origin().x > old_camera.x, "Camera scrolls toward eastern landmarks")
	check(ui._camera_origin().y > old_camera.y, "Camera scrolls toward southern landmarks")
	var world_cached_tile: Control = ui.map_grid.get_child(123)
	ui._draw_map()
	check(ui.map_grid.get_child(123) == world_cached_tile, "World scrolling does not destroy and recreate tiles")
	ui.tile_pos = Vector2i(12, 14)
	ui._refresh()
	await process_frame
	var grid_before: Vector2 = ui.map_grid.position
	var grid_target: Vector2 = ui._camera_grid_position(Vector2i(13, 14))
	check(grid_before.distance_to(grid_target) > 5.0, "Overworld has a non-zero camera pan to next tile")
	ui._walk(1, 0)
	await create_timer(0.14).timeout
	var pan_distance: float = ui.map_grid.position.distance_to(grid_before)
	check(pan_distance > 2.0 and pan_distance < grid_before.distance_to(grid_target) - 2.0, "Camera moves smoothly through intermediate pixel offsets")
	await create_timer(0.25).timeout
	check(ui.map_grid.get_child(123) == world_cached_tile, "Camera pan retains generated tile nodes")
	ui._travel("cave", [1, 5])
	check(ui.location_id == "cave" and ui.tile_pos == Vector2i(1, 5), "World to cave travel uses destination spawn")
	ui._travel("world_map", [30, 7])
	check(ui.location_id == "world_map" and ui.tile_pos == Vector2i(30, 7), "Cave returns to its world-map entrance")
	ui.location_id = initial_location
	ui.tile_pos = Vector2i(4, 5)
	ui._refresh()
	await process_frame
	await process_frame

	check(ui.description_label.text.contains("ウィンドル"), "New Windle village visible on startup")
	check(ui.tile_pos == Vector2i(4, 5), "Hero spawns at village entry rather than map edge")
	var village: Dictionary = ui.game.registry.by_id("maps", "field")
	check(village.get("points", []).size() >= 9, "Village includes NPCs and hidden-discovery points")
	check(str(village.get("rows", [])[3]).contains("p"), "Village road exists in map data")
	var walk_start: Vector2 = ui.hero_overlay.position
	ui._walk(1, 0)
	check(ui.walk_sprite_frame == 0, "First step pose appears immediately")
	check(ui.tile_pos == Vector2i(5, 5), "Mobile movement updates logical tile")
	check(ui.hero_overlay.position.distance_to(walk_start) < 1.0, "Hero does not teleport to target on first input")
	await create_timer(0.17).timeout
	var halfway: float = ui.hero_overlay.position.distance_to(walk_start)
	check(halfway > 2.0 and halfway < float(ui.cell_size) - 2.0, "Hero smoothly moves between neighboring tile coordinates")
	check(ui.walking, "Movement remains animated after logical grid step")
	check(ui.hero_overlay != null and ui.hero_overlay.texture != null, "Hero is persistent independent of terrain tiles")
	check(ui.walk_textures.size() == 4, "Walking animation has all four directions")
	check(ui.character_walk_frames.size() == 4, "Walking loader handles all four character profiles")
	for actor_id in ["ch_ricky", "ch_meri", "ch_goro"]:
		var profile: Dictionary = ui.game.registry.by_id("characters", actor_id)
		check(profile.has("walk_animation"), "Companion walk spec can be extended: " + actor_id)
		check(ui.character_walk_frames.has(actor_id), "Companion has an animation registry entry: " + actor_id)
	var hero_visual: Dictionary = ui.game.registry.by_id("characters", "hero")
	var hero_rect: Rect2 = SpriteAnimation.field_rect(float(ui.cell_size), hero_visual)
	check(hero_rect.size.x > float(ui.cell_size), "Hero larger than one tile without moving its feet")
	check(hero_rect.position.y < 0.0, "Hero grows upward instead of shifting feet")
	check(absf(ui.hero_overlay.size.x - hero_rect.size.x) < 1.0, "Hero portrait uses data-driven enlarged size")
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
	check(ui.tile_pos == Vector2i(6, 5), "Holding direction moves immediately")
	await create_timer(0.48).timeout
	ui._process(0.25)
	check(ui.tile_pos == Vector2i(7, 5), "Held direction repeats movement")
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
	for hero_avatar in ui.battle_party_visual.get_children():
		check(hero_avatar is VBoxContainer, "Combat actors retain compact layout")
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
