class_name Player
extends CharacterBody3D

const Palette = preload("res://game/theme/palette.gd")

@export var player_number: int = 1
@export var move_speed: float = 4.0
@export var jump_velocity: float = 5.0
@export var turn_speed: float = 10.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _ready() -> void:
	add_to_group("players")
	var mesh_instance: MeshInstance3D = $MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PEACH
	mesh_instance.material_override = material

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(_action("jump")):
		velocity.y = jump_velocity

	var move_direction := _get_move_direction()
	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed

	if move_direction.length() > 0.01:
		var target_angle := atan2(-move_direction.x, -move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)

	move_and_slide()

func _get_move_direction() -> Vector3:
	var input_dir := Vector2.ZERO
	input_dir.y -= 1.0 if Input.is_action_pressed(_action("move_forward")) else 0.0
	input_dir.y += 1.0 if Input.is_action_pressed(_action("move_back")) else 0.0
	input_dir.x -= 1.0 if Input.is_action_pressed(_action("move_left")) else 0.0
	input_dir.x += 1.0 if Input.is_action_pressed(_action("move_right")) else 0.0

	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_dir.x, 0.0, -input_dir.y).normalized()

	var cam_basis := camera.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()
	return (forward * -input_dir.y + right * input_dir.x).normalized()

func _action(action_name: String) -> String:
	return "p%d_%s" % [player_number, action_name]
