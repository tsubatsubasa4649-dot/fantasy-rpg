extends Control
## Phase 2 only: diagnostic scene. No map or combat yet.
const GameSession = preload("res://scripts/game_session.gd")
var game = GameSession.new()

func _ready() -> void:
	if game.initialize():
		$Message.text = "PHASE 2 DATA FOUNDATION\nLoaded: %d characters, %d events, %d storylines, %d endings\nDay: %d / Phase: %d\nRun tests: godot --headless --path godot --script res://tests/test_phase2.gd" % [
			game.registry.records("characters").size(),
			game.registry.records("events").size(),
			game.registry.records("storylines").size(),
			game.registry.records("endings").size(),
			game.state["day"], game.state["phase"]
		]
	else:
		$Message.text = "Data load failed:\n" + "\n".join(game.registry.errors)
