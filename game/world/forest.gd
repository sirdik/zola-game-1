extends Node3D

const Palette = preload("res://game/theme/palette.gd")

func _ready() -> void:
	var ground_mesh: MeshInstance3D = $Ground/MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PASTEL_GREEN
	ground_mesh.material_override = material
