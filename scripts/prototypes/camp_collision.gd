extends RefCounted
## Authored ground footprints relative to the visible building threshold, in world pixels.
static func polygons(definition: Dictionary) -> Array[PackedVector2Array]:
 var result: Array[PackedVector2Array] = []
 var heights := {}
 for c in definition.cells: heights[Vector2i(c[0],c[1])] = float(c[2])
 for building in definition.buildings:
  if not building.get("collision_enabled",true) or not building.get("preview_visible",false): continue
  var door := Vector2(building.door[0],building.door[1])
  var offset: Array = building.get("visual_offset",[0,0])
  var origin := Vector2((door.x-door.y)*64,(door.x+door.y)*32-float(heights.get(Vector2i(door),0)))+Vector2(offset[0],offset[1])
  var polygon := PackedVector2Array()
  var multiplier: Array = building.get("collision_scale",[1,1])
  var ratio := float(building.get("display_width",220))/float(building.get("collision_reference_width",building.get("display_width",220)))
  for p in building.get("collision_polygon",[]):
   polygon.append(origin+(Vector2(p[0],p[1])*Vector2(multiplier[0],multiplier[1])*ratio).rotated(deg_to_rad(float(building.get("rotation_degrees",0)))))
  if polygon.size() >= 3: result.append(polygon)
 return result

static func contains(point: Vector2, footprints: Array[PackedVector2Array]) -> bool:
 for polygon in footprints:
  if Geometry2D.is_point_in_polygon(point,polygon): return true
 return false

static func crosses(a: Vector2,b: Vector2,footprints: Array[PackedVector2Array]) -> bool:
 if contains(a,footprints) or contains(b,footprints): return true
 for polygon in footprints:
  for i in polygon.size():
   if Geometry2D.segment_intersects_segment(a,b,polygon[i],polygon[(i+1)%polygon.size()]) != null: return true
 return false
