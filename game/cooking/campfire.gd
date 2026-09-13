extends Area3D

var _players_in_range: int = 0
var _hud: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	call_deferred("_find_hud")

func _find_hud() -> void:
	var huds := get_tree().get_nodes_in_group("hud")
	if huds.size() > 0:
		_hud = huds[0]
		if _players_in_range > 0:
			_hud.set_near_campfire(true)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_players_in_range += 1
		if _hud != null and _players_in_range == 1:
			_hud.set_near_campfire(true)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_players_in_range = max(0, _players_in_range - 1)
		if _hud != null and _players_in_range == 0:
			_hud.set_near_campfire(false)

func _process(_delta: float) -> void:
	if _hud == null:
		_find_hud()
