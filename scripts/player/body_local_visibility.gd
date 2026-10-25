extends Node
## Hides the local soldier's head and arms so the FPS camera does not see duplicates.
## Legs, hips, torso and vest stay visible. Imported GLB files are not modified.
##
## body-rigged-animated.glb is one skinned mesh, SubMesh_0. Head and arm
## triangles are stripped from a runtime copy using skin bind names.

const _HEAD_BONES: PackedStringArray = ["Head", "Neck"]
const _ARM_BONES: PackedStringArray = [
	"UpperArm.L", "Forearm.L", "Hand.L",
	"UpperArm.R", "Forearm.R", "Hand.R",
]


func _ready() -> void:
	apply_local_visibility()


func apply_local_visibility() -> void:
	var hidden_nodes := 0
	var skinned: Array[MeshInstance3D] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var kind := _classify_mesh_name(String(mesh_instance.name))
		if kind == "hide":
			mesh_instance.visible = false
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hidden_nodes += 1
		elif kind == "unknown" and mesh_instance.skin != null:
			skinned.append(mesh_instance)
	if hidden_nodes == 0:
		for mesh_instance in skinned:
			_strip_head_and_arms(mesh_instance)


func _classify_mesh_name(mesh_name: String) -> String:
	var lowered := mesh_name.to_lower()
	if "leg" in lowered or "thigh" in lowered or "shin" in lowered or "boot" in lowered or "foot" in lowered or "hip" in lowered:
		return "keep"
	if "torso" in lowered or "vest" in lowered or "chest" in lowered or "spine" in lowered:
		return "keep"
	if "head" in lowered or "helmet" in lowered or "neck" in lowered:
		return "hide"
	if "arm" in lowered or "hand" in lowered:
		return "hide"
	return "unknown"


func _strip_head_and_arms(mesh_instance: MeshInstance3D) -> void:
	var source := mesh_instance.mesh
	if source == null or mesh_instance.skin == null:
		return
	var hidden_binds := _hidden_bind_indices(mesh_instance.skin)
	if hidden_binds.is_empty():
		return
	var stripped := ArrayMesh.new()
	var wrote_surface := false
	for surface_idx in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_idx)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or bones.is_empty() or weights.is_empty():
			continue
		var weights_per_vertex := int(weights.size() / vertices.size())
		var vertex_hidden := PackedByteArray()
		vertex_hidden.resize(vertices.size())
		for vertex_idx in vertices.size():
			var best_weight := -1.0
			var best_bone := -1
			for slot in weights_per_vertex:
				var weight := weights[vertex_idx * weights_per_vertex + slot]
				if weight > best_weight:
					best_weight = weight
					best_bone = bones[vertex_idx * weights_per_vertex + slot]
			vertex_hidden[vertex_idx] = 1 if hidden_binds.has(best_bone) else 0
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		if indices.is_empty():
			for triangle in range(0, vertices.size() - 2, 3):
				if _triangle_hidden(vertex_hidden, triangle, triangle + 1, triangle + 2):
					continue
				kept.append(triangle)
				kept.append(triangle + 1)
				kept.append(triangle + 2)
		else:
			for triangle in range(0, indices.size() - 2, 3):
				var i0 := indices[triangle]
				var i1 := indices[triangle + 1]
				var i2 := indices[triangle + 2]
				if _triangle_hidden(vertex_hidden, i0, i1, i2):
					continue
				kept.append(i0)
				kept.append(i1)
				kept.append(i2)
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		stripped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		stripped.surface_set_material(stripped.get_surface_count() - 1, source.surface_get_material(surface_idx))
		wrote_surface = true
	if wrote_surface:
		mesh_instance.mesh = stripped


func _hidden_bind_indices(skin: Skin) -> Dictionary:
	var hidden := {}
	for bind_idx in skin.get_bind_count():
		var bone_name := String(skin.get_bind_name(bind_idx))
		if bone_name in _HEAD_BONES or bone_name in _ARM_BONES:
			hidden[bind_idx] = true
	return hidden


func _triangle_hidden(vertex_hidden: PackedByteArray, i0: int, i1: int, i2: int) -> bool:
	var hidden_count := vertex_hidden[i0] + vertex_hidden[i1] + vertex_hidden[i2]
	# One shared vertex is enough. On the combined full-body mesh, arm and
	# head spikes often sit on a triangle whose other two corners stay on the torso.
	return hidden_count >= 1
