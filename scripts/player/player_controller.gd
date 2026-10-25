extends CharacterBody3D

const SPEED := 4.8
const ACCELERATION := 28.0
const JUMP_VELOCITY := 4.6
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := 85.0

@onready var head: Node3D = $Head
@onready var animation: Node = $Animation
@onready var view_model: Node3D = $Head/Camera3D/ViewModel

var _in_air := false


func _ready() -> void:
	_ensure_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-PITCH_LIMIT), deg_to_rad(PITCH_LIMIT))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	if not was_on_floor:
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		animation.notify_jumped()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target := direction * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCELERATION * delta)
	move_and_slide()

	if was_on_floor and not is_on_floor():
		_in_air = true
	if _in_air and is_on_floor():
		animation.notify_landed()
		_in_air = false
	if Input.is_action_just_pressed("reload"):
		view_model.start_reload()

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var animate_grounded := is_on_floor() or not _in_air
	animation.update_view(horizontal_speed, animate_grounded, velocity.y)


func _ensure_actions() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("reload", KEY_R)


func _bind_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
