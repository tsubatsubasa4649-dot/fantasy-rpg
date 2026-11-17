extends Node3D
## HD-2D Windle Village vertical slice. The world is real 3D geometry;
## all pixel-art textures are cropped from existing authored image assets.
## No pixel art, noise patterns or terrain textures are synthesized in code.
const SpriteAnimation = preload("res://scripts/sprite_animation.gd")
const FONT = preload("res://assets/NotoSansJP.ttf")
const MAP_HALF_X := 14
const MAP_HALF_Z := 12
const WALK_SPEED := 4.0
var hero: Sprite3D
var camera: Camera3D
var hero_frames: Array = []
var hero_anim: Dictionary = {}
var elapsed: float = 0.0
var held_direction := Vector2.ZERO
var npc_records: Array[Dictionary] = []
var blockers: Array[Rect2] = []
var dialogue: Label
var interaction_button: Button
var ground_materials: Dictionary = {}
var heading: Label
var _last_facing := Vector2i.DOWN

func _ready() -> void:
	_build_lighting()
	_build_ground()
	_build_village()
	_build_actors()
	_build_camera()
	_build_hud()
	_update_camera(1.0)
	_update_proximity()
	print("HD2D VILLAGE READY: textured 3D village, sprite actors, mobile controls")

func _mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	return mat

func _box(name: String, at: Vector3, dimensions: Vector3, mat: Material, tilt: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.rotation.z = tilt
	add_child(node)
	return node

func _tile_texture(path: String, tile: Rect2i) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var bytes := Marshalls.base64_to_raw(FileAccess.get_file_as_string(path).strip_edges())
	if image.load_png_from_buffer(bytes) != OK:
		return null
	if tile.end.x > image.get_width() or tile.end.y > image.get_height():
		return null
	return ImageTexture.create_from_image(image.get_region(tile))

func _textured_material(texture: Texture2D, fallback: Color) -> StandardMaterial3D:
	var mat := _mat(fallback)
	if texture != null:
		mat.albedo_texture = texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat

func _build_lighting() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#ef9c74")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f2bf9d")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunsetSun"
	sun.light_color = Color("#ffce84")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-43), deg_to_rad(-35), deg_to_rad(-12))
	add_child(sun)

func _build_ground() -> void:
	_box("Raised earth platform", Vector3(0, -0.45, 0), Vector3(30, 0.9, 26), _mat(Color("#705946")))
	var atlas := "res://assets/village_atlas.b64"
	ground_materials["grass"] = _textured_material(_tile_texture(atlas, Rect2i(0, 0, 16, 16)), Color("#688b53"))
	ground_materials["cobble"] = _textured_material(_tile_texture(atlas, Rect2i(48, 48, 16, 16)), Color("#aa9170"))
	ground_materials["flowers"] = _textured_material(_tile_texture(atlas, Rect2i(0, 16, 16, 16)), Color("#819858"))
	var places: Dictionary = {"grass": [], "cobble": [], "flowers": []}
	for z in range(-MAP_HALF_Z, MAP_HALF_Z):
		for x in range(-MAP_HALF_X, MAP_HALF_X):
			var is_path: bool = abs(x) <= 2 or abs(z) <= 1 or (x * x + (z + 2) * (z + 2)) < 27
			var is_flower: bool = not is_path and ((x < -4 and z > 2 and z < 7) or (x > 4 and z > 2 and z < 5))
			var kind: String = "cobble" if is_path else ("flowers" if is_flower else "grass")
			places[kind].append(Vector3(float(x) + 0.5, 0.016, float(z) + 0.5))
	for kind in places:
		var locations: Array = places[kind]
		var ground := MultiMeshInstance3D.new()
		ground.name = "Author-art terrain: " + kind
		var tile_mesh := PlaneMesh.new()
		tile_mesh.size = Vector2.ONE
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = tile_mesh
		multimesh.instance_count = locations.size()
		for i in range(locations.size()):
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, locations[i]))
		ground.multimesh = multimesh
		ground.material_override = ground_materials[kind]
		add_child(ground)
	# A real height change and steps, not a painted optical illusion.
	_box("Upper terrace", Vector3(-10, 0.26, -8.5), Vector3(7.2, 0.52, 6), _mat(Color("#736956")))
	for i in range(4):
		_box("Stone step %d" % i, Vector3(-6.7 - i * 0.75, 0.04 + i * 0.12, -5.0 - i * 0.4),
			Vector3(2.1, 0.16 + 0.18 * i, 0.85), _mat(Color("#aa9581")))

