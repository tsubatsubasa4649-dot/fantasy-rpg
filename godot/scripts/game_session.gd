extends RefCounted
## Domain engine: no scene, sprite or input dependencies.
const ContentRegistry = preload("res://scripts/content_registry.gd")
const ConditionEvaluator = preload("res://scripts/condition_evaluator.gd")
const SaveStore = preload("res://scripts/save_store.gd")

var registry = ContentRegistry.new()
var evaluator = ConditionEvaluator.new()
var saver = SaveStore.new()
var state: Dictionary = {}
var meta: Dictionary = {}

func initialize() -> bool:
	if not registry.load_all():
		for problem in registry.errors:
			push_error(problem)
		return false
	meta = _default_meta()
	new_run()
	return true

func new_run(carryover: Array = []) -> void:
	var safe_items: Array = []
	for item_id in carryover:
		var item: Dictionary = registry.by_id("items", str(item_id))
		if item.get("carryover_allowed", false) and str(item_id) in meta.get("unlocked_carryovers", []):
			if not str(item_id) in safe_items and safe_items.size() < 2:
				safe_items.append(str(item_id))
	state = {
		"day": int(registry.world().get("initial_day", 0)),
		"phase": 1,
		"flags": registry.world().get("initial_flags", {}).duplicate(true),
		"recruited": [],
		"party": [str(registry.world().get("party", {}).get("hero_id", "hero"))],
		"storylines": {},
		"events_completed": [],
		"items": safe_items,
		"ending": "",
		"run_id": str(Time.get_unix_time_from_system()) + "-" + str(randi())
	}

func _default_meta() -> Dictionary:
	return {"schema_version":1, "loop_count":0, "achievements":[], "endings_seen":[], "unlocked_carryovers":[], "flags":{}}

func can(condition: Dictionary) -> bool:
	return evaluator.matches(condition, state, meta)

func can_recruit(character_id: String) -> bool:
	var character: Dictionary = registry.by_id("characters", character_id)
	if character.is_empty() or character.get("is_hero", false):
		return false
	if character_id in state.get("recruited", []):
		return false
	return can(character.get("recruit", {"always":false}))

func active_party() -> Array:
	return state.get("party", []).duplicate()

func set_party(companion_ids: Array) -> bool:
	var allowed: int = int(registry.world().get("party", {}).get("max_size", 4)) - 1
	if companion_ids.size() > allowed:
		return false
	var hero_id: String = str(registry.world().get("party", {}).get("hero_id", "hero"))
	var candidate: Array = [hero_id]
	for companion in companion_ids:
		if typeof(companion) != TYPE_STRING:
			return false
		if companion == hero_id or companion in candidate or not companion in state.get("recruited", []):
			return false
		candidate.append(companion)
	state["party"] = candidate
	return true

func run_event(event_id: String) -> bool:
	if not state.get("ending", "").is_empty():
		return false
	var event: Dictionary = registry.by_id("events", event_id)
	if event.is_empty():
		return false
	if not can(event.get("when", {"always":false})):
		return false
	# Prevalidate all effects before mutating run state.
	for effect in event.get("effects", []):
		if effect.has("recruit"):
			if not can_recruit(str(effect.recruit)):
				return false
		elif effect.has("set_flag"):
			if effect.set_flag.size() != 2:
				return false
		elif effect.has("set_storyline_stage"):
			if effect.set_storyline_stage.size() != 2:
				return false
		else:
			return false
	var cost: Variant = event.get("time_cost", 0)
	var days: int = _cost_days(cost)
	if days < 0:
		return false
	for effect in event.get("effects", []):
		if effect.has("recruit"):
			state["recruited"].append(str(effect.recruit))
		elif effect.has("set_flag"):
			state["flags"][str(effect.set_flag[0])] = effect.set_flag[1]
		elif effect.has("set_storyline_stage"):
			state["storylines"][str(effect.set_storyline_stage[0])] = str(effect.set_storyline_stage[1])
	if not event_id in state["events_completed"]:
		state["events_completed"].append(event_id)
	advance_days(days)
	return true

func advance_days(days: int) -> bool:
	if days < 0 or not state.get("ending", "").is_empty():
		return false
	state["day"] += days
	var next_phase: int = 1
	for phase in registry.world().get("phases", []):
		if state["day"] >= int(phase.get("from_day", 0)):
			next_phase = max(next_phase, int(phase.get("id", 1)))
	state["phase"] = next_phase
	if state["day"] >= int(registry.world().get("deadline_day", 60)):
		state["flags"]["world_expired"] = true
		state["ending"] = str(registry.world().get("deadline_ending_id", "ED_END"))
	return true

func _cost_days(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_STRING:
		return int(registry.world().get("time_costs", {}).get(value, -1))
	return -1

func eligible_endings() -> Array:
	var eligible: Array = []
	for ending in registry.records("endings"):
		if can(ending.get("when", {"always":false})):
			eligible.append(str(ending.id))
	return eligible

func finish(ending_id: String) -> bool:
	if not state.get("ending", "").is_empty() or not ending_id in eligible_endings():
		return false
	state["ending"] = ending_id
	if not ending_id in meta["endings_seen"]:
		meta["endings_seen"].append(ending_id)
	var achievement: String = "ending_" + ending_id
	if not achievement in meta["achievements"]:
		meta["achievements"].append(achievement)
	return true

func unlock_carryover(item_id: String) -> bool:
	var item: Dictionary = registry.by_id("items", item_id)
	if not item.get("carryover_allowed", false):
		return false
	if not item_id in meta["unlocked_carryovers"]:
		meta["unlocked_carryovers"].append(item_id)
	return true

func begin_next_loop(carryover: Array = []) -> bool:
	if state.get("ending", "").is_empty():
		return false
	meta["loop_count"] += 1
	new_run(carryover)
	return true

func save_game(slot: int) -> bool:
	return saver.save_slot(slot, state, meta)

func load_game(slot: int) -> bool:
	var payload: Dictionary = saver.load_slot(slot)
	if payload.is_empty():
		return false
	var loaded_state: Dictionary = payload["state"]
	var loaded_meta: Dictionary = payload["meta"]
	if not _valid_loaded_state(loaded_state):
		return false
	state = loaded_state.duplicate(true)
	meta = loaded_meta.duplicate(true)
	return true

func _valid_loaded_state(candidate: Dictionary) -> bool:
	if typeof(candidate.get("recruited")) != TYPE_ARRAY or typeof(candidate.get("party")) != TYPE_ARRAY:
		return false
	if typeof(candidate.get("flags")) != TYPE_DICTIONARY or typeof(candidate.get("storylines")) != TYPE_DICTIONARY:
		return false
	if typeof(candidate.get("day")) != TYPE_INT or candidate["day"] < 0:
		return false
	if candidate["party"].is_empty() or candidate["party"][0] != str(registry.world().get("party", {}).get("hero_id", "hero")) or candidate["party"].size() > int(registry.world().get("party", {}).get("max_size", 4)):
		return false
	var seen: Dictionary = {}
	for id in candidate["party"]:
		if seen.has(str(id)):
			return false
		seen[str(id)] = true
		if id != str(registry.world().get("party", {}).get("hero_id", "hero")) and not id in candidate["recruited"]:
			return false
	for id in candidate["recruited"]:
		if registry.by_id("characters", str(id)).is_empty():
			return false
	return true
