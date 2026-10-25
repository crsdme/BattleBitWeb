extends Node
## Full-body clips live on the imported soldier AnimationPlayer.
## View clips live on the imported FPS hands AnimationPlayer.
## Reload is IK and replaces the hand clip until it finishes.

const LOOPING_BODY := ["idle", "walk", "run", "sprint", "crouch", "fall"]
const LOOPING_HANDS := ["fps_idle", "fps_walk", "fps_run", "fps_sprint", "fps_fall", "fps_ads_idle"]

@export var run_speed_threshold := 6.5

var _body_clip := ""
var _hands_clip := ""
var _body_oneshot := ""
var _hands_oneshot := ""

@onready var _view: Node3D = $"../Head/Camera3D/ViewModel"
@onready var _body_animation: AnimationPlayer = $"../Body/Soldier/AnimationPlayer"
@onready var _hands_animation: AnimationPlayer = $"../Head/Camera3D/ViewModel/Hands/AnimationPlayer"


func _ready() -> void:
	_arm(_body_animation, LOOPING_BODY, _on_body_finished)
	_arm(_hands_animation, LOOPING_HANDS, _on_hands_finished)
	_play_body("idle")
	_play_hands("fps_equip")
	_hands_oneshot = "fps_equip"


func update_view(horizontal_speed: float, on_floor: bool, vertical_speed: float) -> void:
	_update_body(horizontal_speed, on_floor, vertical_speed)
	if _hands_animation == null:
		return
	if _view.is_reloading():
		if _hands_animation.is_playing():
			_hands_animation.stop()
		_hands_clip = ""
		_hands_oneshot = ""
		return
	if _hands_oneshot != "":
		return
	_play_hands(_hands_clip_for(horizontal_speed, on_floor, vertical_speed))


func notify_jumped() -> void:
	if not _view.is_reloading():
		_play_hands("fps_jump")
		_hands_oneshot = "fps_jump"
	_play_body("jump")
	_body_oneshot = "jump"


func notify_landed() -> void:
	if not _view.is_reloading():
		_play_hands("fps_land")
		_hands_oneshot = "fps_land"
	_play_body("land")
	_body_oneshot = "land"


func _update_body(horizontal_speed: float, on_floor: bool, _vertical_speed: float) -> void:
	if _body_animation == null or _body_oneshot != "":
		return
	var clip := "idle"
	if not on_floor:
		clip = "fall"
	elif horizontal_speed >= run_speed_threshold:
		clip = "run"
	elif horizontal_speed > 0.15:
		clip = "walk"
	_play_body(clip)


func _hands_clip_for(horizontal_speed: float, on_floor: bool, vertical_speed: float) -> String:
	if not on_floor:
		return "fps_jump" if vertical_speed > 0.2 else "fps_fall"
	if horizontal_speed >= run_speed_threshold:
		return "fps_run"
	if horizontal_speed > 0.15:
		return "fps_walk"
	return "fps_idle"


func _on_body_finished(anim_name: StringName) -> void:
	if anim_name == StringName(_body_oneshot):
		_body_oneshot = ""
		_body_clip = ""


func _on_hands_finished(anim_name: StringName) -> void:
	if anim_name == StringName(_hands_oneshot):
		_hands_oneshot = ""
		_hands_clip = ""


func _arm(animation_player: AnimationPlayer, looping: Array, finished: Callable) -> void:
	if animation_player == null:
		push_error("A player model is missing its AnimationPlayer.")
		return
	for clip_name in looping:
		if animation_player.has_animation(clip_name):
			animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	animation_player.animation_finished.connect(finished)


func _play_body(clip_name: String) -> void:
	if _body_animation == null or clip_name == _body_clip:
		return
	if not _body_animation.has_animation(clip_name):
		return
	_body_clip = clip_name
	_body_animation.play(clip_name, 0.12)


func _play_hands(clip_name: String) -> void:
	if _hands_animation == null or clip_name == _hands_clip:
		return
	if not _hands_animation.has_animation(clip_name):
		return
	_hands_clip = clip_name
	_hands_animation.play(clip_name, 0.1)