func _house(name: String, at: Vector3, size: Vector3, inn: bool = false) -> void:
	var walls := _mat(Color("#c0a68b"))
	var timber := _mat(Color("#59402f"))
	var roof := _mat(Color("#7d3d36") if inn else Color("#66514b"))
	var glass := _mat(Color("#ffd38a"), true)
	var base_y: float = 0.0
	_box(name + " plaster", at + Vector3(0, size.y / 2.0 + base_y, 0), size, walls)
	for side in [-1, 1]:
		_box(name + " beam", at + Vector3(side * size.x * 0.47, size.y * 0.5, size.z * 0.51),
			Vector3(0.15, size.y, 0.13), timber)
		_box(name + " window", at + Vector3(side * size.x * 0.27, size.y * 0.59, size.z * 0.505),
			Vector3(0.68, 0.65, 0.08), glass)
		_box(name + " window frame", at + Vector3(side * size.x * 0.27, size.y * 0.59, size.z * 0.55),
			Vector3(0.1, 0.69, 0.08), timber)
	_box(name + " door", at + Vector3(0, size.y * 0.32, size.z * 0.52),
		Vector3(0.88, size.y * 0.64, 0.11), timber)
	for side in [-1, 1]:
		_box(name + " roof slope", at + Vector3(side * size.x * 0.245, size.y + 0.54, 0),
			Vector3(size.x * 0.57, 0.23, size.z + 0.65), roof, deg_to_rad(25 * side))
	_box(name + " chimney", at + Vector3(size.x * 0.3, size.y + 1.15, -size.z * 0.25),
		Vector3(0.42, 1.35, 0.48), _mat(Color("#8c7770")))
	blockers.append(Rect2(Vector2(at.x - size.x / 2, at.z - size.z / 2), Vector2(size.x, size.z)))
	if inn:
		var label := Label3D.new()
		label.text = "宿屋  INN"
		label.font = FONT
		label.font_size = 54
		label.pixel_size = 0.009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("#ffdea1")
		label.position = at + Vector3(0, 2.7, size.z / 2.0 + 0.3)
		add_child(label)

func _tree(at: Vector3, scale_factor: float = 1.0) -> void:
	var wood := _mat(Color("#6a4932"))
	var leaves := _mat(Color("#547145"))
	_box("Tree trunk", at + Vector3(0, 1.3 * scale_factor, 0),
		Vector3(0.44, 2.6, 0.44) * scale_factor, wood)
	var crown := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.5 * scale_factor
	mesh.height = 2.3 * scale_factor
	crown.mesh = mesh
	crown.material_override = leaves
	crown.position = at + Vector3(0, 3.25 * scale_factor, 0)
	add_child(crown)

func _lantern(at: Vector3, lit: bool = true) -> void:
	_box("Lamppost", at + Vector3(0, 1.25, 0), Vector3(0.1, 2.5, 0.1), _mat(Color("#342b25")))
	_box("Lantern", at + Vector3(0, 2.58, 0), Vector3(0.42, 0.5, 0.42), _mat(Color("#ffb958"), true))
	if lit and get_node_or_null("LanternLight") == null:
		var glow := OmniLight3D.new()
		glow.name = "LanternLight"
		glow.position = at + Vector3(0, 2.4, 0)
		glow.light_color = Color("#ffae58")
		glow.light_energy = 0.8
		glow.omni_range = 5
		glow.shadow_enabled = false
		add_child(glow)

func _build_village() -> void:
	_house("Sunset Inn", Vector3(8.5, 0, -3), Vector3(5.6, 3.4, 4.8), true)
	_house("Village cottage north", Vector3(-8.5, 0.52, -8.2), Vector3(4.7, 3.2, 4.0))
	_house("Village cottage west", Vector3(-9, 0, 2.5), Vector3(4.5, 2.9, 4.2))
	_house("Herbalist's cottage", Vector3(8.6, 0, 7), Vector3(4.2, 2.9, 3.7))
	# The well is a 3D cylindrical landmark with a roof and posts.
	var well := MeshInstance3D.new()
	var stone := CylinderMesh.new()
	stone.top_radius = 1.15
	stone.bottom_radius = 1.25
	stone.height = 0.82
	well.mesh = stone
	well.material_override = _mat(Color("#b6a38a"))
	well.position = Vector3(0, 0.44, -2.2)
	add_child(well)
	for side in [-1, 1]:
		_box("Well pillar", Vector3(side * 1.0, 1.45, -2.2),
			Vector3(0.2, 2.2, 0.2), _mat(Color("#70503a")))
	_box("Well roof", Vector3(0, 2.67, -2.2), Vector3(2.85, 0.23, 2.0), _mat(Color("#765346")))
	blockers.append(Rect2(-Vector2.ONE * 1.4 + Vector2(0, -2.2), Vector2(2.8, 2.8)))
	for place in [Vector3(-12, 0, -2), Vector3(12, 0, -8), Vector3(-12, 0, 8),
		Vector3(12, 0, 10), Vector3(-4, 0, -10), Vector3(4, 0, -10)]:
		_tree(place, 0.85)
	for lamp_place in [Vector3(-4, 0, -2), Vector3(4, 0, -2), Vector3(-4, 0, 5), Vector3(4, 0, 5)]:
		_lantern(lamp_place)

