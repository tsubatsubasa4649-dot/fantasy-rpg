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
	verify(session.registry.records("maps").size() == 2, "Field + cave")
	var battle_defs: Dictionary = session.registry.collections["battles"]
	verify(battle_defs.get("enemies", []).size() == 2, "Normal enemy + boss")
	verify(session.run_event("help_village"), "Village helper event")
	verify(session.run_event("recruit_ricky"), "Ricky joins")
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
	team.run_event("help_village")
	team.run_event("recruit_ricky")
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
	print("PHASE 3 FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
