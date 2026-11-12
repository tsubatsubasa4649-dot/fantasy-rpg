extends Control
## Phase 3 vertical slice. UI controls are native Godot widgets; art is generated PNG data.
const GameSession = preload("res://scripts/game_session.gd")
const BattleEngine = preload("res://scripts/battle_engine.gd")
const SpriteAnimation = preload("res://scripts/sprite_animation.gd")
const TILE_SIZE := 44
const BUILD_ID := "RPG CAMERA-17 / SMOOTH FOLLOW"
const JAPANESE_FONT = preload("res://assets/NotoSansJP.ttf")
var game = GameSession.new()
var battle = BattleEngine.new()
var textures: Dictionary = {}
var location_id: String = "field"
var tile_pos: Vector2i = Vector2i(1, 4)
var battle_active: bool = false
var battle_enemy_id: String = ""
var status_label: Label
var description_label: Label
var message_label: Label
var map_grid: GridContainer
var action_list: VBoxContainer
var battle_panel: VBoxContainer
var battle_status: Label
var battle_visual: HBoxContainer
var battle_enemy_sprite: TextureRect
var battle_party_visual: GridContainer
var battle_commands: HBoxContainer
var direction_controls: HBoxContainer
var root_column: Control
var hud_panel: Panel
var hud_title: Label
var build_label: Label
var battle_backdrop: Panel
var map_frame: Panel
var map_center: Control
var dialogue_panel: Panel
var action_scroll: ScrollContainer
var menu_button: Button
var management_panel: HBoxContainer
var combat_controls: HBoxContainer
var screen_mode: String = "explore"
var cell_size: int = 44
const CAMERA_COLS: int = 10
const CAMERA_ROWS: int = 7
var button_size: Vector2 = Vector2(94, 74)
var last_point_id: String = ""
var last_phase: int = 0
var previous_tile_pos: Vector2i = Vector2i(-1, -1)
var facing: Vector2i = Vector2i.DOWN
var music_player: AudioStreamPlayer
var music_on: bool = true
var current_music_id: String = ""
var music_toggle_button: Button
var sound_player: AudioStreamPlayer
var hit_player: AudioStreamPlayer
var audio_unlocked: bool = false
var pending_choices: bool = false
var walking: bool = false
var hero_overlay: TextureRect
const WALK_DURATION := 0.28
var walk_elapsed: float = 0.0
var walk_sprite_direction: int = 0
var walk_sprite_frame: int = 1
var walk_textures: Array = []
var character_walk_frames: Dictionary = {}
var last_map_scene: String = ""
var last_map_phase: int = 0
var last_map_cell_size: int = 0
var rendered_tile_count: int = 0
var held_direction: Vector2i = Vector2i.ZERO
var repeat_clock: float = 0.0
const FIRST_REPEAT_DELAY := 0.08
const REPEAT_INTERVAL := 0.02

func _ready() -> void:
	if not game.initialize():
		var label := Label.new()
		label.text = "DATA ERROR: " + ", ".join(game.registry.errors)
		add_child(label)
		return
	_apply_japanese_font()
	_load_art()
	_build_ui()
	_setup_music()
	_restore_location()
	_show_message("魔王を倒せ。それだけが、思い出せる使命だった。")
	_refresh()
	_play_music_for_location()

func _apply_japanese_font() -> void:
	# Resource preload makes the imported font an explicit export dependency.
	var ui_theme := Theme.new()
	ui_theme.default_font = JAPANESE_FONT
	ui_theme.default_font_size = 19
	theme = ui_theme
	ThemeDB.fallback_font = JAPANESE_FONT
	ThemeDB.fallback_font_size = 19
	if not JAPANESE_FONT.has_char(0x59CB):
		push_error("Japanese glyph missing from exported Noto Sans JP font")

func _strip_tile_margin(source: Image) -> Image:
	# Cropping the white frame baked into generated PNGs; no art is drawn by code.
	var x0: int = source.get_width()
	var y0: int = source.get_height()
	var x1: int = -1
	var y1: int = -1
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var c: Color = source.get_pixel(x, y)
			# White padding was unintentionally included in the source tiles.
			if c.a < 0.5 or (c.r > 0.90 and c.g > 0.90 and c.b > 0.90):
				continue
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x)
			y1 = maxi(y1, y)
	if x1 < x0 or y1 < y0:
		return source
	# One or two edge pixels can remain tinted, so inset the edge slightly.
	var crop_x: int = mini(x1, x0 + 1)
	var crop_y: int = mini(y1, y0 + 1)
	var crop_width: int = maxi(1, x1 - crop_x)
	var crop_height: int = maxi(1, y1 - crop_y)
	return source.get_region(Rect2i(crop_x, crop_y, crop_width, crop_height))

func _remove_house_background(source: Image) -> Image:
	# Edge-connected dark backdrop is not part of the generated house art.
	# Flood-fill transparency preserves enclosed dark details such as windows.
	var img := source.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue: Array[Vector2i] = []
	for x in range(w):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in range(h):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))
	var cursor: int = 0
	while cursor < queue.size():
		var pos: Vector2i = queue[cursor]
		cursor += 1
		if pos.x < 0 or pos.x >= w or pos.y < 0 or pos.y >= h:
			continue
		var index: int = pos.y * w + pos.x
		if visited[index] != 0:
			continue
		visited[index] = 1
		var c: Color = img.get_pixelv(pos)
		# Includes the dark grey/black flat background of the image-gen tile.
		if c.a > 0.5 and not (c.r < 0.27 and c.g < 0.27 and c.b < 0.29):
			continue
		img.set_pixelv(pos, Color(0, 0, 0, 0))
		queue.append(pos + Vector2i.LEFT)
		queue.append(pos + Vector2i.RIGHT)
		queue.append(pos + Vector2i.UP)
		queue.append(pos + Vector2i.DOWN)
	return img

