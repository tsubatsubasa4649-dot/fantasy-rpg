extends SceneTree
## Run: godot --headless --path godot --script res://tests/test_phase3.gd
const GameSession = preload("res://scripts/game_session.gd")
const BattleEngine = preload("res://scripts/battle_engine.gd")
var failures := 0

func verify(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var session = GameSession.new()
	verify(session.initialize(), "Content registry validates maps and sample assets")
	if session.registry.errors.size() > 0:
		quit(1)
		return
	verify(session.registry.records("maps").size() == 3, "Village, overworld, and cave all load")
	var village: Dictionary = session.registry.by_id("maps", "field")
	verify(village.get("rows", []).size() == 16, "Windle village has 16 rows")
	verify(str(village.get("rows", [""])[0]).length() == 22, "Windle village is 22 tiles wide")
	verify(village.get("points", []).size() >= 16, "Windle village has populated NPCs and locations")
	for phase in ["2", "3"]:
		verify(village.get("phase_rows", {}).get(phase, []).size() == 16, "Windle phase " + phase + " preserves size")
	var world_map: Dictionary = session.registry.by_id("maps", "world_map")
	verify(world_map.get("rows", []).size() == 24, "Overworld is twenty-four rows tall")
	verify(str(world_map.get("rows", [""])[0]).length() == 40, "Overworld is forty tiles wide")
	verify(world_map.get("points", []).size() >= 6, "Overworld has discoverable destinations")
	var terrain: String = ""
	for terrain_row in world_map.get("rows", []):
		terrain += str(terrain_row)
	verify(terrain.contains("~"), "World has impassable coastline")
	verify(terrain.contains("f"), "World has forest regions")
	verify(terrain.contains("p"), "World has branching roads")
	var battle_defs: Dictionary = session.registry.collections["battles"]
	verify(battle_defs.get("enemies", []).size() == 2, "Normal enemy + boss")
	verify(not session.run_event("help_village"), "Cannot bypass village patrol")
	verify(session.run_event("start_village_patrol"), "Start village patrol")
	verify(session.run_event("patrol_check_flowers"), "Visit flowerbed checkpoint")
	verify(session.run_event("patrol_check_well"), "Visit old well checkpoint")
	verify(session.run_event("help_village"), "Village patrol reported")
	verify(session.run_event("recruit_ricky"), "Ricky joins")
	verify(session.run_event("start_forest_search"), "Start Meri search")
	verify(session.run_event("find_forest_traces"), "Search old shrine")
	verify(session.run_event("find_forest_clue"), "Forest clue is phase-limited")
	verify(session.run_event("recruit_meri"), "Meri joins in phase 1")
	session.advance_days(20)
	verify(session.run_event("save_refugees"), "Refugee rescue phase 2")
	verify(session.run_event("recruit_goro"), "Goro joins")
	verify(session.set_party(["ch_ricky", "ch_meri", "ch_goro"]), "Four member party")
	verify(session.run_event("bridge_investigate"), "Storyline investigation")
	verify(session.run_event("bridge_resolution"), "Storyline resolves")
	verify(session.finish("ED_BRIDGE"), "Bridge ending can be completed")
	verify(session.meta["endings_seen"].has("ED_BRIDGE"), "End remembered")
	verify(session.begin_next_loop(), "New loop starts")
	verify(session.state["phase"] == 1, "World reverts to phase 1")
	session.advance_days(45)
	verify(session.state["phase"] == 3, "Final phase reached")
	var boss: Dictionary = {}
	for e in battle_defs["enemies"]:
		if e["id"] == "darklord":
			boss = e
	var fight = BattleEngine.new()
	fight.begin(boss, session.state["party"], session.registry.records("characters"), battle_defs)
	verify(fight.allies.size() == 1, "Solo is supported")
	for round_index in range(30):
		if fight.finished:
			break
		fight.choose("skill")
	verify(fight.finished, "Battle eventually resolves")
	# A full party should win the boss encounter.
	var team = GameSession.new()
	verify(team.initialize(), "Independent combat session")
	team.run_event("start_village_patrol")
	team.run_event("patrol_check_flowers")
	team.run_event("patrol_check_well")
	team.run_event("help_village")
	team.run_event("recruit_ricky")
	team.run_event("start_forest_search")
	team.run_event("find_forest_traces")
	team.run_event("find_forest_clue")
	team.run_event("recruit_meri")
	team.advance_days(20)
	team.run_event("save_refugees")
	team.run_event("recruit_goro")
	team.set_party(["ch_ricky", "ch_meri", "ch_goro"])
	team.advance_days(25)
	var team_fight = BattleEngine.new()
	team_fight.begin(boss, team.state["party"], team.registry.records("characters"), battle_defs)
	for i in range(40):
		if team_fight.finished:
			break
		team_fight.choose("skill")
	verify(team_fight.won, "Four-member party wins boss")
	verify(team.run_event("defeat_darklord"), "Winning battle sets data flag")
	verify(team.finish("ED_DARKLORD"), "Darklord ending completes")
	var herb_session = GameSession.new()
	verify(herb_session.initialize(), "Independent item session")
	verify(herb_session.grant_item("healing_herb"), "Slime reward enters inventory")
	verify(herb_session.count_item("healing_herb") == 1, "Herbs counted correctly")
	herb_session.remember_party_health([{"id": "hero", "hp": 12}])
	verify(herb_session.party_health("hero", 42) == 12, "Damage persists between battles")
	herb_session.restore_party_health()
	verify(herb_session.party_health("hero", 42) == 42, "Rest fully restores party HP")
	verify(herb_session.run_event("help_herbalist"), "Herbalist quest can be completed")
	verify(not herb_session.run_event("help_herbalist"), "Herbalist reward is one-time")
	verify(herb_session.run_event("hear_elder_warning"), "Elder dialogue quest progresses")
	verify(herb_session.run_event("ask_inn_supplies"), "Inn has first-visit supplies")
	var slime: Dictionary = {}
	for enemy_record in battle_defs["enemies"]:
		if enemy_record["id"] == "slime":
			slime = enemy_record
	var herb_fight = BattleEngine.new()
	herb_fight.begin(slime, herb_session.active_party(), herb_session.registry.records("characters"), battle_defs, herb_session.count_item("healing_herb"))
	verify(not herb_fight.choose("herb").get("ok", false), "Cannot waste herbs at full HP")
	herb_fight.choose("guard")
	var herb_result: Dictionary = herb_fight.choose("herb")
	verify(herb_result.get("ok", false) and herb_result.get("herbs_used", 0) == 1, "Herb heals damaged ally")
	verify(herb_fight.herbs_available == 0, "Battle herb stock depleted")
	verify(herb_session.consume_item("healing_herb"), "Herb is consumed")
	verify(herb_session.count_item("healing_herb") == 0 and not herb_session.consume_item("healing_herb"), "Used herb cannot be reused")
	print("PHASE 3 FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