func _sprite(texture: Texture2D, at: Vector3, pixel_size: float, shaded: bool = false) -> Sprite3D:
	var actor := Sprite3D.new()
	actor.texture = texture
	actor.pixel_size = pixel_size
	actor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	actor.shaded = shaded
	actor.position = at
	add_child(actor)
	return actor

func _npc_image(index: int) -> Texture2D:
	return _tile_texture("res://assets/npc_idle_atlas.b64", Rect2i(index * 40, 0, 40, 48))

func _add_npc(name: String, pos: Vector3, atlas_index: int, text: String) -> void:
	var npc := _sprite(_npc_image(atlas_index), pos + Vector3(0, 0.8, 0), 0.034)
	npc.name = name
	npc_records.append({"name": name, "position": pos, "dialogue": text, "sprite": npc})

func _build_actors() -> void:
	hero_anim = {
		"type": "sheet", "source": "res://assets/hero_walk.b64",
		"columns": 3, "rows": 4, "frame_width": 48, "frame_height": 56,
		"order": ["down", "left", "right", "up"], "idle_frame": 1
	}
	hero_frames = SpriteAnimation.decode_frames({"walk_animation": hero_anim})
	var first: Texture2D = null
	if hero_frames.size() == 4:
		first = hero_frames[0][1]
	hero = _sprite(first, Vector3(0, 0.94, 3.3), 0.034)
	hero.name = "PlayablePixelHero"
	_add_npc("リッキー", Vector3(-3.5, 0, 3.2), 0, "夜回りの途中なんだ。西の花壇は見たか？")
	_add_npc("メリル", Vector3(-5.4, 0, -2.5), 1, "森の祈りの石に、不思議な紋章が残っていたの。")
	_add_npc("ゴロー", Vector3(3.8, 0, 8.0), 2, "旅に出るなら、準備を怠るなよ。")
	_add_npc("長老", Vector3(5, 0, 0.6), 3, "古井戸には、まだ誰も知らぬ秘密が眠っておる。")
	_add_npc("薬師セナ", Vector3(6, 0, 5.4), 4, "怪我をしたらいつでも来て。薬草を分けるわ。")

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "HD2DObliqueCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.0
	camera.current = true
	add_child(camera)

func _update_camera(delta: float) -> void:
	if camera == null or hero == null:
		return
	var focus: Vector3 = hero.position + Vector3(0, 0.3, -0.5)
	var desired: Vector3 = focus + Vector3(0, 14.5, 15.5)
	camera.global_position = camera.global_position.lerp(desired, clampf(delta * 3.2, 0.0, 1.0))
	camera.look_at(focus, Vector3.UP)

func _panel() -> PanelContainer:
	var box := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.07, 0.08, 0.83)
	bg.border_color = Color("#b78f58")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	bg.content_margin_top = 8
	bg.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", bg)
	return box