func _trim_transparent_padding(source: Image) -> Image:
	# Only crop the alpha channel of already generated sprite art.
	# No new artwork is produced by code.
	var left: int = source.get_width()
	var top: int = source.get_height()
	var right: int = -1
	var bottom: int = -1
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x, y).a < 0.15:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	if right < left:
		return source
	var margin: int = 1
	left = maxi(0, left - margin)
	top = maxi(0, top - margin)
	right = mini(source.get_width() - 1, right + margin)
	bottom = mini(source.get_height() - 1, bottom + margin)
	return source.get_region(Rect2i(left, top, right - left + 1, bottom - top + 1))

func _load_art() -> void:
	for id in ["ground", "wall", "house", "cave-entrance", "elder", "hero", "slime", "guardian"]:
		var path: String = "res://assets/" + id + ".b64"
		if not FileAccess.file_exists(path):
			continue
		var bytes: PackedByteArray = Marshalls.base64_to_raw(FileAccess.get_file_as_string(path).strip_edges())
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK:
			push_warning("Could not load pixel art: " + id)
			continue
		if id == "ground" or id == "wall":
			image = _strip_tile_margin(image)
		elif id == "house":
			image = _remove_house_background(image)
		if id in ["hero", "elder", "slime", "guardian", "house", "cave-entrance"]:
			image = _trim_transparent_padding(image)
		textures[id] = ImageTexture.create_from_image(image)
	_load_party_atlas()
	_load_walk_frames()

func _character_profile(character_id: String) -> Dictionary:
	return game.registry.by_id("characters", character_id)

func _profile_from_field_sprite(sprite_id: String) -> Dictionary:
	for profile in game.registry.records("characters"):
		if str(profile.get("field_sprite_id", "")) == sprite_id:
			return profile
	return {}

func _load_walk_frames() -> void:
	# Every actor uses the same sheet loader; companions may use static frames
	# until their directional PNG artwork is provided.
	character_walk_frames.clear()
	for profile in game.registry.records("characters"):
		var character_id: String = str(profile.get("id", ""))
		var frames: Array = SpriteAnimation.decode_frames(profile)
		character_walk_frames[character_id] = frames
	walk_textures = character_walk_frames.get("hero", [])
	if walk_textures.size() == 4:
		textures["hero_walk_atlas"] = walk_textures[0][0].atlas

func _face_row(direction: Vector2i) -> int:
	return SpriteAnimation.direction_row(_character_profile("hero").get("walk_animation", {}), direction)

func _set_hero_walk_frame(frame: int) -> void:
	walk_sprite_frame = clampi(frame, 0, 2)
	if hero_overlay == null:
		return
	var hero: Dictionary = _character_profile("hero")
	var texture: Texture2D = SpriteAnimation.frame(
		character_walk_frames.get("hero", []),
		hero.get("walk_animation", {}), facing, walk_sprite_frame
	)
	if texture != null:
		hero_overlay.texture = texture
		hero_overlay.flip_h = false


func _load_party_atlas() -> void:
	# Images come from a hand-selected, AI-generated art sheet, not drawing code.
	var path: String = "res://assets/party_sheet.b64"
	if not FileAccess.file_exists(path):
		push_warning("Generated party art atlas is absent; old sprites remain available")
		return
	var bytes: PackedByteArray = Marshalls.base64_to_raw(FileAccess.get_file_as_string(path).strip_edges())
	var sheet := Image.new()
	if sheet.load_png_from_buffer(bytes) != OK:
		push_warning("Generated party sprite atlas failed PNG decoding")
		return
	if sheet.get_width() != 160 or sheet.get_height() != 104:
		push_warning("Generated party atlas has unexpected dimensions")
		return
	var ids: Array[String] = ["hero", "ricky", "meri", "goro"]
	for index in range(ids.size()):
		var field_image := sheet.get_region(Rect2i(index * 40, 0, 40, 40))
		var battle_image := sheet.get_region(Rect2i(index * 40, 40, 40, 64))
		textures[ids[index] + "_field"] = ImageTexture.create_from_image(_trim_transparent_padding(field_image))
		textures[ids[index] + "_battle"] = ImageTexture.create_from_image(_trim_transparent_padding(battle_image))

