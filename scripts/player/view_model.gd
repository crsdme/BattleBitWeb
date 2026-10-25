extends Node3D

@onready var hands: Node3D = $Hands
@onready var weapon: Node3D = $Weapon

var _ik: Node
var _skeleton: Skeleton3D
var _arms_root := -1
var _arms_rest := Vector3.ZERO
var _weapon_rest := Transform3D.IDENTITY


func _ready() -> void:
	set_process_priority(10)

	_skeleton = hands.find_child("Skeleton3D", true, false) as Skeleton3D
	_weapon_rest = weapon.transform

	var skeleton := hands.find_child("Skeleton3D", true, false) as Skeleton3D
	var right_grip := weapon.find_child("RightHandGrip", true, false) as Node3D
	var left_grip := weapon.find_child("LeftHandGrip", true, false) as Node3D
	if skeleton == null or right_grip == null or left_grip == null:
		push_error("IK needs the hand skeleton and both grip markers.")
		return

	_arms_root = _skeleton.find_bone("ArmsRoot")
	_skeleton.reset_bone_poses()
	_arms_rest = _skeleton.get_bone_pose_position(_arms_root)

	_ik = preload("res://scripts/player/fps_arm_ik.gd").new()
	_ik.name = "ArmIK"
	_ik.skeleton = skeleton
	add_child(_ik)
	_ik.set_process_priority(20)
	_ik.add_chain("UpperArm.R", "Forearm.R", "Hand.R", right_grip, _pole("PoleR", Vector3(0.85, -0.85, -0.45)), null)
	_ik.add_chain("UpperArm.L", "Forearm.L", "Hand.L", left_grip, _pole("PoleL", Vector3(-0.85, -0.8, -0.5)), null)


func _pole(pole_name: String, position: Vector3) -> Marker3D:
	var pole := Marker3D.new()
	pole.name = pole_name
	pole.position = position
	add_child(pole)
	return pole

func _process(_delta: float) -> void:
	if _skeleton == null or _arms_root < 0:
		return
	var delta := _skeleton.get_bone_pose_position(_arms_root) - _arms_rest
	var world_delta := _skeleton.global_transform.basis * delta
	var local_delta := global_transform.affine_inverse().basis * world_delta
	weapon.transform = Transform3D(_weapon_rest.basis, _weapon_rest.origin + local_delta)
