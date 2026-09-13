extends Node3D

const Palette = preload("res://game/theme/palette.gd")
const PickupScript = preload("res://game/pickups/pickup.gd")
const PickupScene := preload("res://game/pickups/Pickup.tscn")
const WaterSourceScript := preload("res://game/pickups/water_source.gd")
const CampfireScript := preload("res://game/cooking/campfire.gd")
const BuildSiteScript := preload("res://game/building/build_site.gd")
const AnimalScript := preload("res://game/animals/animal.gd")
const IconGenerator := preload("res://game/theme/icon_generator.gd")

const TILE_SIZE := 2.0
const SKIP_CHARS := "0123456789 "

@export var level_path: String = "res://levels/forest_01.txt"
@export var player_path: NodePath = NodePath("../Player1")

func _ready() -> void:
	var lines := _read_grid_lines(level_path)
	if lines.is_empty():
		push_warning("level_loader: no grid lines found in %s" % level_path)
		return

	var cols := 0
	for line: String in lines:
		cols = max(cols, line.length())
	var rows := lines.size()

	_build_ground(cols, rows)

	var player_spawn_found := false
	var player_spawn_pos := Vector3.ZERO

	for row in range(rows):
		var line: String = lines[row]
		for col in range(cols):
			var ch: String = line[col] if col < line.length() else "."
			var world_pos := Vector3(col * TILE_SIZE, 0.0, row * TILE_SIZE)
			match ch:
				".":
					pass
				"#":
					_spawn_rock(world_pos)
				"T":
					_spawn_tree(world_pos)
				"~":
					_spawn_water(world_pos)
					_spawn_water_source(world_pos)
				"F":
					_spawn_campfire(world_pos)
				"S":
					_spawn_build_site(world_pos)
				"P":
					player_spawn_found = true
					player_spawn_pos = world_pos
				_:
					var item_data := Items.get_by_map_char(ch)
					if not item_data.is_empty():
						_spawn_pickup(world_pos, item_data)
					else:
						var animal_data := Animals.get_by_map_char(ch)
						if not animal_data.is_empty():
							_spawn_animal(world_pos, animal_data)
						elif not SKIP_CHARS.contains(ch):
							_spawn_unknown(world_pos, ch, row, col)

	if player_spawn_found:
		var player := get_node_or_null(player_path)
		if player is Node3D:
			player.global_position = player_spawn_pos + Vector3(0, 0.05, 0)

	var nav_region := NavigationRegion3D.new()
	add_child(nav_region)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = "nav_source"
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.25
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_region.navigation_mesh = nav_mesh
	nav_region.bake_navigation_mesh(true)

func _read_grid_lines(path: String) -> Array[String]:
	var lines: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("level_loader: could not open %s" % path)
		return lines
	var content := file.get_as_text()
	file.close()
	for raw_line: String in content.split("\n"):
		var line: String = raw_line.replace("\r", "")
		if line.begins_with(";"):
			continue
		if line.strip_edges() == "":
			continue
		if line.begins_with("[legend]"):
			break
		lines.append(line)
	return lines

func _build_ground(cols: int, rows: int) -> void:
	var width := cols * TILE_SIZE
	var depth := rows * TILE_SIZE
	var center := Vector3(width / 2.0 - TILE_SIZE / 2.0, -0.5, depth / 2.0 - TILE_SIZE / 2.0)

	var body := StaticBody3D.new()
	add_child(body)
	body.add_to_group("nav_source")

	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 1.0, depth)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	body.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 1.0, depth)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = center
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PASTEL_GREEN
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

func _spawn_rock(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	body.add_to_group("nav_source")

	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 1.0, 0)
	body.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 2.0, 2.0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, 1.0, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.6, 0.62)
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

