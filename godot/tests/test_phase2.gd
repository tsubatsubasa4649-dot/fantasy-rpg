extends SceneTree
## Execute: godot --headless --path godot --script res://tests/test_phase2.gd
const GameSession = preload("res://scripts/game_session.gd")
const ConditionEvaluator = preload("res://scripts/condition_evaluator.gd")
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	if not value:
		failed += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func _run() -> void:
	var game = GameSession.new()
	check(game.initialize(), "Content files load and IDs validate")
	if game.registry.errors.size() > 0:
		quit(1)
		return
	var e = ConditionEvaluator.new()
	check(not e.matches({"unknown":true}, game.state, game.meta), "Unknown predicate fails closed")
	check(not e.matches({"any":[]}, game.state, game.meta), "Empty any is false")
	check(not e.matches({"not":{"always":true}}, game.state, game.meta), "NOT evaluates")
	check(game.run_event("help_village"), "Complete village help")
	check(game.can_recruit("ch_ricky"), "Ricky can join")
	check(game.run_event("recruit_ricky"), "Recruit Ricky")
	check(game.run_event("find_forest_clue"), "Discover forest clue in phase 1")
	check(game.run_event("recruit_meri"), "Recruit phase-1-only Meri")
	check(not game.run_event("recruit_meri"), "No duplicate recruitment")
	check(game.set_party(["ch_ricky", "ch_meri"]), "Compose active party")
	check(not game.set_party(["ch_ricky", "ch_meri", "ch_goro", "ch_z"]), "Max 3 companions enforced")
	check(not game.set_party(["ch_goro"]), "Cannot deploy unjoined companion")
	check(game.run_event("travel_region"), "Travel costs 2 days")
	check(game.state["day"] == 2, "World clock charged exactly once")
	check(game.advance_days(18), "Advance to phase 2")
	check(game.state["phase"] == 2, "Phase 2 starts at day 20")
	check(not game.can_recruit("ch_meri") or "ch_meri" in game.state["recruited"], "Meri already recruited")
	check(game.run_event("save_refugees"), "Rescue refugees")
	check(game.run_event("recruit_goro"), "Goro recruited in phase 2")
	check(game.run_event("bridge_investigate"), "Storyline starts with two recruited companions")
	check(game.run_event("bridge_resolution"), "One active companion enables resolution")
	check("ED_BRIDGE" in game.eligible_endings(), "Bridge ending unlocked declaratively")
	check(game.save_game(1), "Save slot written")
	var restored = GameSession.new()
	check(restored.initialize(), "Initialize second session")
	check(restored.load_game(1), "Load slot")
	check(restored.state["day"] == 20, "Saved time roundtrips")
	check(restored.finish("ED_BRIDGE"), "End storyline run")
	check(not restored.finish("ED_DARKLORD"), "Cannot finish a run twice")
	check(restored.unlock_carryover("rusted_key"), "Unlock allowed carryover")
	check(not restored.unlock_carryover("healing_herb"), "Ordinary items forbidden")
	check(restored.begin_next_loop(["rusted_key", "healing_herb"]), "Begin next loop")
	check(restored.meta["loop_count"] == 1, "Loop count persists")
	check(restored.state["items"] == ["rusted_key"], "Only approved carryover passes")
	check(restored.state["day"] == 0 and restored.state["recruited"].is_empty(), "Run state reset")
	check("ED_BRIDGE" in restored.meta["endings_seen"], "Ending achievement retained")
	# Test an independent path where Meri is missed.
	var missed = GameSession.new()
	check(missed.initialize(), "New independent run")
	missed.advance_days(20)
	missed.run_event("find_forest_clue")  # Must fail outside phase 1.
	check(not missed.run_event("recruit_meri"), "Phase-limited recruitment expires")
	missed.advance_days(25)
	check(missed.state["phase"] == 3, "Phase 3 begins at day 45")
	check(missed.run_event("defeat_darklord"), "Defeat boss event condition")
	check(missed.finish("ED_DARKLORD"), "Boss ending is reachable")
	print("Phase 2 test failures: ", failed)
	quit(0 if failed == 0 else 1)
