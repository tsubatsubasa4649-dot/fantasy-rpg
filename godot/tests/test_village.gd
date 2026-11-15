extends SceneTree
## Village-24 regression: all locations remain reachable and village services work.
const GameSession = preload("res://scripts/game_session.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS VILLAGE: ", label)
	else:
		failures += 1
		push_error("FAIL VILLAGE: " + label)

func _run() -> void:
	var game = GameSession.new()
	check(game.initialize(), "Game data loads")
	if not game.registry.errors.is_empty():
		quit(1)
		return
	var village: Dictionary = game.registry.by_id("maps", "field")
	var village_start: Array = village.get("spawn", [])
	check(village_start.size() == 2 and int(village_start[0]) == 14 and int(village_start[1]) == 5, "Village starts in central plaza")
	check(village.get("points", []).size() >= 16, "Village has NPCs and discovery points")
	for phase in ["1", "2", "3"]:
		var rows: Array = village.get("rows", []) if phase == "1" else village.get("phase_rows", {}).get(phase, [])
		check(rows.size() == 16, "Phase " + phase + " has 16 rows")
		if rows.size() != 16:
			continue
		var valid_width: bool = true
		for row in rows:
			if str(row).length() != 22:
				valid_width = false
		check(valid_width, "Phase " + phase + " has 22 columns")
		if not valid_width:
			continue
		var start := Vector2i(14, 5)
		var queue: Array[Vector2i] = [start]
		var visited: Dictionary = {}
		visited[start] = true
		var head: int = 0
		while head < queue.size():
			var pos: Vector2i = queue[head]
			head += 1
			for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = pos + step
				if next.x < 0 or next.x >= 22 or next.y < 0 or next.y >= 16:
					continue
				var terrain: String = str(rows[next.y]).substr(next.x, 1)
				if terrain in ["#", "H", "~", "t"] or visited.has(next):
					continue
				visited[next] = true
				queue.append(next)
		for point in village.get("points", []):
			var xy: Array = point.get("at", [])
			if xy.size() < 2:
				check(false, "Point has coordinates: " + str(point.get("id", "")))
				continue
			var spot := Vector2i(int(xy[0]), int(xy[1]))
			var adjacent: bool = visited.has(spot)
			for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				adjacent = adjacent or visited.has(spot + step)
			check(adjacent, "Phase " + phase + " can reach " + str(point.get("id", "")))
	var world: Dictionary = game.registry.by_id("maps", "world_map")
	for point in world.get("points", []):
		if point.get("id") == "home_village":
			for action in point.get("actions", []):
				if action.get("travel_to") == "field":
					var arrive: Array = action.get("spawn", [])
					check(arrive.size() == 2 and int(arrive[0]) == 14 and int(arrive[1]) == 5, "World-to-village entrance uses updated spawn")
	check(game.run_event("read_village_sign"), "Village information board can be read")
	check(game.run_event("discover_well_emblem"), "Village well discovery can be completed")
	check(game.run_event("help_herbalist"), "Herbalist quest can be completed")
	check(not game.run_event("help_herbalist"), "Herbalist quest cannot be farmed")
	check(game.run_event("ask_inn_supplies"), "Inn gives one-time supplies")
	check(not game.run_event("ask_inn_supplies"), "Inn supplies cannot be duplicated")
	game.remember_party_health([{"id": "hero", "hp": 9}])
	check(game.party_health("hero", 42) == 9, "Damaged HP is retained")
	var initial_day: int = int(game.state["day"])
	check(game.run_event("rest_at_inn"), "Inn rest event succeeds")
	game.restore_party_health()
	check(game.party_health("hero", 42) == 42, "Inn rest restores HP")
	check(int(game.state["day"]) == initial_day + 1, "Inn rest advances one day")
	print("VILLAGE FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
