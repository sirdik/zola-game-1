class_name CoopCamera
extends Node3D

@export var follow_speed: float = 5.0
@export var min_spring_length: float = 7.0
@export var max_spring_length: float = 14.0
@export var max_player_spread: float = 15.0
@export var zoom_speed: float = 3.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

func _process(delta: float) -> void:
	var players := _get_players()
	if players.is_empty():
		return

	var midpoint := _compute_midpoint(players)
	var move_t: float = clamp(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(midpoint, move_t)

	var spread := _compute_max_spread(players, midpoint)
	_teleport_stragglers(players)

	var target_spring_length: float = clamp(min_spring_length + spread * 0.5, min_spring_length, max_spring_length)
	var zoom_t: float = clamp(zoom_speed * delta, 0.0, 1.0)
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_spring_length, zoom_t)

func _get_players() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("players"):
		if node is Node3D:
			result.append(node)
	return result

func _compute_midpoint(players: Array[Node3D]) -> Vector3:
	var sum := Vector3.ZERO
	for p in players:
		sum += p.global_position
	return sum / players.size()

func _compute_max_spread(players: Array[Node3D], midpoint: Vector3) -> float:
	var max_dist := 0.0
	for p in players:
		max_dist = max(max_dist, p.global_position.distance_to(midpoint))
	return max_dist

func _teleport_stragglers(players: Array[Node3D]) -> void:
	if players.size() < 2:
		return
	var anchor := _find_anchor(players)
	for p in players:
		if p == anchor:
			continue
		var to_player := p.global_position - anchor.global_position
		to_player.y = 0.0
		if to_player.length() > max_player_spread:
			p.global_position = anchor.global_position + to_player.normalized() * (max_player_spread * 0.6) + Vector3(0, 0.05, 0)

func _find_anchor(players: Array[Node3D]) -> Node3D:
	var midpoint := _compute_midpoint(players)
	var anchor: Node3D = players[0]
	var best_dist := INF
	for p in players:
		var dist: float = p.global_position.distance_to(midpoint)
		if dist < best_dist:
			best_dist = dist
			anchor = p
	return anchor
