@tool
extends Node2D
## A screen-wide horizontal bank of mist, vertically anchored to the camp's cliff foot.
const FRAMES = preload("res://resources/prototypes/camp_mist_sequence/frames.tres")
var player: AnimatedSprite2D
func _ready() -> void:
	name = "MountainFootMist"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	player = AnimatedSprite2D.new()
	player.sprite_frames = FRAMES
	player.visible = false
	add_child(player)
	player.play()
	player.frame_changed.connect(queue_redraw)

func _process(_delta: float) -> void:
	queue_redraw()

func band_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var centre := get_global_transform_with_canvas()*Vector2(0,900)
	var feather_height := maxf(viewport_size.y*0.40,absf(get_global_transform_with_canvas().get_scale().y)*440.0)
	# Follow the cliff within a bounded lower-screen region. The dense foot always
	# extends beyond the viewport, even after dragging or zooming the map.
	var top := clampf(centre.y-feather_height*0.5,viewport_size.y*0.52,viewport_size.y*0.72)
	return Rect2(0,top,viewport_size.x,viewport_size.y-top+32.0)

func _draw() -> void:
	if player == null: return
	var band := band_rect()
	var frame := FRAMES.get_frame_texture(&"default",player.frame)
	# Cancel map pan/scale for horizontal coverage: every viewport pixel stays covered.
	draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse())
	var tile_width := 768.0
	for column in range(ceili(band.size.x/tile_width)):
		draw_texture_rect(frame,Rect2(column*tile_width,band.position.y,tile_width,band.size.y),false)
