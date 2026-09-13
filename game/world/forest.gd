extends Node3D

const Palette = preload("res://game/theme/palette.gd")

func _ready() -> void:
	var env: Environment = $WorldEnvironment.environment
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
	sky_mat.sky_top_color = Palette.SKY_BLUE.darkened(0.15)
	sky_mat.sky_horizon_color = Palette.CREAM.lerp(Palette.SKY_BLUE, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.CREAM.lerp(Palette.SKY_BLUE, 0.3)

	var music_player: AudioStreamPlayer = $MusicPlayer
	if music_player.stream is AudioStreamWAV:
		music_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music_player.play()
