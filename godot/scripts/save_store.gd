extends RefCounted
## Save slots are local to Godot's user:// directory, not the res:// project.
const SAVE_VERSION := 1
const MAX_SLOTS := 5

func save_slot(slot: int, state: Dictionary, meta: Dictionary) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		return false
	var folder_err: int = DirAccess.make_dir_recursive_absolute("user://saves")
	if folder_err != OK:
		return false
	var payload: Dictionary = {
		"schema_version": SAVE_VERSION,
		"state": state.duplicate(true),
		"meta": meta.duplicate(true)
	}
	var destination := "user://saves/slot_%d.json" % slot
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	var backup := destination + ".bak"
	if FileAccess.file_exists(backup):
		if DirAccess.remove_absolute(backup) != OK:
			return false
	if FileAccess.file_exists(destination):
		if DirAccess.rename_absolute(destination, backup) != OK:
			return false
	if DirAccess.rename_absolute(temporary, destination) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, destination)
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return true

func load_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > MAX_SLOTS:
		return {}
	var path := "user://saves/slot_%d.json" % slot
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = json.data
	if payload.get("schema_version", -1) != SAVE_VERSION:
		return {}
	if typeof(payload.get("state")) != TYPE_DICTIONARY or typeof(payload.get("meta")) != TYPE_DICTIONARY:
		return {}
	return payload
