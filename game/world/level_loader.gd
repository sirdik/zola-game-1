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

const ROCK_MODELS: Array[Dictionary] = [
	{"path": "res://assets/models/nature/rock_smallA.glb", "scale": 3.2},
	{"path": "res://assets/models/nature/rock_smallD.glb", "scale": 3.2},
	{"path": "res://assets/models/nature/rock_largeA.glb", "scale": 2.0},
	{"path": "res://assets/models/nature/rock_largeD.glb", "scale": 2.0},
]

const TREE_MODELS: Array[Dictionary] = [
	{"path": "res://assets/models/nature/tree_pineRoundA.glb", "scale": 1.9},
	{"path": "res://assets/models/nature/tree_pineRoundC.glb", "scale": 1.9},
	{"path": "res://assets/models/nature/tree_pineTallA.glb", "scale": 1.75},
	{"path": "res://assets/models/nature/tree_pineTallC.glb", "scale": 1.75},
]

const DECORATION_MODELS: Array[Dictionary] = [
	{"path": "res://assets/models/nature/mushroom_red.glb", "scale": 1.5},
	{"path": "res://assets/models/nature/mushroom_tan.glb", "scale": 1.5},
	{"path": "res://assets/models/nature/flower_purpleA.glb", "scale": 1.5},
	{"path": "res://assets/models/nature/flower_redA.glb", "scale": 1.5},
	{"path": "res://assets/models/nature/flower_yellowA.glb", "scale": 1.5},
	{"path": "res://assets/models/nature/plant_bushSmall.glb", "scale": 1.3},
	{"path": "res://assets/models/nature/log.glb", "scale": 1.2},
]

@export var level_path: String = "res://levels/forest_01.txt"
@export var player_paths: Array[NodePath] = [NodePath("../Player1"), NodePath("../Player2")]

func _ready() -> void:
	var effective_level_path := level_path
	if FileAccess.file_exists(Game.MAP_PATH):
		effective_level_path = Game.MAP_PATH

	var lines := _read_grid_lines(effective_level_path)
	if lines.is_empty():
		push_warning("level_loader: no grid lines found in %s" % effective_level_path)
		return

	var legend := _read_legend(effective_level_path)

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
				"*":
					_spawn_decoration(world_pos)
				"S":
					_spawn_build_site(world_pos, _lookup_building_id(line, col, "S", legend))
				"H":
					_spawn_blueprint(world_pos, _lookup_building_id(line, col, "H", legend))
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
		for i in player_paths.size():
			var player := get_node_or_null(player_paths[i])
			if player is Node3D:
				player.global_position = player_spawn_pos + Vector3(0, 0.05, 0) + Vector3(i * 1.0, 0.0, 0.0)

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

func _read_legend(path: String) -> Dictionary:
	var legend: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return legend
	var content := file.get_as_text()
	file.close()

	var in_legend := false
	for raw_line: String in content.split("\n"):
		var line: String = raw_line.replace("\r", "").strip_edges()
		if line.begins_with(";") or line == "":
			continue
		if line.begins_with("[legend]"):
			in_legend = true
			continue
		if not in_legend:
			continue
		var eq_index := line.find("=")
		if eq_index < 0:
			continue
		var token := line.substr(0, eq_index).strip_edges()
		var rest := line.substr(eq_index + 1)
		var building_index := rest.find("building=")
		if building_index < 0:
			continue
		var building_id := rest.substr(building_index + "building=".length()).strip_edges()
		legend[token] = building_id
	return legend

func _lookup_building_id(line: String, col: int, prefix: String, legend: Dictionary) -> String:
	if col + 1 < line.length() and "0123456789".contains(line[col + 1]):
		var token := prefix + line[col + 1]
		if legend.has(token):
			return legend[token]
		push_warning("level_loader: no legend entry for '%s', defaulting to 'house'" % token)
	return "house"

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

	_add_random_model(body, ROCK_MODELS)

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

	_add_random_model(body, TREE_MODELS)

func _add_random_model(parent: Node3D, models: Array[Dictionary]) -> void:
	var choice: Dictionary = models[randi() % models.size()]
	var scene: PackedScene = load(choice["path"])
	var instance: Node3D = scene.instantiate()
	instance.scale = Vector3.ONE * float(choice["scale"])
	instance.rotation.y = randf_range(0.0, TAU)
	parent.add_child(instance)

