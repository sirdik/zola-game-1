class_name CoopCamera
extends Node3D

@export var follow_speed: float = 5.0

var _target: Node3D

func _ready() -> void:
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
	var t: float = clamp(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(target_pos, t)
