extends SceneTree
## A genuine landscape 3D render from an isolated 1280x720 Godot viewport.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var view := SubViewport.new()
	view.name = "HD2DReviewViewport"
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var packed: PackedScene = load("res://scenes/hd2d_village.tscn")
	if packed == null:
		push_error("HD2D CAPTURE: Scene failed to load")
		quit(1)
		return
	var village: Node3D = packed.instantiate()
	view.add_child(village)
	await process_frame
	await process_frame
	await create_timer(0.75).timeout
	var image: Image = view.get_texture().get_image()
	if image == null or image.is_empty() or image.get_width() != 1280:
		push_error("HD2D CAPTURE: Expected a real 1280px landscape viewport")
		quit(1)
		return
	if image.save_png("res://hd2d-village-screen.png") != OK:
		push_error("HD2D CAPTURE: Could not write screenshot")
		quit(1)
		return
	print("HD2D CAPTURE: ", image.get_width(), "x", image.get_height())
	quit(0)
