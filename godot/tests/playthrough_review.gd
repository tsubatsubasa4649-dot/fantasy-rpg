extends SceneTree
## Automated input-driven exploratory playtest. Screenshots are from real Godot scenes.
## This does not mutate gameplay code or fake event/recruitment progress.
const Scene = preload("res://scenes/vertical_slice.tscn")
var actor
var failures: Array[String] = []
var notes: Array[String] = []
var snap_count: int = 0

func _initialize() -> void:
	call_deferred("_play")

func _record(ok: bool, detail: String) -> void:
	print("PLAYCHECK %s | %s | map=%s pos=%s party=%s day=%s" % [
		"PASS" if ok else "FAIL", detail, actor.location_id,
		str(actor.tile_pos), str(actor.game.active_party()), str(actor.game.state.get("day", "?"))
	])
	if not ok:
		failures.append(detail)

func _snap(title: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var path: String = "res://review-" + title + ".png"
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_record(false, "Screenshot failed: " + title)
		return
	snap_count += 1
	print("PLAYSHOT | ", title, " | ", image.get_width(), "x", image.get_height(), " | ", str(actor.message_label.text).replace("\n", " / "))

func _point_by_id(id: String) -> Dictionary:
	for entry in actor._map().get("points", []):
		if str(entry.get("id", "")) == id:
			return entry
	return {}

func _go_to(id: String) -> bool:
	var point: Dictionary = _point_by_id(id)
	if point.is_empty():
		_record(false, "Point absent: " + id)
		return false
	var at: Array = point.get("at", [])
	var target := Vector2i(int(at[0]), int(at[1]))
	var rows: Array = actor._current_rows()
	var start: Vector2i = actor.tile_pos
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {}
	previous[start] = start
	var finish := Vector2i(-1, -1)
	var head: int = 0
	while head < queue.size():
		var loc: Vector2i = queue[head]
		head += 1
		if absi(loc.x - target.x) + absi(loc.y - target.y) == 1:
			finish = loc
			break
		for step in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var nxt: Vector2i = loc + step
			if nxt.y < 0 or nxt.y >= rows.size() or nxt.x < 0 or nxt.x >= str(rows[nxt.y]).length():
				continue
			if str(rows[nxt.y]).substr(nxt.x, 1) in ["#", "H", "~", "t"] or previous.has(nxt):
				continue
			previous[nxt] = loc
			queue.append(nxt)
	if finish == Vector2i(-1, -1):
		_record(false, "No playable walking path to " + id)
		return false
	var path: Array[Vector2i] = []
	var loc: Vector2i = finish
	while loc != start:
		path.push_front(loc)
		loc = previous[loc]
	for next_step in path:
		if actor.walking:
			await create_timer(0.1).timeout
		var delta: Vector2i = next_step - actor.tile_pos
		actor._walk(delta.x, delta.y)
		if actor.tile_pos != next_step:
			_record(false, "Movement blocked toward " + id + " at " + str(next_step))
			return false
		await create_timer(0.34).timeout
	actor.facing = target - actor.tile_pos
	actor._refresh()
	_record(str(actor._nearby_point().get("id", "")) == id, "Walked by directional controls to " + id + " over " + str(path.size()) + " steps")
	return true

func _talk(action_part: String, screenshot: String = "") -> bool:
	actor._interact()
	if not screenshot.is_empty():
		await _snap(screenshot)
	var matched: Button = null
	var choices: Array[String] = []
	for control in actor.action_list.get_children():
		if control is Button:
			choices.append(control.text)
			if control.text.contains(action_part):
				matched = control
	print("PLAYCHOICES | ", str(actor._nearby_point().get("id", "")), " | ", JSON.stringify(choices))
	if matched == null:
		_record(false, "Missing action containing: " + action_part)
		actor._interact()
		return false
	matched.pressed.emit()
	await process_frame
	print("PLAYACTION | ", action_part, " | ", str(actor.message_label.text).replace("\n", " / "))
	return true

func _play() -> void:
	root.size = Vector2i(450, 900)
	var scene: PackedScene = Scene
	actor = scene.instantiate()
	root.add_child(actor)
	await process_frame
	await process_frame
	await create_timer(0.45).timeout
	_record(actor.location_id == "field" and actor.game.active_party() == ["hero"], "Fresh game starts solo in the village")
	await _snap("01-first-frame")
	actor._toggle_menu()
	_record(actor.party_menu_ui.visible, "Main menu opens from fresh start")
	await _snap("02-first-menu")
	actor._toggle_menu()

	if await _go_to("ricky"):
		if await _talk("夜回り", "03-first-dialogue"):
			_record(bool(actor.game.state["flags"].get("village_helped", false)), "Ricky's night patrol changes quest flag")
		if await _talk("リッキーを誘う"):
			_record(actor.game.active_party().has("ch_ricky"), "Ricky is recruitable from actual conversation")
		await _snap("04-ricky-recruited")

	if await _go_to("meri"):
		if await _talk("森の手がかり"):
			_record(bool(actor.game.state["flags"].get("forest_clue", false)), "Meri's quest changes state")
		if await _talk("メリルを誘う"):
			_record(actor.game.active_party().has("ch_meri"), "Meri joins party from actual conversation")
		await _snap("05-two-companions")

	actor._toggle_menu()
	actor.party_menu_ui.show_formation()
	await _snap("06-formation-recruited")
	actor.party_menu_ui.toggle_member("ch_meri")
	_record(not actor.game.active_party().has("ch_meri"), "Tap sends Meri to reserve")
	actor.party_menu_ui.toggle_member("ch_meri")
	_record(actor.game.active_party().has("ch_meri"), "Tap returns Meri to active group")
	actor.party_menu_ui.back()
	actor.party_menu_ui._command("セーブ")
	_record(actor.message_label.text.contains("セーブ完了"), "Save through real menu command")
	actor.party_menu_ui.close()

	if await _go_to("inn"):
		if await _talk("宿の備蓄", "07-inn-dialogue"):
			_record(actor.game.count_item("healing_herb") == 1, "Inn supplies give a real item")
		if await _talk("一晩休む"):
			_record(int(actor.game.state.get("day", 0)) == 1, "Inn advances a day")

	actor.party_menu_ui.show_home()
	actor.party_menu_ui._command("ロード")
	_record(int(actor.game.state.get("day", 0)) == 0, "Load returns to saved day")
	_record(actor.game.active_party().has("ch_ricky") and actor.game.active_party().has("ch_meri"), "Load restores recruited party")
	actor.party_menu_ui.close()
	await _snap("08-after-load")

	if await _go_to("cave_path"):
		if await _talk("世界地図へ出る"):
			_record(actor.location_id == "world_map", "Village exit actually reaches overworld")
			await _snap("09-world-entry")

	if actor.location_id == "world_map":
		if await _go_to("wind_cave"):
			if await _talk("洞窟に入る"):
				_record(actor.location_id == "cave", "Overworld entry reaches Wind-Howling Cave")
				await _snap("10-cave-entry")

	if actor.location_id == "cave":
		if await _go_to("slime"):
			actor._interact()
			await _snap("11-slime-choice")
			for control in actor.action_list.get_children():
				if control is Button and control.text.contains("スライムと戦う"):
					control.pressed.emit()
					break
			_record(actor.battle_active, "Slime battle starts from cave interaction")
			await _snap("12-battle-command")
			var rounds: int = 0
			while actor.battle_active and rounds < 20:
				actor._choose_battle("attack")
				rounds += 1
				await process_frame
			_record(not actor.battle_active and actor.battle.won, "Battle resolves with selectable attack commands")
			_record(actor.game.count_item("healing_herb") >= 1, "Victory rewards healing herb")
			await _snap("13-battle-result")

	root.size = Vector2i(360, 740)
	await process_frame
	await process_frame
	actor.party_menu_ui.show_home()
	await _snap("14-compact-menu")
	actor.party_menu_ui.show_formation()
	await _snap("15-compact-formation")
	print("PLAYTEST SUMMARY | shots=%d checks_failed=%d failures=%s" % [snap_count, failures.size(), JSON.stringify(failures)])
	# It is exploratory: gameplay findings are captured without hiding screenshots.
	quit(0)
