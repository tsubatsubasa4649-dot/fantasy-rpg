extends SceneTree
## Real Godot scene smoke test. No screenshots or mock objects stand in for the 3D scene.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS HD2D: ", message)
	else:
		failures += 1
		push_error("FAIL HD2D: " + message)

func _run() -> void:
	root.size = Vector2i(900, 650)
	var packed: PackedScene = load("res://scenes/hd2d_village.tscn")
	check(packed != null, "HD-2D village packed scene loads")
	if packed == null:
		quit(1)
		return
	var village: Node3D = packed.instantiate()
	root.add_child(village)
	await process_frame
	await process_frame
	check(village.hero != null and village.hero is Sprite3D, "Hero is a real 3D pixel-art sprite")
	check(village.hero_frames.size() == 4, "Original hero walk sheet reused with four directions")
	check(village.camera != null and village.camera is Camera3D, "Perspective depth uses a 3D camera")
	check(village.get_node_or_null("SunsetSun") is DirectionalLight3D, "3D village has directional sunset lighting")
	check(village.get_node_or_null("Sunset Inn plaster") is MeshInstance3D, "Inn is 3D geometry, not a backdrop")
	check(village.get_node_or_null("Well roof") is MeshInstance3D, "Well has real 3D geometry")
	check(village.npc_records.size() == 5, "Five distinct image-based village NPCs spawn")
	check(village.blockers.size() >= 5, "Buildings and well block movement")
	check(not village._can_walk(Vector3(8.5, 0.9, -3.0)), "Cannot walk through the inn")
	check(village._can_walk(Vector3(0.0, 0.9, 3.0)), "Village plaza is walkable")
	for group in ["grass", "cobble", "flowers"]:
		check(village.ground_materials.has(group), "Terrain type " + group + " provided")
		if village.ground_materials.has(group):
			check(village.ground_materials[group].albedo_texture != null, "Terrain draws existing authored art: " + group)
	village.hero.position = Vector3(-2.8, 0.94, 3.2)
	check(str(village._nearby_npc().get("name", "")) == "リッキー", "Proximity detects Ricky")
	village._interact()
	check(village.dialogue.text.contains("夜回り"), "Touch/talk interaction shows unique NPC dialogue")
	village._last_facing = Vector2i.RIGHT
	village._set_hero_frame(true)
	check(village.hero.texture != null, "Walking animation changes facing in 3D")
	village.hero.position = Vector3(0, 0.94, 3.3)
	village._update_camera(1.0)
	check(village.camera.is_current(), "HD-2D camera is current")
	print("HD2D CHECKS: ", 18 - failures, " passed, ", failures, " failed")
	village.queue_free()
	quit(1 if failures > 0 else 0)
