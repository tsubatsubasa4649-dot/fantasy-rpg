extends SceneTree
## Capture the actual running Godot village scene in a software-rendered Xvfb display.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(450, 900)
	var scene: PackedScene = load("res://scenes/vertical_slice.tscn")
	if scene == null:
		push_error("SCREENSHOT: scene could not load")
		quit(1)
		return
	var game: Control = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.45).timeout
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("SCREENSHOT: viewport returned no image")
		quit(1)
		return
	var error: int = image.save_png("res://village-screen.png")
	if error != OK:
		push_error("SCREENSHOT: save failed " + str(error))
		quit(1)
		return
	print("SCREENSHOT SAVED: ", image.get_width(), "x", image.get_height())
	quit(0)
