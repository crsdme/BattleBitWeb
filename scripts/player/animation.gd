extends Node

const LOOPING := ["idle", "walk", "run", "sprint", "crouch", "fall"]

var _clip := ""
var _oneshot := ""

@onready var _body_animation: AnimationPlayer = $"../Body/Soldier/AnimationPlayer"


func _ready() -> void:
	if _body_animation == null:
		push_error("Soldier has no AnimationPlayer.")
		return
	for clip_name in LOOPING:
		if _body_animation.has_animation(clip_name):
			_body_animation.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	_body_animation.animation_finished.connect(_on_finished)
	_play("idle")


func update_view(horizontal_speed: float, on_floor: bool, _vertical_speed: float, crouching: bool) -> void:
	if _body_animation == null or _oneshot != "":
		return
	var clip := "idle"
	if not on_floor:
		clip = "fall"
	elif horizontal_speed > 6.0:
		clip = "sprint"
	elif horizontal_speed > 0.15:
		clip = "walk"
	elif crouching:
		clip = "crouch"
	_play(clip)


func notify_jumped() -> void:
	_play("jump")
	_oneshot = "jump"


func notify_landed() -> void:
	_play("land")
	_oneshot = "land"


func _on_finished(anim_name: StringName) -> void:
	if anim_name == StringName(_oneshot):
		_oneshot = ""
		_clip = ""


func _play(clip_name: String) -> void:
	if _body_animation == null or clip_name == _clip:
		return
	if not _body_animation.has_animation(clip_name):
		return
	_clip = clip_name
	_body_animation.play(clip_name, 0.12)