func _spawn_decoration(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	_add_random_model(holder, DECORATION_MODELS)

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

func _spawn_build_site(pos: Vector3, building_id: String) -> void:
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

	site.building_id = building_id
	site.data_path = "res://data/%s.txt" % building_id

	add_child(site)

func _spawn_blueprint(pos: Vector3, building_id: String) -> void:
	var item_data := Items.get_by_id("blueprint_%s" % building_id)
	if item_data.is_empty():
		push_warning("level_loader: no blueprint item defined for building '%s'" % building_id)
		return
	_spawn_pickup(pos, item_data)

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

	var color := Color.html(animal_data["color"])
	var model_path: String = animal_data.get("model_path", "")
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		var model: Node3D = model_scene.instantiate()
		model.name = "Mesh"
		model.position = Vector3.ZERO
		model.rotation.y = PI
		model.scale = Vector3.ONE * float(animal_data.get("model_scale", 1.0))
		animal.add_child(model)
	else:
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.4
		mesh.height = 1.2
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = mesh
		mesh_instance.position = Vector3(0, 0.6, 0)
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		mesh_instance.material_override = material
		animal.add_child(mesh_instance)
		_add_animal_features(animal, animal_data.get("shape", "generic"), color)

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

func _add_animal_features(animal: CharacterBody3D, shape_name: String, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color

	var head_radius := 0.32 if shape_name == "bear" else 0.24
	var head_mesh := SphereMesh.new()
	head_mesh.radius = head_radius
	head_mesh.height = head_radius * 2.0
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.position = Vector3(0, 1.0, -0.35)
	head.material_override = material
	animal.add_child(head)

	match shape_name:
		"fox":
			_add_cone_ears(animal, material, 0.08, 0.16)
			_add_tail(animal, material)
		"wolf":
			_add_cone_ears(animal, material, 0.09, 0.2)
		"deer":
			_add_cone_ears(animal, material, 0.06, 0.14)
			_add_antlers(animal, material)
		"bear":
			_add_round_ears(animal, material)

func _add_cone_ears(animal: CharacterBody3D, material: StandardMaterial3D, radius: float, height: float) -> void:
	for side in [-1.0, 1.0]:
		var ear_mesh := CylinderMesh.new()
		ear_mesh.top_radius = 0.0
		ear_mesh.bottom_radius = radius
		ear_mesh.height = height
		var ear := MeshInstance3D.new()
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.13, 1.22, -0.35)
		ear.material_override = material
		animal.add_child(ear)

func _add_round_ears(animal: CharacterBody3D, material: StandardMaterial3D) -> void:
	for side in [-1.0, 1.0]:
		var ear_mesh := SphereMesh.new()
		ear_mesh.radius = 0.1
		ear_mesh.height = 0.2
		var ear := MeshInstance3D.new()
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.22, 1.18, -0.3)
		ear.material_override = material
		animal.add_child(ear)

func _add_tail(animal: CharacterBody3D, material: StandardMaterial3D) -> void:
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.04
	tail_mesh.bottom_radius = 0.14
	tail_mesh.height = 0.5
	var tail := MeshInstance3D.new()
	tail.mesh = tail_mesh
	tail.position = Vector3(0, 0.75, 0.55)
	tail.rotation = Vector3(deg_to_rad(-55.0), 0.0, 0.0)
	tail.material_override = material
	animal.add_child(tail)

func _add_antlers(animal: CharacterBody3D, material: StandardMaterial3D) -> void:
	for side in [-1.0, 1.0]:
		var antler_mesh := CylinderMesh.new()
		antler_mesh.top_radius = 0.0
		antler_mesh.bottom_radius = 0.04
		antler_mesh.height = 0.35
		var antler := MeshInstance3D.new()
		antler.mesh = antler_mesh
		antler.position = Vector3(side * 0.15, 1.3, -0.35)
		antler.rotation = Vector3(0.0, 0.0, deg_to_rad(side * -20.0))
		antler.material_override = material
		animal.add_child(antler)

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
