@tool
extends Sprite2D
## Keep Sprite2D alpha picking and layout transforms; Godot owns frame timing.
var player: AnimatedSprite2D

func configure(item: Dictionary) -> void:
	if player == null:
		player = AnimatedSprite2D.new()
		player.visible = false
		player.frame_changed.connect(_sync_frame)
		add_child(player)
	player.sprite_frames = load(item.sprite_frames)
	player.play(&"default")
	_sync_frame()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _sync_frame() -> void:
	texture = player.sprite_frames.get_frame_texture(player.animation, player.frame)