func _panel_style(fill: Color, border: Color = Color("#657da8")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _style_button(button: Button, accent: bool = false) -> void:
	var fill: Color = Color("#36557f") if accent else Color("#1d314e")
	var pressed_fill := Color("#658db9") if accent else Color("#385a82")
	button.add_theme_stylebox_override("normal", _panel_style(fill))
	button.add_theme_stylebox_override("hover", _panel_style(fill.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _panel_style(pressed_fill))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color("#f4eedb"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.focus_mode = Control.FOCUS_NONE

func _setup_music() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -5.0
	music_player.bus = "Master"
	add_child(music_player)
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -4.0
	add_child(sound_player)
	hit_player = AudioStreamPlayer.new()
	hit_player.volume_db = -3.0
	add_child(hit_player)

func _unlock_audio() -> void:
	if audio_unlocked:
		return
	audio_unlocked = true
	if music_on and music_player != null:
		music_player.stop()
		current_music_id = ""
		_play_music("battle" if battle_active else ("cave" if location_id == "cave" else "field"))

func _play_sfx(effect_id: String) -> void:
	_unlock_audio()
	var effect: AudioStream = load("res://audio/" + effect_id + ".wav") as AudioStream
	if effect == null:
		return
	var player: AudioStreamPlayer = hit_player if effect_id == "hit" else sound_player
	player.stream = effect
	player.play()

func _play_music_for_location() -> void:
	_play_music("cave" if location_id == "cave" else "field")

func _play_music(track_id: String) -> void:
	if current_music_id == track_id:
		return
	current_music_id = track_id
	if music_player == null:
		return
	music_player.stop()
	if not music_on:
		return
	var track: AudioStream = load("res://audio/" + track_id + ".wav") as AudioStream
	if track == null:
		push_warning("Missing original BGM: " + track_id)
		return
	if track is AudioStreamWAV:
		track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music_player.stream = track
	music_player.play()

func _audio_diagnostic() -> void:
	# iOS WebAudio requires a user gesture. This handler is activated by tap.
	_unlock_audio()
	music_on = true
	music_toggle_button.text = "音楽 ON"
	current_music_id = ""
	var active_track: String = "battle" if battle_active else ("cave" if location_id == "cave" else "field")
	_play_music(active_track)
	_play_sfx("confirm")
	var available: bool = ResourceLoader.exists("res://audio/" + active_track + ".wav")
	var status: String = "音声ファイルあり" if available else "音声ファイルがない"
	var playback: String = "BGM再生指示済み" if music_player.playing else "BGM再生できず"
	_show_message(status + " ／ " + playback + "。音が出なければiPhoneの消音・音量を確認。")

func _toggle_music() -> void:
	_unlock_audio()
	music_on = not music_on
	music_toggle_button.text = "音楽 ON" if music_on else "音楽 OFF"
	if music_on:
		var restart_id: String = current_music_id
		current_music_id = ""
		_play_music(restart_id if not restart_id.is_empty() else "field")
	elif music_player != null:
		music_player.stop()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0b1426")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	root_column = Control.new()
	root_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_column)

	hud_panel = Panel.new()
	hud_panel.add_theme_stylebox_override("panel", _panel_style(Color("#172744")))
	root_column.add_child(hud_panel)

	hud_title = Label.new()
	hud_title.text = "終わりの地図"
	hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_title.add_theme_font_size_override("font_size", 22)
	hud_panel.add_child(hud_title)

	build_label = Label.new()
	build_label.text = "CAMERA-17"
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_label.add_theme_font_size_override("font_size", 11)
	build_label.add_theme_color_override("font_color", Color("#9fb5d8"))
	hud_panel.add_child(build_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.add_theme_font_size_override("font_size", 15)
	hud_panel.add_child(status_label)
	status_label.position.y = 38
	status_label.size.y = 24

	menu_button = _add_button(hud_panel, "メニュー", _toggle_menu)
	menu_button.add_theme_font_size_override("font_size", 15)
	menu_button.custom_minimum_size = Vector2.ZERO
	menu_button.size = Vector2(90, 45)
	_style_button(menu_button)

	map_frame = Panel.new()
	map_frame.add_theme_stylebox_override("panel", _panel_style(Color("#101f30"), Color("#9caec3")))
	map_frame.clip_contents = true
	root_column.add_child(map_frame)
	map_center = Control.new()
	map_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_center.offset_left = 7
	map_center.offset_top = 7
	map_center.offset_right = -7
	map_center.offset_bottom = -7
	map_center.clip_contents = true
	map_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_frame.add_child(map_center)

	battle_backdrop = Panel.new()
	battle_backdrop.add_theme_stylebox_override("panel", _panel_style(Color("#14233f"), Color("#9caec3")))
	root_column.add_child(battle_backdrop)
	battle_backdrop.visible = false
	map_grid = GridContainer.new()
	map_grid.columns = 10
	map_grid.add_theme_constant_override("h_separation", 0)
	map_grid.add_theme_constant_override("v_separation", 0)
	map_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_center.add_child(map_grid)
	hero_overlay = TextureRect.new()
	hero_overlay.custom_minimum_size = Vector2.ZERO
	hero_overlay.size = SpriteAnimation.field_rect(float(cell_size), _character_profile("hero")).size
	hero_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_overlay.texture = textures.get("hero_field", textures.get("hero"))
	walk_sprite_direction = _face_row(facing)
	_set_hero_walk_frame(1)
	map_frame.add_child(hero_overlay)

	battle_panel = VBoxContainer.new()
	battle_panel.add_theme_constant_override("separation", 22)
	battle_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	root_column.add_child(battle_panel)
	battle_visual = HBoxContainer.new()
	battle_visual.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_visual.add_theme_constant_override("separation", 8)
	battle_panel.add_child(battle_visual)
	battle_enemy_sprite = _battle_portrait("slime")
	battle_enemy_sprite.custom_minimum_size = Vector2(92, 96)
	battle_visual.add_child(battle_enemy_sprite)
	var separator := Label.new()
	separator.text = "VS"
	separator.add_theme_font_size_override("font_size", 15)
	battle_visual.add_child(separator)
	battle_party_visual = GridContainer.new()
	battle_party_visual.columns = 2
	battle_party_visual.add_theme_constant_override("h_separation", 3)
	battle_party_visual.add_theme_constant_override("v_separation", 3)
	battle_visual.add_child(battle_party_visual)
	battle_status = Label.new()
	battle_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_status.add_theme_font_size_override("font_size", 16)
	battle_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_panel.add_child(battle_status)

	dialogue_panel = Panel.new()
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color("#182b4a"), Color("#7e94b8")))
	root_column.add_child(dialogue_panel)
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 17)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_label.offset_left = 13
	message_label.offset_right = -13
	message_label.offset_top = 7
	message_label.offset_bottom = -7
	dialogue_panel.add_child(message_label)

	description_label = Label.new()
	description_label.add_theme_font_size_override("font_size", 14)
	description_label.add_theme_color_override("font_color", Color("#afc6e7"))
	root_column.add_child(description_label)

	action_scroll = ScrollContainer.new()
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	action_scroll.visible = false
	root_column.add_child(action_scroll)
	action_list = VBoxContainer.new()
	action_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_list.add_theme_constant_override("separation", 5)
	action_scroll.add_child(action_list)

	direction_controls = HBoxContainer.new()
	direction_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	direction_controls.add_theme_constant_override("separation", 13)
	root_column.add_child(direction_controls)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 4)
	pad.add_theme_constant_override("v_separation", 4)
	direction_controls.add_child(pad)
	_add_pad_gap(pad)
	_add_direction_button(pad, "▲", Vector2i(0, -1))
	_add_pad_gap(pad)
	_add_direction_button(pad, "◀", Vector2i(-1, 0))
	_add_pad_gap(pad)
	_add_direction_button(pad, "▶", Vector2i(1, 0))
	_add_pad_gap(pad)
	_add_direction_button(pad, "▼", Vector2i(0, 1))
	_add_pad_gap(pad)
	var interact_button := _add_button(direction_controls, "話す\n調べる", _interact)
	interact_button.custom_minimum_size = Vector2(119, 140)
	interact_button.add_theme_font_size_override("font_size", 20)
	_style_button(interact_button, true)

	combat_controls = HBoxContainer.new()
	combat_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	combat_controls.add_theme_constant_override("separation", 7)
	root_column.add_child(combat_controls)
	battle_commands = combat_controls
	for entry in [["攻撃", "attack"], ["技", "skill"], ["防御", "guard"]]:
		var command: String = str(entry[1])
		var combat_button := _add_button(combat_controls, str(entry[0]), func(): _choose_battle(command))
		combat_button.custom_minimum_size = Vector2(145, 85)
		combat_button.add_theme_font_size_override("font_size", 21)
		_style_button(combat_button, true)

	management_panel = HBoxContainer.new()
	management_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	management_panel.add_theme_constant_override("separation", 6)
	root_column.add_child(management_panel)
	for entry in [["編成", Callable(self, "_auto_party")], ["セーブ", Callable(self, "_save")], ["ロード", Callable(self, "_load")], ["周回", Callable(self, "_next_loop")], ["音楽 ON", Callable(self, "_toggle_music")], ["音テスト", Callable(self, "_audio_diagnostic")]]:
		var manage_button := _add_button(management_panel, str(entry[0]), entry[1])
		manage_button.custom_minimum_size = Vector2(115, 64)
		manage_button.add_theme_font_size_override("font_size", 16)
		_style_button(manage_button)
		if str(entry[0]) == "音楽 ON":
			music_toggle_button = manage_button
	management_panel.visible = false

	battle_panel.visible = false
	combat_controls.visible = false
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()

