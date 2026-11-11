extends RefCounted
## Declarative JSON condition evaluator. Rejects unknown predicates (fail closed).

func matches(expr: Variant, state: Dictionary, meta: Dictionary = {}) -> bool:
	if typeof(expr) != TYPE_DICTIONARY:
		return false
	var e: Dictionary = expr
	if e.size() != 1:
		return false
	var key: String = str(e.keys()[0])
	var value: Variant = e[key]
	match key:
		"always":
			return value == true
		"all":
			if typeof(value) != TYPE_ARRAY:
				return false
			for child in value:
				if not matches(child, state, meta):
					return false
			return true
		"any":
			if typeof(value) != TYPE_ARRAY or value.is_empty():
				return false
			for child in value:
				if matches(child, state, meta):
					return true
			return false
		"not":
			return not matches(value, state, meta)
		"flag_is":
			return _pair_matches(value, state.get("flags", {}))
		"meta_flag_is":
			return _pair_matches(value, meta.get("flags", {}))
		"recruited":
			return str(value) in state.get("recruited", [])
		"active":
			return str(value) in state.get("party", [])
		"phase_is":
			return state.get("phase", 1) == value
		"phase_gte":
			return state.get("phase", 1) >= value if typeof(value) in [TYPE_INT, TYPE_FLOAT] else false
		"phase_lte":
			return state.get("phase", 1) <= value if typeof(value) == TYPE_INT else false
		"day_gte":
			return state.get("day", 0) >= value if typeof(value) == TYPE_INT else false
		"day_lte":
			return state.get("day", 0) <= value if typeof(value) == TYPE_INT else false
		"storyline_stage_is":
			return _pair_matches(value, state.get("storylines", {}))
		"ending_seen":
			return str(value) in meta.get("endings_seen", [])
		"achievement_unlocked":
			return str(value) in meta.get("achievements", [])
		"loop_count_gte":
			return meta.get("loop_count", 0) >= value if typeof(value) == TYPE_INT else false
		"carryover_has":
			return str(value) in state.get("items", [])
		_:
			push_warning("Unknown condition predicate: " + key)
			return false

func _pair_matches(value: Variant, dictionary: Dictionary) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return false
	return dictionary.get(str(value[0]), null) == value[1]
