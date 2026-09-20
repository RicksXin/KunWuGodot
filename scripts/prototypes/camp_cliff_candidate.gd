extends RefCounted
## Development review only: optional, unapproved candidate files. No export/game dependency.
const ROOT := "res://art/candidates/camp-cliff-tiles/gpt-v1/"
static var textures: Dictionary = {}

static func available() -> bool:
	return FileAccess.file_exists(ROOT+"wall-a-compiled.png") and FileAccess.file_exists(ROOT+"wall-b-compiled.png")

static func wall(parent: Node2D, a: Vector2, b: Vector2, height: float) -> void:
	var orientation := "a" if b.x > a.x else "b"
	if not textures.has(orientation):
		var picture := Image.load_from_file(ProjectSettings.globalize_path(ROOT+"wall-"+orientation+"-compiled.png"))
		assert(picture != null and picture.get_size() == Vector2i(144,128))
		textures[orientation] = ImageTexture.create_from_image(picture)
	var count := roundi(absf(b.x-a.x)/64.0)
	assert(count > 0 and is_equal_approx(absf(b.y-a.y),count*32.0))
	var step := (b-a)/count
	for segment in range(count):
		for level in range(ceili(height/48.0)):
			var remaining := minf(48,height-level*48)
			var start := a+step*segment+Vector2(0,level*48)
			var finish := start+step
			var shape := Polygon2D.new()
			shape.name = "CandidateWall_%s_%d_%d" % [orientation,segment,level]
			shape.texture = textures[orientation]
			shape.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			shape.polygon = PackedVector2Array([start,finish,finish+Vector2(0,remaining),start+Vector2(0,remaining)])
			var uv_start := Vector2(8,40) if orientation == "a" else Vector2(136,40)
			var uv_finish := Vector2(72,72)
			shape.uv = PackedVector2Array([uv_start,uv_finish,uv_finish+Vector2(0,remaining),uv_start+Vector2(0,remaining)])
			# Partial 22px display bases are clipped in face coordinates, never stretched.
			shape.set_meta("cliff_height",remaining)
			shape.set_meta("orientation",orientation)
			parent.add_child(shape)