func _layout_ui() -> void:
	if root_column == null:
		return
	var screen: Vector2 = get_viewport_rect().size
	var w: float = screen.x
	var h: float = screen.y
	var margin: float = 12.0
	var header_h: float = clampf(h * 0.075, 65, 78)
	var map_h: float = clampf(h * 0.36, 230, 355)
	var dialogue_h: float = clampf(h * 0.082, 64, 82)
	var actions_h: float = clampf(h * 0.12, 100, 112)
	var bottom_h: float = h - header_h - map_h - dialogue_h - actions_h - 50.0
	# Compact screen fallback: shrink the map before shrinking controls.
	if bottom_h < 214.0:
		map_h = maxf(170.0, map_h - (214.0 - bottom_h))
		bottom_h = h - header_h - map_h - dialogue_h - actions_h - 50.0
	hud_panel.position = Vector2(margin, 5)
	hud_panel.size = Vector2(w - margin * 2.0, header_h)
	menu_button.position = Vector2(hud_panel.size.x - 99.0, 13)
	hud_title.position = Vector2(12, 5)
	hud_title.size = Vector2(hud_panel.size.x - 122.0, 31)
	status_label.position = Vector2(12, 38)
	status_label.size = Vector2(hud_panel.size.x - 122.0, 23)
	build_label.position = Vector2(hud_panel.size.x - 97.0, 2)
	build_label.size = Vector2(75, 15)
	map_frame.position = Vector2(margin, header_h + 11)
	map_frame.size = Vector2(w - margin * 2.0, map_h)
	battle_backdrop.position = map_frame.position
	battle_backdrop.size = map_frame.size
	battle_panel.position = map_frame.position + Vector2(14, 20)
	battle_panel.size = map_frame.size - Vector2(28, 40)
	cell_size = mini(46, mini(int((map_frame.size.x - 22.0) / 10.0), int((map_frame.size.y - 20.0) / 7.0)))
	if hero_overlay != null:
		hero_overlay.size = SpriteAnimation.field_rect(float(cell_size), _character_profile("hero")).size
	description_label.position = Vector2(margin + 3, map_frame.position.y + map_h + 3)
	description_label.size = Vector2(w - margin * 2.0, 21)
	dialogue_panel.position = Vector2(margin, description_label.position.y + 22)
	dialogue_panel.size = Vector2(w - margin * 2.0, dialogue_h)
	action_scroll.position = Vector2(margin, dialogue_panel.position.y + dialogue_h + 5)
	action_scroll.size = Vector2(w - margin * 2.0, actions_h)
	var control_y: float = action_scroll.position.y + actions_h + 5
	var available: float = maxf(170.0, h - control_y - 9)
	var pad_h: float = clampf((available - 10) / 3.0, 59, 81)
	var pad_w: float = clampf((w - 160) / 3.0, 72, 105)
	button_size = Vector2(pad_w, pad_h)
	var pad: GridContainer = direction_controls.get_child(0)
	for child in pad.get_children():
		child.custom_minimum_size = button_size
	var interact: Button = direction_controls.get_child(1)
	interact.custom_minimum_size = Vector2(clampf(w * 0.22, 90, 125), pad_h * 1.7)
	direction_controls.position = Vector2(margin, control_y)
	direction_controls.size = Vector2(w - margin * 2.0, available)
	combat_controls.position = Vector2(margin, control_y + 15)
	combat_controls.size = Vector2(w - margin * 2.0, 95)
	for child in combat_controls.get_children():
		child.custom_minimum_size = Vector2((w - 42) / 3.0, 84)
	management_panel.position = Vector2(margin, header_h + 13)
	management_panel.size = Vector2(w - margin * 2.0, 74)
	for child in management_panel.get_children():
		child.custom_minimum_size = Vector2((w - 58) / 6.0, 63)
	if map_grid.get_child_count() > 0:
		_draw_map()
		call_deferred("_sync_hero_overlay")

