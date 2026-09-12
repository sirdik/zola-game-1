extends Area3D

@export var item_id: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	if item_id != "block" or not _deliver_to_build_site():
		Game.add_item(item_id)
	queue_free()

func _deliver_to_build_site() -> bool:
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site.has_method("receive_block") and site.receive_block(global_position):
			return true
	return false
