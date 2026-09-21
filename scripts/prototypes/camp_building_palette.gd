@tool
extends RefCounted
## Shared candidate art direction for map sprites and standalone building previews.
static func apply(material: StandardMaterial3D) -> void:
	var name := material.resource_name.to_lower()
	var tint := Color(0.70, 0.72, 0.72)
	if name.begins_with("basalt") or "stair stone" in name:
		tint = Color(0.53, 0.57, 0.58)
		material.roughness = maxf(material.roughness, 0.88)
	elif "worn cut edges" in name:
		tint = Color(0.60, 0.63, 0.60)
	elif "smoked oak" in name or "charcoal lacquer" in name:
		tint = Color(0.72, 0.68, 0.62)
		material.roughness = maxf(material.roughness, 0.78)
	elif "ceramic" in name or "ridge caps" in name:
		tint = Color(0.71, 0.74, 0.77)
	elif "bronze" in name or "gilded" in name:
		tint = Color(0.61, 0.59, 0.50)
		material.roughness = maxf(material.roughness, 0.65)
	elif "parchment" in name or "linen" in name:
		tint = Color(0.67, 0.63, 0.53)
	elif "skin" in name or "robe" in name:
		tint = Color(0.84, 0.84, 0.82)
	# Keep authored emissive colours; the motion controllers own their intensity.
	if not material.emission_enabled:
		material.albedo_color *= tint
