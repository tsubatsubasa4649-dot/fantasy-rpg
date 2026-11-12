extends RefCounted
## Shared, data-driven movement art loader and bottom-aligned sprite geometry.
## Artwork is loaded from generated PNGs; no geometry or illustration is drawn.
static func decode_frames(profile: Dictionary) -> Array:
	var spec: Dictionary = profile.get("walk_animation", {})
	if str(spec.get("type", "static")) != "sheet":
		return []
	var source: String = str(spec.get("source", ""))
	if source.is_empty() or not FileAccess.file_exists(source):
		return []
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(FileAccess.get_file_as_string(source).strip_edges())) != OK:
		return []
	var cols: int = int(spec.get("columns", 3))
	var rows: int = int(spec.get("rows", 4))
	var width: int = int(spec.get("frame_width", 48))
	var height: int = int(spec.get("frame_height", 56))
	if cols < 1 or rows < 1 or width < 1 or height < 1:
		return []
	if image.get_width() != cols * width or image.get_height() != rows * height:
		return []
	var atlas: Texture2D = ImageTexture.create_from_image(image)
	var output: Array = []
	for row in range(rows):
		var frames: Array = []
		for col in range(cols):
			var part := AtlasTexture.new()
			part.atlas = atlas
			part.region = Rect2(col * width, row * height, width, height)
			frames.append(part)
		output.append(frames)
	return output

static func direction_row(spec: Dictionary, direction: Vector2i) -> int:
	var name: String = "down"
	if direction.y < 0:
		name = "up"
	elif direction.x < 0:
		name = "left"
	elif direction.x > 0:
		name = "right"
	var order: Array = spec.get("order", ["down", "left", "right", "up"])
	var found: int = order.find(name)
	return maxi(0, found)

static func step_frame(spec: Dictionary, elapsed: float, duration: float) -> int:
	var columns: int = maxi(1, int(spec.get("columns", 3)))
	if duration <= 0.0:
		return int(spec.get("idle_frame", 1))
	return mini(columns - 1, int(clampf(elapsed / duration, 0.0, 0.999) * columns))

static func frame(frames: Array, spec: Dictionary, direction: Vector2i, index: int) -> Texture2D:
	if frames.is_empty():
		return null
	var row: int = direction_row(spec, direction)
	if row >= frames.size() or frames[row].is_empty():
		return null
	return frames[row][clampi(index, 0, frames[row].size() - 1)]

static func visual(profile: Dictionary) -> Dictionary:
	return profile.get("visual", {})

static func field_rect(cell: float, profile: Dictionary) -> Rect2:
	var look: Dictionary = visual(profile)
	var scale: float = clampf(float(look.get("field_scale", 1.0)), 0.65, 1.5)
	var offset_y: float = float(look.get("foot_offset_y", 0.0))
	var size := Vector2(cell * scale, cell * scale)
	return Rect2(Vector2((cell - size.x) / 2.0, cell - size.y + offset_y), size)

static func battle_size(base_size: Vector2, profile: Dictionary) -> Vector2:
	var scale: float = clampf(float(visual(profile).get("battle_scale", 1.0)), 0.75, 1.2)
	return base_size * scale
