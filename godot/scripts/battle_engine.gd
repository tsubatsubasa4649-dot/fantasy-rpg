extends RefCounted
## Turn-based four-hero side-view battle model. No drawing or scene dependencies.
var enemy: Dictionary = {}
var allies: Array[Dictionary] = []
var queued: Array[String] = []
var command_cursor: int = 0
var finished: bool = false
var won: bool = false
var lost: bool = false
var round_number: int = 1

func begin(enemy_record: Dictionary, party_ids: Array, character_records: Array, battle_defs: Dictionary) -> void:
	enemy = enemy_record.duplicate(true)
	enemy["hp"] = int(enemy.get("max_hp", 1))
	allies.clear()
	queued.clear()
	command_cursor = 0
	finished = false
	won = false
	lost = false
	round_number = 1
	for character_id in party_ids:
		var character: Dictionary = {}
		for c in character_records:
			if c.get("id") == character_id:
				character = c
				break
		var stats: Dictionary = {}
		for unit in battle_defs.get("allies", []):
			if unit.get("character_id") == character_id:
				stats = unit
				break
		if character.is_empty() or stats.is_empty():
			continue
		allies.append({
			"id": character_id, "name": str(character.get("name", character_id)),
			"hp": int(stats.get("hp", 25)), "max_hp": int(stats.get("hp", 25)),
			"attack": int(stats.get("attack", 7)), "skill": int(stats.get("skill_damage", 11)),
			"guard": false
		})

func awaiting_name() -> String:
	while command_cursor < allies.size() and allies[command_cursor]["hp"] <= 0:
		command_cursor += 1
	if command_cursor >= allies.size():
		return ""
	return str(allies[command_cursor]["name"])

func choose(action: String) -> Dictionary:
	if finished or not action in ["attack", "skill", "guard"]:
		return {"ok": false, "text": "入力できないコマンド。"}
	var name: String = awaiting_name()
	if name.is_empty():
		return {"ok": false, "text": "入力待ちはない。"}
	queued.append(action)
	command_cursor += 1
	if not awaiting_name().is_empty():
		return {"ok": true, "resolved": false, "text": name + "：" + action + "を予約"}
	return resolve_round()

func resolve_round() -> Dictionary:
	var logs: Array[String] = []
	var action_index: int = 0
	for unit in allies:
		if int(unit["hp"]) <= 0:
			continue
		var action: String = queued[action_index]
		action_index += 1
		if action == "guard":
			unit["guard"] = true
			logs.append(str(unit["name"]) + "は身構えた。")
			continue
		var base_damage: int = int(unit["skill"]) if action == "skill" else int(unit["attack"])
		var damage: int = maxi(1, base_damage - int(enemy.get("defense", 0)))
		enemy["hp"] = maxi(0, int(enemy["hp"]) - damage)
		logs.append("%sの%s！ %dダメージ" % [str(unit["name"]), "技" if action == "skill" else "攻撃", damage])
		if int(enemy["hp"]) <= 0:
			break
	if int(enemy["hp"]) <= 0:
		finished = true
		won = true
		logs.append(str(enemy.get("name", "敵")) + "を倒した！")
	else:
		var target: Dictionary = {}
		for unit in allies:
			if int(unit["hp"]) > 0:
				target = unit
				break
		if not target.is_empty():
			var damage: int = maxi(1, int(enemy.get("attack", 5)) - (6 if bool(target["guard"]) else 0))
			target["hp"] = maxi(0, int(target["hp"]) - damage)
			logs.append("%sの反撃！ %sに%dダメージ" % [str(enemy.get("name")), str(target["name"]), damage])
		var living: int = 0
		for unit in allies:
			if int(unit["hp"]) > 0:
				living += 1
		if living == 0:
			finished = true
			lost = true
			logs.append("全滅した……")
	for unit in allies:
		unit["guard"] = false
	queued.clear()
	command_cursor = 0
	round_number += 1
	return {"ok": true, "resolved": true, "text": "\n".join(logs), "won": won, "lost": lost}

func status_text() -> String:
	var text: String = "%s HP %d/%d\n" % [str(enemy.get("name","敵")), int(enemy.get("hp",0)), int(enemy.get("max_hp",1))]
	for unit in allies:
		text += "%s %d/%d  " % [str(unit["name"]), int(unit["hp"]), int(unit["max_hp"])]
	return text
