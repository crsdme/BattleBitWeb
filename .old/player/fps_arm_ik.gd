extends Node
## Two-bone IK for the FPS arms. Each chain reaches a grip marker on the rifle,
## and the elbow bends toward a pole so the arm does not flip.

var skeleton: Skeleton3D
var active := true
var _chains: Array[Dictionary] = []


func set_chain_target(end_bone: String, target: Node3D) -> void:
	var end := skeleton.find_bone(end_bone)
	for chain in _chains:
		if chain["end"] == end:
			chain["target"] = target
			return


func add_chain(root_bone: String, middle_bone: String, end_bone: String, target: Node3D, pole: Node3D, orientation: Node3D) -> void:
	_chains.append({
		"root": skeleton.find_bone(root_bone),
		"middle": skeleton.find_bone(middle_bone),
		"end": skeleton.find_bone(end_bone),
		"upper_length": skeleton.get_bone_rest(skeleton.find_bone(middle_bone)).origin.length(),
		"fore_length": skeleton.get_bone_rest(skeleton.find_bone(end_bone)).origin.length(),
		"target": target,
		"pole": pole,
		"orientation": orientation,
	})


func _process(_delta: float) -> void:
	if not active or skeleton == null:
		return
	for chain in _chains:
		_solve_chain(chain)
	skeleton.force_update_all_bone_transforms()


func _solve_chain(chain: Dictionary) -> void:
	var root: int = chain["root"]
	var middle: int = chain["middle"]
	var end: int = chain["end"]
	var target: Node3D = chain["target"]
	var pole: Node3D = chain["pole"]
	if root < 0 or middle < 0 or end < 0 or target == null or pole == null:
		return
	var to_skeleton := skeleton.global_transform.affine_inverse()
	var shoulder: Vector3 = skeleton.get_bone_global_pose(root).origin
	var goal: Vector3 = to_skeleton * target.global_position
	var hint: Vector3 = to_skeleton * pole.global_position
	var upper_length: float = chain["upper_length"]
	var fore_length: float = chain["fore_length"]
	var elbow := _elbow(shoulder, goal, upper_length, fore_length, hint)
	_aim_bone(root, middle, elbow)
	_aim_bone(middle, end, goal)
	var orientation: Node3D = chain["orientation"]
	if orientation:
		_align_end(end, orientation)


func _elbow(shoulder: Vector3, goal: Vector3, upper_length: float, fore_length: float, pole: Vector3) -> Vector3:
	var reach := upper_length + fore_length
	var to_goal := goal - shoulder
	var distance := to_goal.length()
	if distance < 0.0001:
		to_goal = Vector3(0, -1, 0)
		distance = 0.0001
	distance = clampf(distance, absf(upper_length - fore_length) + 0.001, reach - 0.001)
	var direction := to_goal / to_goal.length()
	var along := (upper_length * upper_length - fore_length * fore_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var pole_offset := pole - shoulder
	var bend := pole_offset - direction * pole_offset.dot(direction)
	if bend.length_squared() < 0.000001:
		bend = direction.cross(Vector3.UP)
	bend = bend.normalized()
	return shoulder + direction * along + bend * height


func _aim_bone(bone: int, child: int, target: Vector3) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_global := Transform3D.IDENTITY
	if parent >= 0:
		parent_global = skeleton.get_bone_global_pose(parent)
	var bone_global := skeleton.get_bone_global_pose(bone)
	var current := bone_global.basis * skeleton.get_bone_rest(child).origin
	var desired := target - bone_global.origin
	if current.length_squared() < 0.0000001 or desired.length_squared() < 0.0000001:
		return
	var turn := Quaternion(current.normalized(), desired.normalized())
	bone_global.basis = Basis(turn) * bone_global.basis
	skeleton.set_bone_pose(bone, parent_global.affine_inverse() * bone_global)
	skeleton.force_update_bone_child_transform(bone)


func _align_end(bone: int, target: Node3D) -> void:
	var parent := skeleton.get_bone_parent(bone)
	if parent < 0:
		return
	var bone_global := skeleton.get_bone_global_pose(bone)
	var target_basis := (skeleton.global_transform.affine_inverse() * target.global_transform).basis.orthonormalized()
	var fingers := target_basis.y
	if fingers.length_squared() < 0.001:
		return
	fingers = fingers.normalized()
	var palm := target_basis.z
	if absf(fingers.dot(palm)) > 0.98:
		palm = target_basis.x
	var side := palm.cross(fingers).normalized()
	palm = fingers.cross(side).normalized()
	bone_global.basis = Basis(side, fingers, palm)
	var parent_global := skeleton.get_bone_global_pose(parent)
	skeleton.set_bone_pose(bone, parent_global.affine_inverse() * bone_global)
