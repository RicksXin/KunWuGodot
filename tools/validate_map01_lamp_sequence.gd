extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		quit(1)
		return
	var Lamp = load("res://scripts/prototypes/map01_formation_lamp.gd")
	var instances: Array[AnimatedSprite2D] = []
	for state in ["", "LAMP_REPAIRED", "LAMP_BROKEN"]:
		var lamp: AnimatedSprite2D = Lamp.new()
		lamp.configure(state)
		root.add_child(lamp)
		instances.append(lamp)
	check(instances[0].animation == &"broken" and instances[1].animation == &"active", "state selected before display")
	instances[0].frame = 4
	instances[0].apply_state("")
	check(instances[0].frame == 4,"same state never resets frame")
	instances[0].apply_state("LAMP_REPAIRED")
	check(instances[0].animation == &"repair","repair starts instead of snapping")
	instances[0].frame = 3
	instances[0].apply_state("LAMP_REPAIRED")
	check(instances[0].frame == 3,"state refresh preserves repair progress")
	check(instances[2].animation == &"broken","lamps independent")
	check(instances[0].sprite_frames == instances[1].sprite_frames,"shared resource")
	for state in [&"broken", &"active"]:
		var frames: SpriteFrames = instances[0].sprite_frames
		check(frames.get_frame_count(state)==8 and frames.get_animation_loop(state),"8 frame loop")
		for i in range(8):
			var frame: AtlasTexture = frames.get_frame_texture(state,i)
			check(frame.region == Rect2(i*256,384 if state==&"active" else 0,256,384),"correct frame range")
	check(not Lamp.FRAMES.get_animation_loop(&"repair"),"repair runs once")
	check(Lamp.FRAMES.get_frame_count(&"repair")==16,"repair has 16 frames")
	check(Lamp.FRAMES.get_frame_count(&"repair")/Lamp.FRAMES.get_animation_speed(&"repair")==Lamp.REPAIR_SECONDS,"two second repair")
	instances[0].frame = 0
	await create_timer(0.3).timeout
	check(instances[0].frame != 0,"animation advances")
	check(instances[0].animation == &"repair","still repairing after 0.3 seconds")
	await create_timer(1.85).timeout
	check(instances[0].animation == &"active","repair ends in active loop")
	instances[2].apply_state("LAMP_REPAIRED")
	instances[2].apply_state("")
	check(instances[2].animation == &"broken","reset cancels repair")
	instances[2].configure("LAMP_REPAIRED")
	check(instances[2].animation == &"active","reentry skips transition")
	for lamp in instances: lamp.queue_free()
	print("PASS map01 lamp sequence" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
