extends RefCounted

const MAP_SIZE := 60
const TREE_ROCK_DENSITY := 0.15
const TREE_FRACTION := 0.6
const FOOD_DENSITY := 0.04
const BLOCK_COUNT := 45
const CAMPFIRE_MIN_DIST := 8
const CAMPFIRE_MAX_DIST := 20
const BUILDING_MIN_DIST := 12
const BLUEPRINT_MIN_DIST := 5
const BLUEPRINT_MAX_DIST := 15
const ANIMAL_MIN_DIST_FROM_SPAWN := 10
const HORN_MIN_DIST_FROM_SPAWN := 10
const PLACEMENT_RETRIES := 50
const MAX_FULL_RETRIES := 20

const BUILDINGS: Array[String] = ["house", "tower", "castle"]
const ANIMAL_COUNTS := {"fox": 2, "wolf": 2, "deer": 2, "bear": 1}
const DEFAULT_ANIMAL_COUNT := 1

const EMPTY := "."
const TREE := "T"
const ROCK := "#"
const WATER := "~"
const PLAYER_SPAWN := "P"
const CAMPFIRE := "F"
const BLUEPRINT := "H"
const BUILD_SITE := "S"
const BLOCK := "k"
const HORN := "!"

static func generate() -> String:
	var density := TREE_ROCK_DENSITY
	var attempt := 0
	while true:
		var result := _try_generate(density)
		if result != "":
			return result
		attempt += 1
		if attempt >= MAX_FULL_RETRIES:
			density *= 0.5
	return ""

static func _try_generate(tree_rock_density: float) -> String:
	var grid := _make_empty_grid()
	_add_border(grid)

	var spawn := _pick_spawn_tile()
	grid[spawn.y][spawn.x] = PLAYER_SPAWN

	var campfire := _pick_tile_near(spawn, CAMPFIRE_MIN_DIST, CAMPFIRE_MAX_DIST, grid)
	if campfire == Vector2i(-1, -1):
		return ""
	grid[campfire.y][campfire.x] = CAMPFIRE

	var legend_lines: Array[String] = []
	var anchor_points: Array[Vector2i] = [spawn, campfire]
	var required_reachable: Array[Vector2i] = [campfire]

	for i in BUILDINGS.size():
		var building_id: String = BUILDINGS[i]
		var token_digit := str(i + 1)

		var site_pos := _pick_marker_far_from_all(anchor_points, BUILDING_MIN_DIST, grid)
		if site_pos == Vector2i(-1, -1):
			return ""
		_place_marker(grid, site_pos, BUILD_SITE, token_digit)
		anchor_points.append(site_pos)
		required_reachable.append(site_pos)

		var blueprint_pos := _pick_marker_near(site_pos, BLUEPRINT_MIN_DIST, BLUEPRINT_MAX_DIST, grid)
		if blueprint_pos == Vector2i(-1, -1):
			return ""
		_place_marker(grid, blueprint_pos, BLUEPRINT, token_digit)
		anchor_points.append(blueprint_pos)
		required_reachable.append(blueprint_pos)

		legend_lines.append("%s%s = build_site building=%s" % [BUILD_SITE, token_digit, building_id])
		legend_lines.append("%s%s = blueprint  building=%s" % [BLUEPRINT, token_digit, building_id])

	var horn_pos := _pick_tile_near(spawn, HORN_MIN_DIST_FROM_SPAWN, MAP_SIZE, grid)
	if horn_pos == Vector2i(-1, -1):
		return ""
	grid[horn_pos.y][horn_pos.x] = HORN
	required_reachable.append(horn_pos)

	_carve_water(grid)
	_scatter_trees_and_rocks(grid, tree_rock_density)
	_scatter_food(grid)
	_scatter_blocks(grid)
	_scatter_animals(grid, spawn)

	if not _is_fully_connected(grid, spawn, required_reachable):
		return ""

	return _serialize(grid, legend_lines)

static func _make_empty_grid() -> Array[PackedStringArray]:
	var grid: Array[PackedStringArray] = []
	for row in MAP_SIZE:
		var cells := PackedStringArray()
		cells.resize(MAP_SIZE)
		cells.fill(EMPTY)
		grid.append(cells)
	return grid

static func _add_border(grid: Array[PackedStringArray]) -> void:
	for i in MAP_SIZE:
		grid[0][i] = ROCK
		grid[MAP_SIZE - 1][i] = ROCK
		grid[i][0] = ROCK
		grid[i][MAP_SIZE - 1] = ROCK