func _spawn_tree(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	body.add_to_group("nav_source")

	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 2.0
	var collision := CollisionShape3D.new()
	collision.shape = trunk_shape
	collision.position = Vector3(0, 1.0, 0)
	body.add_child(collision)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 2.0
	var trunk_instance := MeshInstance3D.new()
	trunk_instance.mesh = trunk_mesh
	trunk_instance.position = Vector3(0, 1.0, 0)
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.55, 0.4, 0.28)
	trunk_instance.material_override = trunk_material
	body.add_child(trunk_instance)

	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 1.2
	crown_mesh.height = 2.5
	var crown_instance := MeshInstance3D.new()
	crown_instance.mesh = crown_mesh
	crown_instance.position = Vector3(0, 3.0, 0)
	var crown_material := StandardMaterial3D.new()
	crown_material.albedo_color = Palette.PASTEL_GREEN.darkened(0.3)
	crown_instance.material_override = crown_material
	body.add_child(crown_instance)

func _spawn_water(pos: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.1, 2.0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = pos + Vector3(0, 0.05, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.WATER_BLUE
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _spawn_water_source(pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.set_script(WaterSourceScript)
	add_child(area)

	var item_data := Items.get_by_map_char("~")
	area.item_id = item_data.get("id", "water")

	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 1.0, 0)
	area.add_child(collision)

func _spawn_pickup(pos: Vector3, item_data: Dictionary) -> void:
	var pickup: PickupScript = PickupScene.instantiate()
	pickup.item_id = item_data["id"]
	pickup.position = pos
	add_child(pickup)
	var sprite: Sprite3D = pickup.get_node("Sprite3D")
	sprite.texture = IconGenerator.generate(item_data.get("icon", "circle"), Color.html(item_data["color"]))

func _spawn_campfire(pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.set_script(CampfireScript)
	add_child(area)

	var shape := SphereShape3D.new()
	shape.radius = 1.5
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 0.5, 0)
	area.add_child(collision)

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.3
	mesh.height = 0.4
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, 0.2, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.45, 0.2)
	mesh_instance.material_override = material
	area.add_child(mesh_instance)

func _spawn_build_site(pos: Vector3) -> void:
	var site := Node3D.new()
	site.position = pos
	site.set_script(BuildSiteScript)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.1, 2.0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Marker"
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, 0.05, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.55)
	mesh_instance.material_override = material
	site.add_child(mesh_instance)

	add_child(site)

func _spawn_animal(pos: Vector3, animal_data: Dictionary) -> void:
	var animal := CharacterBody3D.new()
	animal.position = pos
	animal.set_script(AnimalScript)

	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 0.6, 0)
	animal.add_child(collision)

	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.2
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, 0.6, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(animal_data["color"])
	mesh_instance.material_override = material
	animal.add_child(mesh_instance)

	var nav_agent := NavigationAgent3D.new()
	nav_agent.name = "NavigationAgent3D"
	animal.add_child(nav_agent)

	animal.animal_id = animal_data["id"]
	animal.aggressive = animal_data.get("aggressive", false)
	animal.move_speed = animal_data.get("move_speed", 1.5)
	animal.wander_radius = animal_data.get("wander_radius", 4.0)
	animal.notice_radius = animal_data.get("notice_radius", 4.0)
	animal.pet_radius = animal_data.get("pet_radius", 1.5)
	animal.chase_radius = animal_data.get("chase_radius", 6.0)
	animal.chase_speed = animal_data.get("chase_speed", 3.0)
	animal.catch_radius = animal_data.get("catch_radius", 1.2)
	animal.give_up_time = animal_data.get("give_up_time", 8.0)
	animal.energy_drain_on_hit = animal_data.get("energy_drain_on_hit", 15.0)
	animal.knockback_force = animal_data.get("knockback_force", 6.0)
	animal.flee_speed = animal_data.get("flee_speed", 4.0)
	animal.flee_duration = animal_data.get("flee_duration", 4.0)
	animal.horn_radius = animal_data.get("horn_radius", 6.0)
	animal.horn_cooldown = animal_data.get("horn_cooldown", 3.0)

	add_child(animal)

func _spawn_unknown(pos: Vector3, ch: String, row: int, col: int) -> void:
	push_warning("level_loader: unknown map character '%s' at row %d, col %d" % [ch, row, col])
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 1.0, 2.0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = pos + Vector3(0, 0.5, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.2, 0.8)
	mesh_instance.material_override = material
	add_child(mesh_instance)
