extends Node3D

const Palette = preload("res://game/theme/palette.gd")

func _ready() -> void:
	var ground_mesh: MeshInstance3D = $Ground/MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PASTEL_GREEN
	ground_mesh.material_override = material

	var env: Environment = $WorldEnvironment.environment
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
	sky_mat.sky_top_color = Palette.SKY_BLUE.darkened(0.15)
	sky_mat.sky_horizon_color = Palette.CREAM.lerp(Palette.SKY_BLUE, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.CREAM.lerp(Palette.SKY_BLUE, 0.3)