static func _tile_free(grid: Array[PackedStringArray], pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= MAP_SIZE or pos.y < 0 or pos.y >= MAP_SIZE:
		return false
	return grid[pos.y][pos.x] == EMPTY

static func _marker_free(grid: Array[PackedStringArray], pos: Vector2i) -> bool:
	if pos.x + 1 >= MAP_SIZE:
		return false
	return _tile_free(grid, pos) and _tile_free(grid, Vector2i(pos.x + 1, pos.y))

static func _place_marker(grid: Array[PackedStringArray], pos: Vector2i, letter: String, digit: String) -> void:
	grid[pos.y][pos.x] = letter
	grid[pos.y][pos.x + 1] = digit

static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

static func _pick_spawn_tile() -> Vector2i:
	var low := MAP_SIZE / 3
	var high := MAP_SIZE * 2 / 3
	return Vector2i(randi_range(low, high), randi_range(low, high))

static func _pick_tile_near(anchor: Vector2i, min_dist: int, max_dist: int, grid: Array[PackedStringArray]) -> Vector2i:
	for attempt in PLACEMENT_RETRIES:
		var candidate := Vector2i(randi_range(0, MAP_SIZE - 1), randi_range(0, MAP_SIZE - 1))
		var dist := _chebyshev(candidate, anchor)
		if dist >= min_dist and dist <= max_dist and _tile_free(grid, candidate):
			return candidate
	return Vector2i(-1, -1)

static func _pick_marker_near(anchor: Vector2i, min_dist: int, max_dist: int, grid: Array[PackedStringArray]) -> Vector2i:
	for attempt in PLACEMENT_RETRIES:
		var candidate := Vector2i(randi_range(0, MAP_SIZE - 2), randi_range(0, MAP_SIZE - 1))
		var dist := _chebyshev(candidate, anchor)
		if dist >= min_dist and dist <= max_dist and _marker_free(grid, candidate):
			return candidate
	return Vector2i(-1, -1)

static func _pick_marker_far_from_all(anchors: Array[Vector2i], min_dist: int, grid: Array[PackedStringArray]) -> Vector2i:
	for attempt in PLACEMENT_RETRIES:
		var candidate := Vector2i(randi_range(0, MAP_SIZE - 2), randi_range(0, MAP_SIZE - 1))
		if not _marker_free(grid, candidate):
			continue
		var far_enough := true
		for anchor in anchors:
			if _chebyshev(candidate, anchor) < min_dist:
				far_enough = false
				break
		if far_enough:
			return candidate
	return Vector2i(-1, -1)

static func _carve_water(grid: Array[PackedStringArray]) -> void:
	for attempt in PLACEMENT_RETRIES:
		var width := randi_range(4, 8)
		var height := randi_range(4, 10)
		var origin := Vector2i(randi_range(0, MAP_SIZE - width), randi_range(0, MAP_SIZE - height))
		var fits := true
		for y in range(origin.y, origin.y + height):
			for x in range(origin.x, origin.x + width):
				if not _tile_free(grid, Vector2i(x, y)):
					fits = false
					break
			if not fits:
				break
		if fits:
			for y in range(origin.y, origin.y + height):
				for x in range(origin.x, origin.x + width):
					grid[y][x] = WATER
			return
	# No free rectangle found after all retries — not fatal, water is decoration,
	# not one of the connectivity check's required reachable points.

static func _scatter_trees_and_rocks(grid: Array[PackedStringArray], density: float) -> void:
	for row in MAP_SIZE:
		for col in MAP_SIZE:
			var pos := Vector2i(col, row)
			if not _tile_free(grid, pos):
				continue
			if randf() < density:
				grid[row][col] = TREE if randf() < TREE_FRACTION else ROCK

static func _get_food_chars() -> Array[String]:
	var chars: Array[String] = []
	for id in Items.all_ids():
		if id == "water":
			continue
		var data := Items.get_by_id(id)
		if data.get("edible", true) and data.has("map_char"):
			chars.append(data["map_char"])
	return chars

static func _scatter_food(grid: Array[PackedStringArray]) -> void:
	var food_chars := _get_food_chars()
	if food_chars.is_empty():
		return
	for row in MAP_SIZE:
		for col in MAP_SIZE:
			var pos := Vector2i(col, row)
			if not _tile_free(grid, pos):
				continue
			if randf() < FOOD_DENSITY:
				grid[row][col] = food_chars[randi() % food_chars.size()]

static func _scatter_blocks(grid: Array[PackedStringArray]) -> void:
	var placed := 0
	var attempts := 0
	var max_attempts := BLOCK_COUNT * 20
	while placed < BLOCK_COUNT and attempts < max_attempts:
		attempts += 1
		var pos := Vector2i(randi_range(0, MAP_SIZE - 1), randi_range(0, MAP_SIZE - 1))
		if _tile_free(grid, pos):
			grid[pos.y][pos.x] = BLOCK
			placed += 1

static func _scatter_animals(grid: Array[PackedStringArray], spawn: Vector2i) -> void:
	for animal_id in Animals.all_ids():
		var data := Animals.get_by_id(animal_id)
		if not data.has("map_char"):
			continue
		var ch: String = data["map_char"]
		var count: int = ANIMAL_COUNTS.get(animal_id, DEFAULT_ANIMAL_COUNT)
		for i in count:
			var pos := _pick_tile_near(spawn, ANIMAL_MIN_DIST_FROM_SPAWN, MAP_SIZE, grid)
			if pos != Vector2i(-1, -1):
				grid[pos.y][pos.x] = ch
			else:
				push_warning("map_generator: could not place an instance of '%s', skipping" % animal_id)

static func _is_fully_connected(grid: Array[PackedStringArray], spawn: Vector2i, required: Array[Vector2i]) -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [spawn]
	visited[spawn] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_pos := current + offset
			if next_pos.x < 0 or next_pos.x >= MAP_SIZE or next_pos.y < 0 or next_pos.y >= MAP_SIZE:
				continue
			if visited.has(next_pos):
				continue
			var ch: String = grid[next_pos.y][next_pos.x]
			if ch == TREE or ch == ROCK or ch == WATER:
				# Water has no collider in level_loader.gd (it's walkable in-game),
				# but we treat it as blocking here anyway — a deliberately
				# conservative simplification, not a bug.
				continue
			visited[next_pos] = true
			queue.append(next_pos)
	for pos in required:
		if not visited.has(pos):
			return false
	return true

static func _serialize(grid: Array[PackedStringArray], legend_lines: Array[String]) -> String:
	var lines: Array[String] = []
	lines.append("; Generated forest")
	for row_cells in grid:
		lines.append("".join(row_cells))
	lines.append("")
	lines.append("[legend]")
	for legend_line in legend_lines:
		lines.append(legend_line)
	return "\n".join(lines)
