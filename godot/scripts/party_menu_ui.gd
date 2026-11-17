extends Control
## Portrait-driven, touch-friendly JRPG menu. The portraits are source PNG art.
var host: Variant
var page: String = "home"
var panel: Panel
var title_label: Label
var subtitle_label: Label
var back_button: Button
var scroller: ScrollContainer
var content: VBoxContainer
var home_page: VBoxContainer
var formation_page: VBoxContainer
var home_slots: HBoxContainer
var formation_slots: HBoxContainer
var roster_list: VBoxContainer
var formation_status: Label
var notice: Label
var formation_notice: Label
var home_journey: Label
var music_button: Button
const GOLD := Color("#e7c68f")
const CREAM := Color("#f6eedc")
const MUTED := Color("#adc0da")

func attach(owner: Control) -> void:
	host = owner
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("#081120")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", _style(Color("#142543"), GOLD))
	add_child(panel)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 25)
	title_label.add_theme_color_override("font_color", GOLD)
	panel.add_child(title_label)
	back_button = _button(panel, "戻る", Callable(self, "back"))
	back_button.add_theme_font_size_override("font_size", 18)
	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_color_override("font_color", MUTED)
	subtitle_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(subtitle_label)
	scroller = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroller)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	scroller.add_child(content)
	home_page = VBoxContainer.new()
	home_page.add_theme_constant_override("separation", 10)
	content.add_child(home_page)
	_header(home_page, "現在のパーティー")
	home_slots = HBoxContainer.new()
	home_slots.add_theme_constant_override("separation", 5)
	home_page.add_child(home_slots)
	_header(home_page, "コマンド")
	var commands := GridContainer.new()
	commands.columns = 2
	commands.add_theme_constant_override("h_separation", 8)
	commands.add_theme_constant_override("v_separation", 8)
	home_page.add_child(commands)
	for cmd in ["編成", "セーブ", "ロード", "周回", "音楽", "音テスト"]:
		var button := _button(commands, cmd, Callable(self, "_command").bind(cmd))
		button.custom_minimum_size = Vector2(145, 62)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		if cmd == "音楽":
			music_button = button
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", 15)
	notice.add_theme_color_override("font_color", MUTED)
	home_page.add_child(notice)
	_header(home_page, "旅の手がかり")
	var journal := Panel.new()
	journal.custom_minimum_size.y = 105
	journal.add_theme_stylebox_override("panel", _style(Color("#1b3453"), Color("#596f8d")))
	home_page.add_child(journal)
	home_journey = Label.new()
	home_journey.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	home_journey.add_theme_font_size_override("font_size", 15)
	home_journey.add_theme_color_override("font_color", CREAM)
	home_journey.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_journey.offset_left = 11
	home_journey.offset_right = -11
	home_journey.offset_top = 8
	home_journey.offset_bottom = -8
	journal.add_child(home_journey)
	formation_page = VBoxContainer.new()
	formation_page.add_theme_constant_override("separation", 12)
	content.add_child(formation_page)
	formation_status = Label.new()
	formation_status.add_theme_color_override("font_color", GOLD)
	formation_status.add_theme_font_size_override("font_size", 18)
	formation_page.add_child(formation_status)
	formation_slots = HBoxContainer.new()
	formation_slots.add_theme_constant_override("separation", 5)
	formation_page.add_child(formation_slots)
	_header(formation_page, "仲間一覧　・　タップで参加 / 待機")
	roster_list = VBoxContainer.new()
	roster_list.add_theme_constant_override("separation", 8)
	formation_page.add_child(roster_list)
	formation_notice = Label.new()
	formation_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	formation_notice.add_theme_font_size_override("font_size", 15)
	formation_notice.add_theme_color_override("font_color", GOLD)
	formation_page.add_child(formation_notice)
	hide()
	resized.connect(_layout)
	_layout()

