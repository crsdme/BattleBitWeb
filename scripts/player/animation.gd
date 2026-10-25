extends Node

const LOOPING := ["idle", "walk", "run", "sprint", "crouch", "fall"]
const LOOPING_HANDS := ["fps_idle", "fps_walk", "fps_sprint", "fps_fall"]

var _clip := ""
var _oneshot := ""

var _hands_clip := ""
var _hands_oneshot := ""

@onready var _body_animation: AnimationPlayer = $"../Body/Soldier/AnimationPlayer"
@onready var _hands_animation: AnimationPlayer = $"../Head/Camera/ViewModel/Hands/AnimationPlayer"


func _ready() -> void:
	if _body_animation == null:
		push_error("Soldier has no AnimationPlayer.")
		return
	for clip_name in LOOPING:
		if _body_animation.has_animation(clip_name):
			_body_animation.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	_body_animation.animation_finished.connect(_on_finished)
	_play("idle")

	if _hands_animation != null:
		for clip_name in LOOPING_HANDS:
			if _hands_animation.has_animation(clip_name):
				_hands_animation.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		_hands_animation.animation_finished.connect(_on_hands_finished)
		_play_hands("fps_idle")


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

	if _hands_oneshot != "":
		return
	var hands_clip := "fps_idle"
	if not on_floor:
		hands_clip = "fps_fall"
	elif horizontal_speed > 6.0:
		hands_clip = "fps_sprint"
	elif horizontal_speed > 0.15:
		hands_clip = "fps_walk"
	_play_hands(hands_clip)


func notify_jumped() -> void:
	_play("jump")
	_oneshot = "jump"
	_play_hands("fps_jump")
	_hands_oneshot = "fps_jump"


func notify_landed() -> void:
	_play("land")
	_oneshot = "land"
	_play_hands("fps_land")
	_hands_oneshot = "fps_land"


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

func _on_hands_finished(anim_name: StringName) -> void:
	if anim_name == StringName(_hands_oneshot):
		_hands_oneshot = ""
		_hands_clip = ""


func _play_hands(clip_name: String) -> void:
	if _hands_animation == null or clip_name == _hands_clip:
		return
	if not _hands_animation.has_animation(clip_name):
		return
	_hands_clip = clip_name
	_hands_animation.play(clip_name, 0.1)