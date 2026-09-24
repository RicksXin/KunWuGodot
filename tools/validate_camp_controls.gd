extends SceneTree
func _initialize(): call_deferred("run")
func run():
 assert(OS.get_cmdline_user_args().has("--no-profile-write"))
 var camp=load("res://scenes/camp.tscn").instantiate()
 root.add_child(camp)
 await process_frame
 camp.set_process(false)
 camp.camp_world.set_process(false)
 camp.camp_world.npcs.set_process(false)
 var graph: AStar2D=camp.camp_world.graph
 var node: int=camp.camp_world.current
 var start: Vector2=graph.get_point_position(node)
 camp.camp_world.actor.position=start
 camp.keyboard_walk(Vector2.RIGHT,0.05)
 var cardinal: float=camp.camp_world.actor.position.distance_to(start)
 camp.camp_world.actor.position=start
 camp.camp_world.current=node
 camp.keyboard_walk(Vector2(1,1),0.05)
 assert(is_equal_approx(cardinal,camp.camp_world.actor.position.distance_to(start)))
 assert(cardinal > 0)
 assert(not camp._try_player_step(Vector2(99999,99999)))
 # Every navigation edge, including stair edges, can be walked in both directions.
 for a in graph.get_point_ids():
  for b in graph.get_point_connections(a):
   camp.camp_world.current=a
   camp.camp_world.actor.position=graph.get_point_position(a)
   var end=graph.get_point_position(b)
   for i in 100:
    var remaining: Vector2=end-camp.camp_world.actor.position
    if remaining.length()<2: break
    camp.keyboard_walk(remaining, minf(0.05,remaining.length()/110.0))
   assert(camp.camp_world.actor.position.distance_to(end)<2,"Blocked authored navigation edge")
 # Screen-axis crossing of every fully connected diamond corner must not stick.
 var corner_cases := 0
 for cell in camp.camp_world.ids:
  for offset in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
   var dest: Vector2i=cell+offset
   var x: Vector2i=cell+Vector2i(offset.x,0)
   var y: Vector2i=cell+Vector2i(0,offset.y)
   var ids: Dictionary=camp.camp_world.ids
   if not ids.has(dest) or not ids.has(x) or not ids.has(y): continue
   if camp.camp_world.heights[cell]!=camp.camp_world.heights[dest]: continue
   if not (graph.are_points_connected(ids[cell],ids[x]) and graph.are_points_connected(ids[cell],ids[y]) and graph.are_points_connected(ids[x],ids[dest]) and graph.are_points_connected(ids[y],ids[dest])): continue
   camp.camp_world.current=ids[cell]
   camp.camp_world.actor.position=graph.get_point_position(ids[cell])
   var end=graph.get_point_position(ids[dest])
   for i in 100:
    var remaining: Vector2=end-camp.camp_world.actor.position
    if remaining.length()<2: break
    camp.keyboard_walk(remaining,minf(0.05,remaining.length()/110.0))
   assert(camp.camp_world.actor.position.distance_to(end)<2,"Screen-axis diamond corner blocked")
   corner_cases+=1
 assert(corner_cases>0)
 print("PASS screen-axis corner cases: ",corner_cases)
 # All authored stairs must exist; checking only surviving edges misses ghost blockers.
 for stair in camp.camp_world.data.stairs:
  var cells=[Vector2i(stair.from[0],stair.from[1]),Vector2i(stair.cell[0],stair.cell[1]),Vector2i(stair.to[0],stair.to[1])]
  for cell in cells: assert(camp.camp_world.ids.has(cell),"Missing stair/landing node: "+str(cell))
  var ids=camp.camp_world.ids
  assert(graph.are_points_connected(ids[cells[0]],ids[cells[1]]))
  assert(graph.are_points_connected(ids[cells[1]],ids[cells[2]]))
  var side=Vector2(-32,16) if stair.axis=="x" else Vector2(32,16)
  for lane in [-0.8,0.0,0.8]:
   for reverse in [false,true]:
    var start_id=ids[cells[2] if reverse else cells[0]]
    var end_id=ids[cells[0] if reverse else cells[2]]
    camp.camp_world.current=start_id
    camp.camp_world.actor.position=graph.get_point_position(start_id)+side*lane
    var end=graph.get_point_position(end_id)+side*lane
    for i in 150:
     var remaining: Vector2=end-camp.camp_world.actor.position
     if remaining.length()<2: break
     camp.keyboard_walk(remaining,minf(0.05,remaining.length()/110.0))
    assert(camp.camp_world.actor.position.distance_to(end)<2,"Stair side lane blocked: "+str(stair.cell))
 for polygon in camp.camp_world.footprints:
  var centre:=Vector2.ZERO
  for vertex in polygon: centre+=vertex
  centre/=polygon.size()
  assert(not camp._try_player_step(centre),"Building interior is walkable")
 print("PASS all 4 authored stairs, 24 side-lane traversals, building interiors blocked")
 # Door interaction opens the existing building module; modal prevents walking.
 var target=camp.camp_world.targets.filter(func(t): return str(t.visual.name)=="garden")[0]
 camp.camp_world.current=graph.get_closest_point(target.visual.position)
 camp.camp_world.actor.position=graph.get_point_position(camp.camp_world.current)
 camp.player.position=camp.camp_world.actor.position
 camp._update_interaction()
 assert(camp.nearby_interaction.get("id")=="garden")
 var e=InputEventKey.new()
 e.physical_keycode=KEY_E
 e.pressed=true
 camp._input(e)
 assert(is_instance_valid(camp.modal))
 start=camp.camp_world.actor.position
 camp.keyboard_walk(Vector2.RIGHT,0.05)
 assert(camp.camp_world.actor.position==start)
 camp._close_modal()
 await process_frame
 # NPC selected by distance, E produces dialogue. Isolate from nearby building doors.
 var npc=camp.camp_world.npcs.people[0].sprite
 camp.camp_world.current=node
 camp.camp_world.actor.position=graph.get_point_position(node)
 camp.player.position=camp.camp_world.actor.position
 npc.position=camp.player.position
 camp._input(e)
 assert(camp.toast_panel.visible and camp.toast_label.text.contains("青衣行脚者"))
 camp.player.position=Vector2(99999,99999)
 camp._update_interaction()
 assert(camp.nearby_interaction.is_empty() and not camp.interaction_hint.visible)
 assert(root.get_node("Game").suppress_profile_writes)
 print("PASS WASD speed, obstacles, all stair/graph edges, E building/NPC interaction, range, modal blocking")
 quit()
