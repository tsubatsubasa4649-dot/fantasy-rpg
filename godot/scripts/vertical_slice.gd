extends Control
## Phase 3 vertical slice. UI controls are native Godot widgets; art is generated PNG data.
const GameSession = preload("res://scripts/game_session.gd")
const BattleEngine = preload("res://scripts/battle_engine.gd")
const TILE_SIZE := 44
const BUILD_ID := "RPG FIX-04 / 2026-11-11"
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
var battle_party_visual: VBoxContainer
var battle_commands: HBoxContainer
var direction_controls: HBoxContainer
var root_column: VBoxContainer
var last_point_id: String = ""
var last_phase: int = 0

func _ready() -> void:
	if not game.initialize():
		var label := Label.new()
		label.text = "DATA ERROR: " + ", ".join(game.registry.errors)
		add_child(label)
		return
	_apply_japanese_font()
	_load_art()
	_build_ui()
	_restore_location()
	_show_message("魔王を倒せ。それだけが、思い出せる使命だった。")
	_refresh()

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
		textures[id] = ImageTexture.create_from_image(image)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#121b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	root_column = VBoxContainer.new()
	root_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_column.add_theme_constant_override("separation", 9)
	add_child(root_column)
	var title := Label.new()
	title.text = "終わりの地図｜Godot 縦切り試作"
	var build_label := Label.new()
	build_label.text = BUILD_ID
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_label.add_theme_font_size_override("font_size", 13)
	root_column.add_child(build_label)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root_column.add_child(title)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	root_column.add_child(status_label)
	description_label = Label.new()
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.add_theme_font_size_override("font_size", 17)
	root_column.add_child(description_label)
	var map_center := CenterContainer.new()
	root_column.add_child(map_center)
	map_grid = GridContainer.new()
	map_grid.columns = 10
	map_grid.add_theme_constant_override("h_separation", 0)
	map_grid.add_theme_constant_override("v_separation", 0)
	map_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_center.add_child(map_grid)
	message_label = Label.new()
	message_label.custom_minimum_size = Vector2(0, 45)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_column.add_child(message_label)
	action_list = VBoxContainer.new()
	root_column.add_child(action_list)
	direction_controls = HBoxContainer.new()
	direction_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	root_column.add_child(direction_controls)
	_add_button(direction_controls, "←", func(): _walk(-1, 0))
	_add_button(direction_controls, "↑", func(): _walk(0, -1))
	_add_button(direction_controls, "↓", func(): _walk(0, 1))
	_add_button(direction_controls, "→", func(): _walk(1, 0))
	_add_button(direction_controls, "調べる", _interact)
	battle_panel = VBoxContainer.new()
	root_column.add_child(battle_panel)
	battle_visual = HBoxContainer.new()
	battle_visual.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_panel.add_child(battle_visual)
	battle_enemy_sprite = _battle_portrait("slime")
	battle_visual.add_child(battle_enemy_sprite)
	var separator := Label.new()
	separator.text = "   VS   "
	battle_visual.add_child(separator)
	battle_party_visual = VBoxContainer.new()
	battle_visual.add_child(battle_party_visual)
	battle_status = Label.new()
	battle_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_panel.add_child(battle_status)
	battle_commands = HBoxContainer.new()
	battle_panel.add_child(battle_commands)
	_add_button(battle_commands, "攻撃", func(): _choose_battle("attack"))
	_add_button(battle_commands, "技", func(): _choose_battle("skill"))
	_add_button(battle_commands, "防御", func(): _choose_battle("guard"))
	var management := HBoxContainer.new()
	management.alignment = BoxContainer.ALIGNMENT_CENTER
	root_column.add_child(management)
	_add_button(management, "編成を整える", _auto_party)
	_add_button(management, "セーブ", _save)
	_add_button(management, "ロード", _load)
	_add_button(management, "次周回", _next_loop)
	battle_panel.visible = false

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
	b.pressed.connect(callback)
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
	status_label.text = "Day %d / %s　仲間 %d人　編成 %s" % [
		int(game.state.get("day", 0)), _current_phase_name(),
		game.state.get("recruited", []).size(), ", ".join(game.state.get("party", []))
	]
	var map_data: Dictionary = _map()
	description_label.text = str(map_data.get("name", "")) + ("　｜地面が裂けている…" if int(game.state.get("phase", 1)) >= 3 else "")
	_draw_map()
	if battle_active:
		_refresh_battle()
	else:
		battle_panel.visible = false
		direction_controls.visible = game.state.get("ending", "").is_empty()
		_show_nearby_actions()

func _draw_map() -> void:
	for item in map_grid.get_children():
		map_grid.remove_child(item)
		item.queue_free()
	var map_data: Dictionary = _map()
	var rows: Array = _current_rows()
	for y in range(rows.size()):
		for x in range(str(rows[y]).length()):
			var cell := TextureRect.new()
			cell.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_SCALE
			var symbol: String = str(rows[y]).substr(x, 1)
			var art_id: String = "wall" if symbol == "#" else "ground"
			if textures.has(art_id):
				cell.texture = textures[art_id]
			map_grid.add_child(cell)
			var sprite_id: String = ""
			if tile_pos == Vector2i(x, y):
				sprite_id = "hero"
			elif symbol == "H":
				sprite_id = "house"
			else:
				for point in map_data.get("points", []):
					if not _point_visible(point):
						continue
					var xy: Array = point.get("at", [])
					if xy.size() == 2 and int(xy[0]) == x and int(xy[1]) == y:
						sprite_id = str(point.get("image", ""))
						break
			if not sprite_id.is_empty():
				var sprite := TextureRect.new()
				sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if textures.has(sprite_id):
					sprite.texture = textures[sprite_id]
				cell.add_child(sprite)