func _button(title: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(64, 58)
	button.add_theme_font_size_override("font_size", 22)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button

func _touch_direction(title: String, direction: Vector2, at: Vector2, pad: Control) -> void:
	var b := _button(title, pad)
	b.position = at
	b.button_down.connect(func() -> void: held_direction = direction)
	b.button_up.connect(func() -> void: held_direction = Vector2.ZERO)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_PASS
	var skin := Theme.new()
	skin.default_font = FONT
	skin.default_font_size = 20
	ui.theme = skin
	layer.add_child(ui)

	var top := _panel()
	top.position = Vector2(14, 14)
	top.custom_minimum_size = Vector2(245, 82)
	ui.add_child(top)
	var title := VBoxContainer.new()
	top.add_child(title)
	var game_title := Label.new()
	game_title.text = "終わりの地図"
	game_title.add_theme_font_size_override("font_size", 24)
	title.add_child(game_title)
	var location := Label.new()
	location.text = "ウィンドル村  / HD-2D 試作"
	location.add_theme_font_size_override("font_size", 15)
	title.add_child(location)

	var back := _button("2D版へ戻る", ui)
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -172
	back.offset_right = -14
	back.offset_top = 16
	back.offset_bottom = 70
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/vertical_slice.tscn"))

	var msg_panel := _panel()
	msg_panel.anchor_left = 0.5
	msg_panel.anchor_right = 0.5
	msg_panel.anchor_top = 1
	msg_panel.anchor_bottom = 1
	msg_panel.offset_left = -190
	msg_panel.offset_right = 190
	msg_panel.offset_top = -168
	msg_panel.offset_bottom = -88
	ui.add_child(msg_panel)
	dialogue = Label.new()
	dialogue.text = "夕暮れのウィンドル村。近くの村人に話しかけてみよう。"
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.add_theme_font_size_override("font_size", 16)
	msg_panel.add_child(dialogue)

	var pad := Control.new()
	pad.anchor_top = 1
	pad.anchor_bottom = 1
	pad.offset_left = 12
	pad.offset_right = 222
	pad.offset_top = -228
	pad.offset_bottom = -20
	ui.add_child(pad)
	_touch_direction("▲", Vector2.UP, Vector2(70, 0), pad)
	_touch_direction("◀", Vector2.LEFT, Vector2(0, 68), pad)
	_touch_direction("▶", Vector2.RIGHT, Vector2(140, 68), pad)
	_touch_direction("▼", Vector2.DOWN, Vector2(70, 136), pad)

	interaction_button = _button("話す", ui)
	interaction_button.anchor_left = 1
	interaction_button.anchor_right = 1
	interaction_button.anchor_top = 1
	interaction_button.anchor_bottom = 1
	interaction_button.offset_left = -102
	interaction_button.offset_right = -16
	interaction_button.offset_top = -110
	interaction_button.offset_bottom = -35
	interaction_button.pressed.connect(_interact)

func _can_walk(pos: Vector3) -> bool:
	if pos.x < -13.1 or pos.x > 13.1 or pos.z < -11.1 or pos.z > 11.1:
		return false
	for obstacle in blockers:
		if obstacle.grow(0.35).has_point(Vector2(pos.x, pos.z)):
			return false
	return true

func _process(delta: float) -> void:
	elapsed += delta
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input_direction.x -= 1
	if Input.is_key_pressed(KEY_D): input_direction.x += 1
	if Input.is_key_pressed(KEY_W): input_direction.y -= 1
	if Input.is_key_pressed(KEY_S): input_direction.y += 1
	input_direction = (input_direction + held_direction).limit_length()
	if input_direction.length() > 0.08 and hero != null:
		var displacement := Vector3(input_direction.x, 0, input_direction.y) * WALK_SPEED * delta
		var test_x := hero.position + Vector3(displacement.x, 0, 0)
		if _can_walk(test_x):
			hero.position.x = test_x.x
		var test_z := hero.position + Vector3(0, 0, displacement.z)
		if _can_walk(test_z):
			hero.position.z = test_z.z
		if abs(input_direction.x) > abs(input_direction.y):
			_last_facing = Vector2i.LEFT if input_direction.x < 0 else Vector2i.RIGHT
		else:
			_last_facing = Vector2i.UP if input_direction.y < 0 else Vector2i.DOWN
	_set_hero_frame(input_direction.length() > 0.08)
	_update_camera(delta)
	_update_proximity()

func _set_hero_frame(moving: bool) -> void:
	if hero == null or hero_frames.size() != 4:
		return
	var index: int = int(elapsed * 9.0) % 3 if moving else 1
	hero.texture = SpriteAnimation.frame(hero_frames, hero_anim, _last_facing, index)

func _nearby_npc() -> Dictionary:
	if hero == null:
		return {}
	for record in npc_records:
		var pos: Vector3 = record["position"]
		if hero.position.distance_to(pos + Vector3(0, 0.9, 0)) < 2.3:
			return record
	return {}

func _update_proximity() -> void:
	if interaction_button == null:
		return
	var closest: Dictionary = _nearby_npc()
	interaction_button.disabled = closest.is_empty()
	interaction_button.text = "話す" if closest.is_empty() else "話す\n" + str(closest["name"])

func _interact() -> void:
	var closest: Dictionary = _nearby_npc()
	if closest.is_empty():
		dialogue.text = "近くには話しかけられる人がいない。"
	else:
		dialogue.text = str(closest["name"]) + "「" + str(closest["dialogue"]) + "」"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_interact()
