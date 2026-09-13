extends Area3D

const PlayerScript = preload("res://game/player/player.gd")

var _players_in_range: Dictionary = {}
var _hud: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	call_deferred("_find_hud")

func _find_hud() -> void:
	var huds := get_tree().get_nodes_in_group("hud")
	if huds.size() > 0:
		_hud = huds[0]
		_notify_hud()

func _on_body_entered(body: Node3D) -> void:
	var player := body as PlayerScript
	if player != null:
		_players_in_range[player.player_number] = true
		_notify_hud()

func _on_body_exited(body: Node3D) -> void:
	var player := body as PlayerScript
	if player != null:
		_players_in_range.erase(player.player_number)
		_notify_hud()

func _notify_hud() -> void:
	if _hud != null:
		_hud.set_near_campfire(_players_in_range.keys())

func _process(_delta: float) -> void:
	if _hud == null:
		_find_hud()