func _point_visible(point: Dictionary) -> bool:
	return game.can(point.get("visible_when", {"always": true}))

func _nearby_point() -> Dictionary:
	var map_data: Dictionary = _map()
	for point in map_data.get("points", []):
		if not _point_visible(point):
			continue
		var xy: Array = point.get("at", [])
		if xy.size() < 2:
			continue
		var distance: int = abs(int(xy[0]) - tile_pos.x) + abs(int(xy[1]) - tile_pos.y)
		if distance <= 1:
			return point
	return {}

func _show_nearby_actions() -> void:
	for node in action_list.get_children():
		action_list.remove_child(node)
		node.queue_free()
	var point: Dictionary = _nearby_point()
	if point.is_empty():
		last_point_id = ""
		_add_button(action_list, "辺りを調べる", _interact)
		return
	var phase: String = str(game.state.get("phase", 1))
	var dialogue: Dictionary = point.get("dialogue", {})
	if last_point_id != str(point.get("id")) or last_phase != int(game.state.get("phase", 1)):
		_show_message(str(point.get("label", "")) + "「" + str(dialogue.get(phase, "……")) + "」")
	last_point_id = str(point.get("id"))
	last_phase = int(game.state.get("phase", 1))
	for action in point.get("actions", []):
		var entry: Dictionary = action
		var label: String = str(entry.get("label", "進む"))
		_add_button(action_list, label, func(): _perform(entry))

func _walk(dx: int, dy: int) -> void:
	if battle_active or not game.state.get("ending", "").is_empty():
		return
	var goal := tile_pos + Vector2i(dx, dy)
	var rows: Array = _current_rows()
	if goal.y < 0 or goal.y >= rows.size() or goal.x < 0 or goal.x >= str(rows[goal.y]).length():
		return
	if str(rows[goal.y]).substr(goal.x, 1) == "#":
		return
	tile_pos = goal
	_refresh()

func _interact() -> void:
	var point := _nearby_point()
	if point.is_empty():
		_show_message("風の音だけが聞こえる。")
		return
	_show_nearby_actions()

func _perform(action: Dictionary) -> void:
	if not game.state.get("ending", "").is_empty():
		return
	if action.has("event"):
		var event_id: String = str(action["event"])
		if game.run_event(event_id):
			_show_message("イベントが進行した：" + event_id)
		else:
			_show_message("今はそのイベントを進められない。加入条件・時期・編成を確認しよう。")
	elif action.has("battle"):
		_begin_battle(str(action["battle"]))
	elif action.has("travel_to"):
		_travel(str(action["travel_to"]))
	elif action.has("ending"):
		var ending_id: String = str(action["ending"])
		if game.finish(ending_id):
			_show_message("物語の結末に到達した：" + ending_id)
		else:
			_show_message("結末への条件がまだ揃っていない。")
	_refresh()

func _travel(destination: String) -> void:
	if game.registry.by_id("maps", destination).is_empty():
		return
	if not game.run_event("travel_region"):
		_show_message("移動できない。")
		return
	location_id = destination
	var spawn: Array = _map().get("spawn", [1, 1])
	tile_pos = Vector2i(int(spawn[0]), int(spawn[1]))
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
	battle_enemy_id = enemy_id
	if textures.has(str(enemy.get("image", ""))):
		battle_enemy_sprite.texture = textures[str(enemy.get("image", ""))]
	for child in battle_party_visual.get_children():
		battle_party_visual.remove_child(child)
		child.queue_free()
	for ally in battle.allies:
		var avatar_line := HBoxContainer.new()
		var avatar := _battle_portrait("hero" if str(ally["id"]) == "hero" else "elder")
		avatar.custom_minimum_size = Vector2(26, 26)
		avatar_line.add_child(avatar)
		var caption := Label.new()
		caption.text = str(ally["name"])
		avatar_line.add_child(caption)
		battle_party_visual.add_child(avatar_line)
	_show_message("戦闘開始！ 最大4人で戦う。")
	_refresh()

func _refresh_battle() -> void:
	battle_panel.visible = true
	direction_controls.visible = false
	battle_status.text = battle.status_text() + "\nコマンド：" + battle.awaiting_name()
	for button in battle_commands.get_children():
		if button is Button:
			button.disabled = battle.finished

func _choose_battle(action: String) -> void:
	if not battle_active:
		return
	var result: Dictionary = battle.choose(action)
	if not result.get("ok", false):
		return
	_show_message(str(result.get("text", "")))
	if result.get("resolved", false) and battle.finished:
		battle_active = false
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
	if not game.load_game(1):
		_show_message("セーブデータが見つからない。")
		return
	_restore_location()
	battle_active = false
	_show_message("ロード完了。")
	_refresh()

func _restore_location() -> void:
	var place: String = str(game.state.get("scene_map", "field"))
	if not game.registry.by_id("maps", place).is_empty():
		location_id = place
	var xy: Array = game.state.get("scene_xy", [1, 4])
	if xy.size() >= 2:
		tile_pos = Vector2i(int(xy[0]), int(xy[1]))

func _next_loop() -> void:
	if not game.begin_next_loop():
		_show_message("エンディング到達後にだけ次周回へ進める。")
		return
	location_id = "field"
	tile_pos = Vector2i(1, 4)
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