func _toggle_menu() -> void:
	_unlock_audio()
	if battle_active:
		return
	management_panel.visible = not management_panel.visible
	menu_button.text = "閉じる" if management_panel.visible else "メニュー"


func _add_pad_gap(parent: GridContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(94, 74)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)

func _add_direction_button(parent: GridContainer, text_value: String, vector: Vector2i) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(94, 74)
	button.add_theme_font_size_override("font_size", 30)
	_style_button(button)
	button.button_down.connect(func(): _begin_hold(vector))
	button.button_up.connect(_end_hold)
	parent.add_child(button)
	return button

func _begin_hold(vector: Vector2i) -> void:
	_unlock_audio()
	held_direction = vector
	repeat_clock = FIRST_REPEAT_DELAY
	_walk(vector.x, vector.y)

func _end_hold() -> void:
	held_direction = Vector2i.ZERO
	repeat_clock = 0.0

func _process(delta: float) -> void:
	# Walk animation advances independently of whether the player keeps a key held.
	if walking:
		walk_elapsed += delta
		_set_hero_walk_frame(SpriteAnimation.step_frame(
			_character_profile("hero").get("walk_animation", {}), walk_elapsed, WALK_DURATION
		))
		return
	if held_direction == Vector2i.ZERO:
		return
	if battle_active or not game.state.get("ending", "").is_empty():
		_end_hold()
		return
	repeat_clock -= delta
	if repeat_clock <= 0.0:
		_walk(held_direction.x, held_direction.y)
		repeat_clock += REPEAT_INTERVAL

