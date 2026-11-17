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
	# Move to the central plaza and capture the well, dialogue landmarks and stalls.
	game.tile_pos = Vector2i(10, 8)
	game._refresh()
	game.map_grid.position = game._camera_grid_position(game.tile_pos)
	game.props_overlay.position = game.map_grid.position
	game._sync_hero_overlay()
	await process_frame
	await process_frame
	var plaza_image: Image = root.get_texture().get_image()
	if plaza_image == null or plaza_image.is_empty() or plaza_image.save_png("res://village-plaza-screen.png") != OK:
		push_error("SCREENSHOT: plaza save failed")
		quit(1)
		return
	print("PLAZA SCREENSHOT SAVED")
	# Two review captures ensure the non-recruitable elder and herbalist
	# receive their own sprites, not the previously shared party artwork.
	game.tile_pos = Vector2i(6, 7)
	game._refresh()
	game.map_grid.position = game._camera_grid_position(game.tile_pos)
	game.props_overlay.position = game.map_grid.position
	game._sync_hero_overlay()
	await process_frame
	await process_frame
	if root.get_texture().get_image().save_png("res://village-west-screen.png") != OK:
		push_error("SCREENSHOT: west village save failed")
		quit(1)
		return
	print("WEST VILLAGE SCREENSHOT SAVED")
	# Screenshot the actual menu with four recruited portraits.
	game.game.state["recruited"] = ["ch_ricky", "ch_meri", "ch_goro"]
	game.game.set_party(["ch_ricky", "ch_meri", "ch_goro"])
	game.party_menu_ui.show_home()
	await process_frame
	await process_frame
	if root.get_texture().get_image().save_png("res://rpg-menu-screen.png") != OK:
		push_error("SCREENSHOT: menu screenshot failed")
		quit(1)
		return
	game.party_menu_ui.show_formation()
	await process_frame
	await process_frame
	if root.get_texture().get_image().save_png("res://rpg-formation-screen.png") != OK:
		push_error("SCREENSHOT: formation screenshot failed")
		quit(1)
		return
	print("MENU AND FORMATION SCREENSHOTS SAVED")
	quit(0)
