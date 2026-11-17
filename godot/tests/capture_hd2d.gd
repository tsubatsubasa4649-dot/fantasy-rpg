extends SceneTree
## Screenshot comes from Godot's actual 3D render viewport, not the concept art.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://scenes/hd2d_village.tscn")
	if packed == null:
		push_error("HD2D CAPTURE: Scene failed to load")
		quit(1)
		return
	var village: Node3D = packed.instantiate()
	root.add_child(village)
	await process_frame
	await process_frame
	await create_timer(0.6).timeout
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("HD2D CAPTURE: Empty viewport")
		quit(1)
		return
	if image.save_png("res://hd2d-village-screen.png") != OK:
		push_error("HD2D CAPTURE: Could not write screenshot")
		quit(1)
		return
	print("HD2D CAPTURE: ", image.get_width(), "x", image.get_height())
	quit(0)