func _battle_portrait(image_id: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if textures.has(image_id):
		portrait.texture = textures[image_id]
	return portrait

func _add_button(parent: Node, title: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = title
	_style_button(b)
	b.pressed.connect(callback)
	b.custom_minimum_size.y = 60
	b.add_theme_font_size_override("font_size", 18)
	parent.add_child(b)
	return b

func _map() -> Dictionary:
	return game.registry.by_id("maps", location_id)

func _current_rows() -> Array:
	var data: Dictionary = _map()
	var phase_rows: Dictionary = data.get("phase_rows", {})
	var key: String = str(game.state.get("phase", 1))
	return phase_rows.get(key, data.get("rows", []))

func _current_phase_name() -> String:
	for phase in game.registry.world().get("phases", []):
		if int(phase.get("id", 0)) == int(game.state.get("phase", 1)):
			return str(phase.get("name", ""))
	return ""

func _refresh() -> void:
	if not game.state.get("ending", "").is_empty():
		_show_ending()
	status_label.text = "Day %d　%s　仲間 %d人" % [
		int(game.state.get("day", 0)), _current_phase_name(),
		game.state.get("recruited", []).size()
	]
	var map_data: Dictionary = _map()
	description_label.text = str(map_data.get("name", "")) + ("　｜地面が裂けている…" if int(game.state.get("phase", 1)) >= 3 else "")
	if location_id == "world_map":
		description_label.text = "世界地図　%s　(%d, %d)" % [_current_phase_name(), tile_pos.x, tile_pos.y]
	var nearby: Dictionary = _nearby_point()
	if not nearby.is_empty():
		description_label.text += "　｜近く：" + str(nearby.get("label", ""))
	_draw_map()
	if battle_active:
		_refresh_battle()
	else:
		battle_panel.visible = false
		battle_backdrop.visible = false
		combat_controls.visible = false
		map_frame.visible = true
		action_scroll.visible = pending_choices
		direction_controls.visible = game.state.get("ending", "").is_empty()
		if not direction_controls.visible:
			_end_hold()
		_show_nearby_actions()

func _camera_grid_position(point: Vector2i) -> Vector2:
	var rows: Array = _current_rows()
	if rows.is_empty():
		return Vector2.ZERO
	var width: int = str(rows[0]).length()
	var height: int = rows.size()
	# Follow continuous world coordinates. The edge clamps avoid showing
	# blank areas while allowing centered movement across interior tiles.
	var x_offset: float = clampf(float(point.x) - (float(CAMERA_COLS) - 1.0) / 2.0, 0.0, maxf(0.0, float(width - CAMERA_COLS)))
	var y_offset: float = clampf(float(point.y) - (float(CAMERA_ROWS) - 1.0) / 2.0, 0.0, maxf(0.0, float(height - CAMERA_ROWS)))
	var base: Vector2 = Vector2(
		(map_center.size.x - CAMERA_COLS * float(cell_size)) * 0.5,
		(map_center.size.y - CAMERA_ROWS * float(cell_size)) * 0.5
	)
	return base - Vector2(x_offset, y_offset) * float(cell_size)

func _camera_origin() -> Vector2i:
	var screen: Vector2 = _camera_grid_position(tile_pos)
	var base: Vector2 = Vector2(
		(map_center.size.x - CAMERA_COLS * float(cell_size)) * 0.5,
		(map_center.size.y - CAMERA_ROWS * float(cell_size)) * 0.5
	)
	return Vector2i(roundi((base.x - screen.x) / float(cell_size)), roundi((base.y - screen.y) / float(cell_size)))

func _hero_cell_position(point: Vector2i) -> Vector2:
	return map_center.position + map_grid.position + Vector2(point.x, point.y) * float(cell_size)

func _sync_hero_overlay() -> void:
	if hero_overlay == null or map_grid.get_child_count() == 0 or walking:
		return
	var actor_rect: Rect2 = SpriteAnimation.field_rect(float(cell_size), _character_profile("hero"))
	hero_overlay.size = actor_rect.size
	hero_overlay.position = _hero_cell_position(tile_pos) + actor_rect.position
	walk_sprite_direction = _face_row(facing)
	_set_hero_walk_frame(1)

func _draw_map() -> void:
	var rows: Array = _current_rows()
	if rows.is_empty():
		return
	var phase: int = int(game.state.get("phase", 1))
	var row_width: int = str(rows[0]).length()
	if last_map_scene == location_id and last_map_phase == phase and last_map_cell_size == cell_size and map_grid.get_child_count() == row_width * rows.size():
		return
	last_map_scene = location_id
	last_map_phase = phase
	last_map_cell_size = cell_size
	for item in map_grid.get_children():
		map_grid.remove_child(item)
		item.queue_free()
	map_grid.columns = row_width
	var map_data: Dictionary = _map()
	var is_world: bool = location_id == "world_map"
	var point_art: Dictionary = {}
	var point_markers: Dictionary = {}
	for point in map_data.get("points", []):
		if not _point_visible(point):
			continue
		var spot: Array = point.get("at", [])
		if spot.size() != 2:
			continue
		var key := Vector2i(int(spot[0]), int(spot[1]))
		point_art[key] = str(point.get("image", ""))
		if not str(point.get("marker_text", "")).is_empty():
			point_markers[key] = point
	for y in range(rows.size()):
		for x in range(row_width):
			var cell := TextureRect.new()
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_SCALE
			var symbol: String = str(rows[y]).substr(x, 1)
			var art_id: String = "wall" if symbol == "#" else "ground"
			if textures.has(art_id):
				cell.texture = textures[art_id]
			# Existing generated art with separate location tints; proper
			# terrain art will be created in a later pass.
			if symbol == "p":
				cell.modulate = Color("#caa06c")
			elif symbol == "f":
				cell.modulate = Color("#467a4e")
			elif symbol == "~":
				cell.modulate = Color("#285a97")
			elif symbol == "s":
				cell.modulate = Color("#b7a47a")
			elif symbol == "#" and is_world:
				cell.modulate = Color("#a5a9ac")
			map_grid.add_child(cell)
			var sprite_id: String = "house" if symbol == "H" else str(point_art.get(Vector2i(x, y), ""))
			var marker: Dictionary = point_markers.get(Vector2i(x, y), {})
			if not marker.is_empty():
				var sign_label := Label.new()
				sign_label.text = str(marker.get("marker_text", ""))
				sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				sign_label.add_theme_font_size_override("font_size", 13)
				sign_label.add_theme_color_override("font_color", Color(str(marker.get("marker_color", "#fff4bb"))))
				sign_label.position = Vector2(-4, -16)
				sign_label.custom_minimum_size = Vector2(cell_size + 8, 18)
				sign_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sign_label.z_index = 1
				cell.add_child(sign_label)
			if sprite_id.is_empty():
				continue
			var sprite := TextureRect.new()
			sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if textures.has(sprite_id):
				sprite.texture = textures[sprite_id]
			var sprite_profile: Dictionary = _profile_from_field_sprite(sprite_id)
			if not sprite_profile.is_empty():
				var actor_rect: Rect2 = SpriteAnimation.field_rect(float(cell_size), sprite_profile)
				sprite.position = actor_rect.position
				sprite.size = actor_rect.size
				var idle: Texture2D = SpriteAnimation.frame(
					character_walk_frames.get(str(sprite_profile.get("id", "")), []),
					sprite_profile.get("walk_animation", {}), Vector2i.DOWN,
					int(sprite_profile.get("walk_animation", {}).get("idle_frame", 1))
				)
				if idle != null:
					sprite.texture = idle
			else:
				sprite.size = Vector2(cell_size, cell_size)
			cell.add_child(sprite)
	rendered_tile_count = map_grid.get_child_count()
	map_grid.position = _camera_grid_position(tile_pos)
	if not walking:
		call_deferred("_sync_hero_overlay")

func _point_visible(point: Dictionary) -> bool:
	return game.can(point.get("visible_when", {"always": true}))

func _nearby_point() -> Dictionary:
	var map_data: Dictionary = _map()
	var closest: Dictionary = {}
	var best_priority: int = 100
	var look_at: Vector2i = tile_pos + facing
	for point in map_data.get("points", []):
		if not _point_visible(point):
			continue
		var xy: Array = point.get("at", [])
		if xy.size() < 2:
			continue
		var spot := Vector2i(int(xy[0]), int(xy[1]))
		var distance: int = absi(spot.x - tile_pos.x) + absi(spot.y - tile_pos.y)
		if distance > 1:
			continue
		var priority: int = 0 if spot == look_at else (1 if spot == tile_pos else 2)
		if priority < best_priority:
			closest = point
			best_priority = priority
	return closest

func _show_nearby_actions() -> void:
	for node in action_list.get_children():
		action_list.remove_child(node)
		node.queue_free()
	action_scroll.visible = pending_choices and not battle_active
	if not pending_choices:
		return
	var point: Dictionary = _nearby_point()
	if point.is_empty():
		var empty := Label.new()
		empty.text = "ここには調べられるものがない。"
		action_list.add_child(empty)
		return
	var phase: String = str(game.state.get("phase", 1))
	var dialogue: Dictionary = point.get("dialogue", {})
	_show_message(str(point.get("label", "")) + "「" + str(dialogue.get(phase, "……")) + "」")
	for action in point.get("actions", []):
		var entry: Dictionary = action
		if not game.can(entry.get("when", {"always": true})):
			continue
		var option := _add_button(action_list, str(entry.get("label", "進む")), func(): _perform(entry))
		option.custom_minimum_size.y = 53

func _walk(dx: int, dy: int) -> void:
	if walking or battle_active or not game.state.get("ending", "").is_empty():
		return
	_unlock_audio()
	facing = Vector2i(dx, dy)
	walk_sprite_direction = _face_row(facing)
	if not walking:
		_set_hero_walk_frame(1)
	var goal := tile_pos + facing
	var rows: Array = _current_rows()
	if goal.y < 0 or goal.y >= rows.size() or goal.x < 0 or goal.x >= str(rows[goal.y]).length():
		return
	if str(rows[goal.y]).substr(goal.x, 1) in ["#", "H", "~"]:
		return
	pending_choices = false
	action_scroll.visible = false
	previous_tile_pos = tile_pos
	tile_pos = goal
	walking = true
	walk_elapsed = 0.0
	_set_hero_walk_frame(0)
	if hero_overlay == null:
		walking = false
		_refresh()
		return
	var target_rect: Rect2 = SpriteAnimation.field_rect(float(cell_size), _character_profile("hero"))
	var next_camera_pos: Vector2 = _camera_grid_position(goal)
	var old_camera_pos: Vector2 = map_grid.position
	var finish: Vector2 = map_center.position + next_camera_pos + Vector2(goal.x, goal.y) * float(cell_size) + target_rect.position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(map_grid, "position", next_camera_pos, WALK_DURATION).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(hero_overlay, "position", finish, WALK_DURATION).set_trans(Tween.TRANS_LINEAR)
	tween.set_parallel(false)
	tween.tween_callback(func():
		walking = false
		_set_hero_walk_frame(1)
		_refresh()
		call_deferred("_sync_hero_overlay")
	)

func _interact() -> void:
	if battle_active or walking:
		return
	_play_sfx("confirm")
	pending_choices = not pending_choices
	if pending_choices and _nearby_point().is_empty():
		_show_message("風の音だけが聞こえる。")
	_show_nearby_actions()

func _perform(action: Dictionary) -> void:
	_play_sfx("confirm")
	pending_choices = false
	action_scroll.visible = false
	if not game.state.get("ending", "").is_empty():
		return
	if action.has("event"):
		var event_id: String = str(action["event"])
		if game.run_event(event_id):
			_show_message(str(action.get("success_message", "イベントが進行した：" + event_id)))
		else:
			_show_message(str(action.get("fail_message", "今はそのイベントを進められない。加入条件・時期・編成を確認しよう。")))
	elif action.has("battle"):
		_begin_battle(str(action["battle"]))
	elif action.has("travel_to"):
		_travel(str(action["travel_to"]), action.get("spawn", []))
	elif action.has("message"):
		_show_message(str(action.get("message", "")))
	elif action.has("ending"):
		var ending_id: String = str(action["ending"])
		if game.finish(ending_id):
			_show_message("物語の結末に到達した：" + ending_id)
		else:
			_show_message("結末への条件がまだ揃っていない。")
	_refresh()

func _travel(destination: String, requested_spawn: Array = []) -> void:
	if game.registry.by_id("maps", destination).is_empty():
		return
	if not game.run_event("travel_region"):
		_show_message("移動できない。")
		return
	location_id = destination
	previous_tile_pos = tile_pos
	pending_choices = false
	_play_music_for_location()
	var spawn: Array = requested_spawn if requested_spawn.size() == 2 else _map().get("spawn", [1, 1])
	tile_pos = Vector2i(int(spawn[0]), int(spawn[1]))
	previous_tile_pos = tile_pos
	_show_message(str(_map().get("name", "")) + "に到着。世界が2日進んだ。")

func _auto_party() -> void:
	var roster: Array = game.state.get("recruited", [])
	var selected: Array = []
	for id in roster:
		if selected.size() >= 3:
			break
		selected.append(id)
	if game.set_party(selected):
		_show_message("編成を変更：" + ", ".join(game.state["party"]))
	else:
		_show_message("編成変更に失敗した。")
	_refresh()

func _begin_battle(enemy_id: String) -> void:
	var enemy: Dictionary = {}
	var battle_data: Dictionary = game.registry.collections.get("battles", {})
	for candidate in battle_data.get("enemies", []):
		if candidate.get("id") == enemy_id:
			enemy = candidate
			break
	if enemy.is_empty() or not game.can(enemy.get("when", {"always":false})):
		_show_message("まだ封印は解けていない。世界の変化を待とう。")
		return
	battle.begin(enemy, game.state.get("party", []), game.registry.records("characters"), battle_data)
	if battle.allies.is_empty():
		_show_message("戦闘できる仲間がいない。")
		return
	battle_active = true
	pending_choices = false
	_play_music("battle")
	battle_enemy_id = enemy_id
	battle_enemy_sprite.custom_minimum_size = Vector2(128, 148) if enemy_id == "darklord" else Vector2(92, 96)
	if textures.has(str(enemy.get("image", ""))):
		battle_enemy_sprite.texture = textures[str(enemy.get("image", ""))]
	for child in battle_party_visual.get_children():
		battle_party_visual.remove_child(child)
		child.queue_free()
	for ally in battle.allies:
		var avatar_column := VBoxContainer.new()
		avatar_column.alignment = BoxContainer.ALIGNMENT_CENTER
		avatar_column.custom_minimum_size = Vector2(82, 96)
		var record: Dictionary = game.registry.by_id("characters", str(ally["id"]))
		var battle_art: String = str(record.get("battle_sprite_id", "hero"))
		var avatar := _battle_portrait(battle_art)
		avatar.custom_minimum_size = SpriteAnimation.battle_size(Vector2(80, 76), record)
		avatar_column.add_child(avatar)
		var caption := Label.new()
		caption.text = str(ally["name"])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 12)
		avatar_column.add_child(caption)
		battle_party_visual.add_child(avatar_column)
	_show_message("戦闘開始！ 最大4人で戦う。")
	_refresh()

func _refresh_battle() -> void:
	battle_panel.visible = true
	battle_backdrop.visible = true
	combat_controls.visible = true
	map_frame.visible = false
	action_scroll.visible = false
	direction_controls.visible = false
	management_panel.visible = false
	menu_button.text = "メニュー"
	_end_hold()
	battle_status.text = battle.status_text() + "\nコマンド：" + battle.awaiting_name()
	for button in battle_commands.get_children():
		if button is Button:
			button.disabled = battle.finished

func _play_attack_feedback() -> void:
	# Animation acts on already generated sprites, not painted effects.
	if battle_enemy_sprite == null or not is_instance_valid(battle_enemy_sprite):
		return
	battle_enemy_sprite.modulate = Color(1, 0.48, 0.48)
	var effect := create_tween()
	effect.tween_property(battle_enemy_sprite, "modulate", Color.WHITE, 0.22)

func _choose_battle(action: String) -> void:
	if not battle_active:
		return
	_play_sfx("attack" if action != "guard" else "confirm")
	var result: Dictionary = battle.choose(action)
	if result.get("resolved", false):
		_play_sfx("hit")
		_play_attack_feedback()
	if not result.get("ok", false):
		return
	_show_message(str(result.get("text", "")))
	if result.get("resolved", false) and battle.finished:
		battle_active = false
		_play_music_for_location()
		if battle.won:
			var on_win: String = str(battle.enemy.get("on_win_event", ""))
			if not on_win.is_empty():
				game.run_event(on_win)
				if battle_enemy_id == "darklord":
					game.finish("ED_DARKLORD")
			_show_message("勝利！ " + str(battle.enemy.get("reward", "")))
		else:
			_show_message("全滅。宿屋で目を覚ました。（2日経過）")
			location_id = "field"
			tile_pos = Vector2i(4, 2)
			game.advance_days(2)
	_refresh()

func _save() -> void:
	game.state["scene_map"] = location_id
	game.state["scene_xy"] = [tile_pos.x, tile_pos.y]
	_show_message("セーブ完了。" if game.save_game(1) else "セーブ失敗。")

func _load() -> void:
	pending_choices = false
	walking = false
	if not game.load_game(1):
		_show_message("セーブデータが見つからない。")
		return
	_restore_location()
	battle_active = false
	_play_music_for_location()
	_show_message("ロード完了。")
	_refresh()

func _restore_location() -> void:
	walk_elapsed = 0.0
	walking = false
	var place: String = str(game.state.get("scene_map", "field"))
	if not game.registry.by_id("maps", place).is_empty():
		location_id = place
	var xy: Array = game.state.get("scene_xy", _map().get("spawn", [4, 5]))
	if xy.size() >= 2:
		tile_pos = Vector2i(int(xy[0]), int(xy[1]))

func _next_loop() -> void:
	pending_choices = false
	walking = false
	if not game.begin_next_loop():
		_show_message("エンディング到達後にだけ次周回へ進める。")
		return
	location_id = "field"
	_play_music_for_location()
	var restart_xy: Array = _map().get("spawn", [4, 5])
	tile_pos = Vector2i(int(restart_xy[0]), int(restart_xy[1]))
	battle_active = false
	_show_message("次の旅が始まった。実績だけが残っている。")
	_refresh()

func _show_ending() -> void:
	var id: String = str(game.state.get("ending", ""))
	if id == "ED_BRIDGE":
		_show_message("END：橋の向こう。二つの村に帰る道ができた。")
	elif id == "ED_DARKLORD":
		_show_message("END：魔王討伐。夜明けが世界を照らす。")
	elif id == "ED_END":
		_show_message("END：世界滅亡。終末は静かに訪れた。")

func _show_message(message: String) -> void:
	if message_label != null:
		message_label.text = message

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				_walk(0, -1)
			KEY_DOWN, KEY_S:
				_walk(0, 1)
			KEY_LEFT, KEY_A:
				_walk(-1, 0)
			KEY_RIGHT, KEY_D:
				_walk(1, 0)
