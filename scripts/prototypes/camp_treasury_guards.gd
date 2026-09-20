extends Node3D
## Independent Blender-authored guards; all motion comes from the GLB skeleton clip.
const GUARD_SCENE := preload("res://resources/prototypes/camp_treasury_3d/guard.glb")
const PHASES := [0.0, 3.25]
const RATES := [1.0, 1.0]
var players: Array[AnimationPlayer] = []
var skeletons: Array[Skeleton3D] = []
var guards: Array[Node3D] = []
var clips: Array[StringName] = []
var playing := true

func _ready() -> void:
	for index in range(2):
		var guard := GUARD_SCENE.instantiate() as Node3D
		guard.name = "LeftGuard" if index == 0 else "RightGuard"
		# Clear the central stair and the censer pedestals; ground stays at y=0.
		guard.position = Vector3(-1.62 if index == 0 else 1.62, 0.0, 3.14)
		guard.rotation_degrees.y = 5.0 if index == 0 else -5.0
		add_child(guard)
		guards.append(guard)
		var player := guard.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert(player != null, "Guard GLB must contain the authored AnimationPlayer")
		var clip: StringName = &""
		for candidate in player.get_animation_list():
			if "GuardIdle" in candidate:
				clip = candidate
		assert(not clip.is_empty(), "Missing Blender GuardIdle clip")
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.speed_scale = RATES[index]
		player.play(clip)
		player.seek(PHASES[index], true)
		players.append(player)
		clips.append(clip)
		var found := guard.find_children("*", "Skeleton3D", true, false)
		assert(found.size() == 1)
		skeletons.append(found[0] as Skeleton3D)

func set_playing(enabled: bool) -> void:
	playing = enabled
	for index in range(players.size()):
		if enabled:
			players[index].play(clips[index])
		else:
			players[index].pause()

func seek_preview(seconds: float) -> void:
	# Deterministic capture and validation; does not alter the imported animation.
	set_playing(false)
	for index in range(players.size()):
		players[index].play(clips[index])
		players[index].seek(fposmod(seconds * RATES[index] + PHASES[index], players[index].get_animation(clips[index]).length), true)
		players[index].pause()
