class_name CoopCamera
extends Camera3D

@export var follow_distance: float = 4.0
@export var follow_height: float = 2.5
@export var follow_speed: float = 5.0

var _target: Node3D

func _ready() -> void:
	current = true
	call_deferred("_find_target")

func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_target = players[0] as Node3D

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_find_target()
		return

	var target_pos: Vector3 = _target.global_transform.origin
	var forward: Vector3 = -_target.global_transform.basis.z
	forward.y = 0.0
	if forward.length() > 0.001:
		forward = forward.normalized()

	var desired_pos: Vector3 = target_pos - forward * follow_distance + Vector3.UP * follow_height
	var t: float = clamp(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired_pos, t)
	look_at(target_pos + Vector3.UP * 1.0, Vector3.UP)
