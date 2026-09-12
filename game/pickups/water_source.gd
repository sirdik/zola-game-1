extends Area3D

const COLLECT_INTERVAL := 2.0

var _timer: float = 0.0
var _player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = true
		_timer = 0.0

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = false

func _process(delta: float) -> void:
	if not _player_inside:
		return
	_timer += delta
	if _timer >= COLLECT_INTERVAL:
		_timer -= COLLECT_INTERVAL
		Game.add_item("water", 1)
