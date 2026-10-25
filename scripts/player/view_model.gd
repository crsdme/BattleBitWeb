extends Node3D
## FPS hands and the rifle follow the camera. Two-bone IK plants the hands
## on the grip markers in M4A1_with_grips.glb. Hand clips only translate
## ArmsRoot, so the rifle follows that sway and the hands stay on the grips.
## Reload is procedural: the left hand moves onto the magazine, pulls it out,
## seats it, and returns to the handguard.

enum LeftGrip { HANDGUARD, MAGAZINE }

const REACH := 0.34
const PULL := 0.42
const HOLD := 0.35
const INSERT := 0.40
const RETURN := 0.34
const MAG_PULL := Vector3(-0.04, -0.125, 0.04)

@export var viewmodel_scale := 0.2
@export var hands_scale := 380.0
@export var hands_pitch_degrees := 180.0
@export var hands_offset := Vector3(0.0, -0.32, -0.45)
@export var weapon_yaw_degrees := -90.0
@export var weapon_scale := 0.24
@export var weapon_offset := Vector3(-0.02, -0.18, -0.22)
@export var left_grip: LeftGrip = LeftGrip.HANDGUARD

@onready var hands: Node3D = $Hands
@onready var weapon: Node3D = $Weapon

var _ik: Node
var _skeleton: Skeleton3D
var _arms_root := -1
var _arms_rest := Vector3.ZERO
var _weapon_rest := Transform3D.IDENTITY
var _left_grip: Node3D
var _magazine_grip: Node3D
var _magazine: Node3D
var _magazine_rest := Transform3D.IDENTITY
var _left_target: Marker3D
var _reloading := false
var _reload_time := 0.0


func _ready() -> void:
	set_process_priority(10)
	scale = Vector3.ONE * viewmodel_scale
	hands.rotation = Vector3(deg_to_rad(hands_pitch_degrees), 0.0, 0.0)
	hands.position = hands_offset
	hands.scale = Vector3.ONE * hands_scale
	var weapon_basis := Basis(Vector3.UP, deg_to_rad(weapon_yaw_degrees)).scaled(Vector3.ONE * weapon_scale)
	weapon.transform = Transform3D(weapon_basis, weapon_offset)
	_weapon_rest = weapon.transform
	_setup_ik()
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func is_reloading() -> bool:
	return _reloading


func start_reload() -> bool:
	if _reloading or _ik == null or _left_target == null:
		return false
	_reloading = true
	_reload_time = 0.0
	_left_target.global_position = _left_grip.global_position
	_ik.set_chain_target("Hand.L", _left_target)
	return true


func _process(delta: float) -> void:
	if _reloading:
		_advance_reload(delta)
		if _reloading:
			return
	_follow_arm_sway()


func _advance_reload(delta: float) -> void:
	_reload_time += delta
	var time := _reload_time
	var reach_end := REACH
	var pull_end := reach_end + PULL
	var hold_end := pull_end + HOLD
	var insert_end := hold_end + INSERT
	var return_end := insert_end + RETURN
	if time >= return_end:
		_finish_reload()
		return
	var cant := 0.0
	var drop := 0.0
	var hand_blend := 0.0
	if time < reach_end:
		var alpha := _ease(time / REACH)
		cant = alpha * 0.45
		hand_blend = alpha
	elif time < pull_end:
		var alpha := _ease((time - reach_end) / PULL)
		cant = lerpf(0.45, 1.0, alpha)
		drop = alpha
		hand_blend = 1.0
	elif time < hold_end:
		cant = 1.0
		drop = 1.0
		hand_blend = 1.0
	elif time < insert_end:
		var alpha := _ease((time - hold_end) / INSERT)
		cant = lerpf(1.0, 0.0, alpha)
		drop = 1.0 - alpha
		hand_blend = 1.0
	else:
		hand_blend = 1.0 - _ease((time - insert_end) / RETURN)
	_pose_weapon(cant)
	_pose_magazine(drop)
	var on_guard: Vector3 = _left_grip.global_position
	var on_mag: Vector3 = _magazine_grip.global_position
	_left_target.global_position = on_guard.lerp(on_mag, hand_blend)


func _finish_reload() -> void:
	_magazine.transform = _magazine_rest
	weapon.transform = _weapon_rest
	_ik.set_chain_target("Hand.L", _left_grip)
	_reloading = false
	_reload_time = 0.0


func _pose_weapon(cant: float) -> void:
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(10.0 * cant))
	var shifted := _weapon_rest.origin + Vector3(0.0, 0.012, 0.018) * cant
	weapon.transform = Transform3D(tilt * _weapon_rest.basis, shifted)


func _pose_magazine(drop: float) -> void:
	var seated: Transform3D = _magazine.get_parent().global_transform * _magazine_rest
	var offset := global_transform.basis * (MAG_PULL * drop)
	_magazine.global_transform = Transform3D(seated.basis, seated.origin + offset)


func _follow_arm_sway() -> void:
	if _skeleton == null or _arms_root < 0:
		return
	var delta := _skeleton.get_bone_pose_position(_arms_root) - _arms_rest
	var world_delta := _skeleton.global_transform.basis * delta
	var local_delta := global_transform.affine_inverse().basis * world_delta
	weapon.transform = Transform3D(_weapon_rest.basis, _weapon_rest.origin + local_delta)


func _ease(alpha: float) -> float:
	return smoothstep(0.0, 1.0, clampf(alpha, 0.0, 1.0))


func _setup_ik() -> void:
	_skeleton = hands.find_child("Skeleton3D", true, false) as Skeleton3D
	var right_grip := weapon.find_child("RightHandGrip", true, false) as Node3D
	_left_grip = weapon.find_child(_left_grip_name(), true, false) as Node3D
	_magazine_grip = weapon.find_child("MagazineGrip", true, false) as Node3D
	_magazine = weapon.find_child("Magazine", true, false) as Node3D
	if _skeleton == null or right_grip == null or _left_grip == null or _magazine_grip == null or _magazine == null:
		push_error("FPS IK is missing the hand skeleton, a grip marker, or the magazine.")
		return
	_arms_root = _skeleton.find_bone("ArmsRoot")
	_skeleton.reset_bone_poses()
	_arms_rest = _skeleton.get_bone_pose_position(_arms_root)
	_magazine_rest = _magazine.transform
	_left_target = Marker3D.new()
	_left_target.name = "LeftReloadTarget"
	add_child(_left_target)
	_ik = preload("res://scripts/player/fps_arm_ik.gd").new()
	_ik.name = "ArmIK"
	_ik.skeleton = _skeleton
	add_child(_ik)
	_ik.set_process_priority(20)
	_ik.add_chain(
		"UpperArm.R", "Forearm.R", "Hand.R",
		right_grip, _pole("PoleR", Vector3(0.85, -0.85, -0.45)),
		null
	)
	_ik.add_chain(
		"UpperArm.L", "Forearm.L", "Hand.L",
		_left_grip, _pole("PoleL", Vector3(-0.85, -0.8, -0.5)),
		null
	)


func _left_grip_name() -> String:
	if left_grip == LeftGrip.MAGAZINE:
		return "MagazineGrip"
	return "LeftHandGrip"


func _pole(pole_name: String, position: Vector3) -> Marker3D:
	var pole := Marker3D.new()
	pole.name = pole_name
	pole.position = position
	add_child(pole)
	return pole
