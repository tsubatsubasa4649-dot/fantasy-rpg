extends RefCounted
## Loads content as JSON, validates references and stable IDs before play.
const DATA_PATH := "res://data/"
const FILES := ["world", "characters", "events", "storylines", "endings", "items"]
var collections: Dictionary = {}
var errors: Array[String] = []

func load_all() -> bool:
	collections.clear()
	errors.clear()
	for file_name in FILES:
		var path: String = DATA_PATH + file_name + ".json"
		if not FileAccess.file_exists(path):
			errors.append("Missing file: " + path)
			continue
		var text: String = FileAccess.get_file_as_string(path)
		var parser := JSON.new()
		if parser.parse(text) != OK:
			errors.append(path + ": " + parser.get_error_message())
			continue
		var data: Variant = parser.data
		if typeof(data) != TYPE_DICTIONARY or data.get("schema_version", -1) != 1:
			errors.append("Invalid schema_version: " + path)
			continue
		collections[file_name] = data
	if errors.is_empty():
		_validate_ids()
	return errors.is_empty()

func records(collection: String) -> Array:
	if not collections.has(collection):
		return []
	var value: Variant = collections[collection].get(collection, [])
	return value if typeof(value) == TYPE_ARRAY else []

func by_id(collection: String, item_id: String) -> Dictionary:
	for item in records(collection):
		if typeof(item) == TYPE_DICTIONARY and item.get("id") == item_id:
			return item
	return {}

func world() -> Dictionary:
	return collections.get("world", {})

func _validate_ids() -> void:
	var known: Dictionary = {}
	for collection in ["characters", "events", "storylines", "endings", "items"]:
		var seen: Dictionary = {}
		if not collections[collection].has(collection) or typeof(collections[collection][collection]) != TYPE_ARRAY:
			errors.append("Missing array: " + collection)
			continue
		for item in records(collection):
			if typeof(item) != TYPE_DICTIONARY or str(item.get("id", "")).is_empty():
				errors.append("Missing ID in " + collection)
				continue
			var item_id: String = str(item.id)
			if seen.has(item_id):
				errors.append("Duplicate ID: " + collection + "/" + item_id)
			seen[item_id] = true
		known[collection] = seen
	for event in records("events"):
		for effect in event.get("effects", []):
			if effect.has("recruit") and not known.get("characters", {}).has(str(effect.recruit)):
				errors.append("Unknown recruited character: " + str(effect.recruit))
			if effect.has("set_storyline_stage"):
				var line_id: String = str(effect.set_storyline_stage[0])
				if not known.get("storylines", {}).has(line_id):
					errors.append("Unknown storyline: " + line_id)
	for char in records("characters"):
		if char.has("event_id") and not known.get("events", {}).has(str(char.event_id)):
			errors.append("Unknown character event: " + str(char.event_id))