func _style(bg: Color, edge: Color = Color("#6d83a3")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(5.0)
	return style

func _button(parent: Node, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_stylebox_override("normal", _style(Color("#243c61")))
	button.add_theme_stylebox_override("hover", _style(Color("#345883"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("#496b95"), GOLD))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", CREAM)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _header(parent: Node, value: String) -> void:
	var heading := Label.new()
	heading.text = value
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", GOLD)
	parent.add_child(heading)

func _layout() -> void:
	if panel == null:
		return
	var screen_size: Vector2 = size
	panel.size = Vector2(minf(screen_size.x - 20.0, 510.0), maxf(300.0, screen_size.y - 22.0))
	panel.position = Vector2(roundf((screen_size.x - panel.size.x) * 0.5), roundf((screen_size.y - panel.size.y) * 0.5))
	title_label.position = Vector2(16, 11)
	title_label.size = Vector2(panel.size.x - 127, 39)
	back_button.position = Vector2(panel.size.x - 108, 11)
	back_button.size = Vector2(91, 46)
	subtitle_label.position = Vector2(16, 60)
	subtitle_label.size = Vector2(panel.size.x - 32, 45)
	scroller.position = Vector2(13, 110)
	scroller.size = Vector2(panel.size.x - 26, panel.size.y - 125)
	content.custom_minimum_size.x = maxf(240.0, scroller.size.x - 10.0)

func show_home() -> void:
	page = "home"
	visible = true
	host.menu_button.text = "閉じる"
	_draw()

func show_formation() -> void:
	page = "formation"
	visible = true
	host.menu_button.text = "閉じる"
	_draw()

func back() -> void:
	if page == "formation":
		show_home()
	else:
		close()

func close() -> void:
	visible = false
	host.menu_button.text = "メニュー"

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _portrait(character_id: String) -> Texture2D:
	var portraits: Dictionary = {
		"hero": "portrait_hero",
		"ch_ricky": "portrait_ricky",
		"ch_meri": "portrait_meri",
		"ch_goro": "portrait_goro"
	}
	return host.textures.get(str(portraits.get(character_id, "")), null)

func _role(character_id: String) -> String:
	match character_id:
		"hero": return "旅人"
		"ch_ricky": return "剣士"
		"ch_meri": return "弓使い"
		"ch_goro": return "守護戦士"
	return "仲間"

func _max_hp(character_id: String) -> int:
	for ally in host.game.registry.collections.get("battles", {}).get("allies", []):
		if str(ally.get("character_id", "")) == character_id:
			return int(ally.get("hp", 1))
	return 1

func _face(parent: Node, character_id: String, location: Vector2, icon_size: Vector2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = _portrait(character_id)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.position = location
	portrait.size = icon_size
	parent.add_child(portrait)
	return portrait

func _slot(parent: HBoxContainer, character_id: String, is_formation: bool) -> void:
	var width: float = maxf(67.0, floorf((panel.size.x - 60.0) / 4.0))
	var button := _button(parent, "", Callable(self, "_slot_action").bind(character_id, is_formation))
	button.custom_minimum_size = Vector2(width, 105)
	button.add_theme_stylebox_override("normal", _style(Color("#283b5a"), GOLD if not character_id.is_empty() else Color("#637087")))
	if character_id.is_empty():
		button.text = "－\n空き"
		button.disabled = true
		return
	_face(button, character_id, Vector2((width - 61) * 0.5, 3), Vector2(61, 65))
	var name_label := Label.new()
	name_label.text = str(host.game.registry.by_id("characters", character_id).get("name", "仲間"))
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.position = Vector2(1, 74)
	name_label.size = Vector2(width - 2, 23)
	button.add_child(name_label)
	if is_formation and character_id == "hero":
		button.disabled = true

func _slot_action(character_id: String, is_formation: bool) -> void:
	if not is_formation:
		show_formation()
	elif character_id != "hero":
		toggle_member(character_id)

func _draw() -> void:
	if panel == null:
		return
	_layout()
	home_page.visible = page == "home"
	formation_page.visible = page == "formation"
	title_label.text = "冒険の手帳" if page == "home" else "パーティ編成"
	back_button.text = "閉じる" if page == "home" else "戻る"
	subtitle_label.text = "現在の仲間と冒険の記録" if page == "home" else "最大4人。主人公は固定、仲間は自由に選択。"
	_clear(home_slots)
	_clear(formation_slots)
	_clear(roster_list)
	var active: Array = host.game.active_party()
	var max_size: int = int(host.game.registry.world().get("party", {}).get("max_size", 4))
	for i in range(max_size):
		var character_id: String = str(active[i]) if i < active.size() else ""
		_slot(home_slots, character_id, false)
		_slot(formation_slots, character_id, true)
	formation_status.text = "戦闘メンバー  %d / %d" % [active.size(), max_size]
	var roster: Array = ["hero"]
	for member in host.game.state.get("recruited", []):
		if not str(member) in roster:
			roster.append(str(member))
	for character_id in roster:
		var id: String = str(character_id)
		var selected: bool = id in active
		var row := _button(roster_list, "", Callable(self, "toggle_member").bind(id))
		row.custom_minimum_size = Vector2(0, 83)
		row.add_theme_stylebox_override("normal", _style(Color("#254467") if selected else Color("#1b2b48"), GOLD if selected else Color("#647b9e")))
		_face(row, id, Vector2(9, 7), Vector2(60, 67))
		var name_label := Label.new()
		name_label.text = str(host.game.registry.by_id("characters", id).get("name", "")) + "  /  " + _role(id)
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.position = Vector2(77, 8)
		name_label.size = Vector2(235, 29)
		row.add_child(name_label)
		var hp: Label = Label.new()
		var maximum: int = _max_hp(id)
		hp.text = "HP  %d / %d" % [host.game.party_health(id, maximum), maximum]
		hp.add_theme_font_size_override("font_size", 14)
		hp.add_theme_color_override("font_color", MUTED)
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp.position = Vector2(78, 45)
		hp.size = Vector2(128, 26)
		row.add_child(hp)
		var badge := Label.new()
		badge.text = "固定" if id == "hero" else ("編成中" if selected else "控え")
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", GOLD if selected else MUTED)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.position = Vector2(210, 47)
		badge.size = Vector2(110, 25)
		row.add_child(badge)
		row.disabled = id == "hero"
	if home_journey != null:
		home_journey.text = "Day %d  /  %s\n\n%s" % [
			int(host.game.state.get("day", 0)),
			str(host._map().get("name", "世界地図")),
			str(host._quest_hint())
		]
	if formation_notice != null:
		formation_notice.text = "明るい枠が編成中の仲間。顔アイコンを押すと切り替えます。"
	if music_button != null:
		music_button.text = "音楽 ON" if host.music_on else "音楽 OFF"
	if roster.size() == 1:
		notice.text = "まずは村でリッキーやメリルに話しかけよう。"
	else:
		notice.text = "編成した仲間は、メニューのセーブで記録できます。"

func toggle_member(character_id: String) -> void:
	if character_id == "hero" or not character_id in host.game.state.get("recruited", []):
		return
	var selected: Array = host.game.active_party().slice(1)
	if character_id in selected:
		selected.erase(character_id)
	else:
		var max_size: int = int(host.game.registry.world().get("party", {}).get("max_size", 4))
		if selected.size() >= max_size - 1:
			formation_notice.text = "最大4人です。先に誰かを控えにしてください。"
			return
		selected.append(character_id)
	if host.game.set_party(selected):
		_draw()
		formation_notice.text = "編成を更新しました。メニューからセーブできます。"

func _command(cmd: String) -> void:
	match cmd:
		"編成":
			show_formation()
			return
		"セーブ": host._save()
		"ロード": host._load()
		"周回": host._next_loop()
		"音楽": host._toggle_music()
		"音テスト": host._audio_diagnostic()
	_draw()
	notice.text = str(host.message_label.text) if cmd != "音楽" else ("音楽が再生中" if host.music_on else "音楽を停止しました")
