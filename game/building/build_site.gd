extends Area3D

const BuildingLoader = preload("res://game/building/building_loader.gd")

const ARC_HEIGHT := 1.0
const FLY_DURATION := 0.4
const BLOCK_DELAY := 0.15
const UNLOCKED_COLOR := Color(0.85, 0.7, 0.4)

@export var building_id: String = "house"
@export var data_path: String = "res://data/house.txt"

@onready var marker: MeshInstance3D = $Marker

var _blocks: Array[Dictionary] = []
var _next_index: int = 0
var _placing: bool = false
var _player_in_range: bool = false
var _was_unlocked: bool = false

func _ready() -> void:
	_blocks = BuildingLoader.parse(data_path)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_in_range = false

func _process(_delta: float) -> void:
	var unlocked := Game.is_building_unlocked(building_id)
	if unlocked and not _was_unlocked:
		_was_unlocked = true
		var material := StandardMaterial3D.new()
		material.albedo_color = UNLOCKED_COLOR
		marker.material_override = material

	if unlocked and _player_in_range and not _placing and Input.is_action_just_pressed("p1_action"):
		_place_next_block()

func _place_next_block() -> void:
	if _next_index >= _blocks.size():
		return
	if not Game.try_consume("block"):
		return
	_placing = true

	var block_data: Dictionary = _blocks[_next_index]
	_next_index += 1

	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * BuildingLoader.BLOCK_SIZE
	block.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = block_data["color"]
	block.material_override = material
	add_child(block)

	var start_pos: Vector3 = global_position + Vector3(0, 2.0, 0)
	var end_pos: Vector3 = global_position + block_data["position"]
	block.global_position = start_pos

	var tween := create_tween()
	tween.tween_method(_fly_step.bind(block, start_pos, end_pos), 0.0, 1.0, FLY_DURATION)
	tween.tween_callback(_land_block.bind(block, end_pos))
	tween.tween_interval(BLOCK_DELAY)
	tween.tween_callback(_finish_placing)

func _fly_step(block: MeshInstance3D, start_pos: Vector3, end_pos: Vector3, t: float) -> void:
	var pos: Vector3 = start_pos.lerp(end_pos, t)
	pos.y += sin(t * PI) * ARC_HEIGHT
	block.global_position = pos

func _land_block(block: MeshInstance3D, end_pos: Vector3) -> void:
	block.global_position = end_pos
	var squash := create_tween()
	squash.tween_property(block, "scale", Vector3(1.3, 0.7, 1.3), 0.08)
	squash.tween_property(block, "scale", Vector3.ONE, 0.12)

func _finish_placing() -> void:
	_placing = false
	_place_next_block()
