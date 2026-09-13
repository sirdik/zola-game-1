# Procedurally generated forest maps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a random, always-playable 60×60 forest map once per save, in the same text format hand-authored maps already use, so the existing level-loading code needs almost no changes.

**Architecture:** A new pure-logic `game/world/map_generator.gd` (a `RefCounted`, no scene-tree dependency) builds a grid of map characters plus a `[legend]` section and serializes it to text identical to `levels/forest_01.txt`'s format. The `Game` autoload creates that text once per save (`user://generated_forest.txt`) and deletes it on reset; `game/world/level_loader.gd` gains a two-line addition to prefer that file when present. The existing parsing/spawning pipeline in `level_loader.gd` is otherwise untouched.

**Tech Stack:** Godot 4.7.2, GDScript with static typing, no automated test framework — verification is a headless boot plus a throwaway invariant-checking probe (deleted after use), per this project's established convention.

**Spec:** `docs/superpowers/specs/2026-09-13-generated-maps.md`

## Global Constraints

- Map size: 60×60 tiles.
- Distance metric throughout: Chebyshev tile distance (`max(|dx|, |dy|)`).
- Density/count constants (starting values, not exact promises — expect tuning after playtest): tree+rock combined density 15% (60% of those trees, 40% rocks), food density 4%, exactly 45 kostičky, animals 2 fox / 2 wolf / 2 deer / 1 bear (read species generically via `Animals.all_ids()`, with a lookup table for counts and a default of 1 for any future species not in that table).
- Player spawn: random tile in the middle third of the grid on both axes.
- Campfire: 8–20 tiles from spawn.
- Each building's build site: at least 12 tiles from spawn, the campfire, and every other building already placed.
- Each building's blueprint: 5–15 tiles from its own build site.
- Animals: at least 10 tiles from spawn.
- All three buildings (house, tower, castle) and their blueprints must always exist and always be reachable — guaranteed by a BFS connectivity check from spawn; if it fails, or if any placement step exhausts its retries, the whole generation attempt is discarded and retried (up to 20 times at full density, then retried again with density halved each further attempt until one succeeds).
- The generated map is persisted (`user://generated_forest.txt`), not regenerated from a stored seed — regenerating from a seed after a future generator-algorithm change would silently produce a different map than the one already explored/built on.
- `level_loader.gd`'s existing parsing/spawning code (`_read_grid_lines`, `_read_legend`, `_lookup_building_id`, every `_spawn_*` function) must not change at all — only path resolution at the very top of `_ready()` changes.
- Never run a test that mutates the real `user://savegame.json` or that calls `Game.reset_save()` against real data — this project has a standing, previously-learned caution about that (see `_ensure_map_exists()`'s behavior below, which is safe: it only ever *creates* a file that doesn't yet exist, and `reset_save()` is only ever invoked by a button press, never by booting).

---

## File Structure

- **Create `game/world/map_generator.gd`**: the entire generation algorithm — grid setup, all placement steps, the connectivity check, retry loop, and text serialization. No dependency on the scene tree; callable as `MapGenerator.generate() -> String`.
- **Modify `project.godot`**: reorder the `[autoload]` list so `Game` loads after `Items` and `Animals` (see Task 2 — `Game` will indirectly need both, and today's order doesn't guarantee that).
- **Modify `game/autoload/game.gd`**: create the generated map file once per save; delete it on reset.
- **Modify `game/world/level_loader.gd`**: prefer the generated map file when it exists.

---

### Task 1: Map generator

**Files:**
- Create: `game/world/map_generator.gd`

**Interfaces:**
- Consumes: `Items.all_ids()` / `Items.get_by_id(id)` (existing autoload, returns `Array[String]` / `Dictionary` with at least `"map_char"` and `"edible"` keys where present) and `Animals.all_ids()` / `Animals.get_by_id(id)` (existing autoload, same shape, `"map_char"` key) — both already exist and are unaffected by this plan.
- Produces: `static func generate() -> String` — the only entry point later tasks call. Returns a complete, ready-to-write map file (grid rows + blank line + `[legend]` section) that always passes its own internal connectivity guarantee.

- [ ] **Step 1: Create `game/world/map_generator.gd` with the full implementation**

```gdscript
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
	var width := randi_range(4, 8)
	var height := randi_range(4, 10)
	for attempt in PLACEMENT_RETRIES:
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

static func _is_fully_connected(grid: Array[PackedStringArray], spawn: Vector2i, required: Array[Vector2i]) -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [spawn]
	visited[spawn] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_pos := current + offset
			if next_pos.x < 0 or next_pos.x >= MAP_SIZE or next_pos.y < 0 or next_pos.y >= MAP_SIZE:
				continue
			if visited.has(next_pos):
				continue
			var ch: String = grid[next_pos.y][next_pos.x]
			if ch == TREE or ch == ROCK or ch == WATER:
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
```

A few things worth understanding before moving on:
- Build sites and blueprints are TWO adjacent tiles, not one: `level_loader.gd`'s `_lookup_building_id` reads the digit from `line[col + 1]` (the tile immediately to the right of the `S`/`H` character) — that's why `_marker_free`/`_place_marker` always reserve and write two horizontal cells, and why `_pick_marker_near`/`_pick_marker_far_from_all` cap their random X coordinate at `MAP_SIZE - 2` (so `col + 1` is always in bounds).
- There is no separate "occupied" tracking structure — every placement writes directly into `grid`, and `_tile_free`/`_marker_free` check `grid[y][x] == EMPTY` directly. This was verified safe with a throwaway spike during design: GDScript's `grid[row][col] = value` correctly mutates a `PackedStringArray` nested inside an `Array[PackedStringArray]` in place (despite `PackedStringArray` normally being a value type) — the nested-subscript-assignment form handles this correctly.
- `generate()`'s `while true` loop has no code path after it — that's intentional; the density-halving fallback is mathematically guaranteed to eventually produce zero density (trivially fully connected), so the function always returns from inside the loop.

- [ ] **Step 2: Create a throwaway verification probe**

Create `_map_gen_probe/probe.gd`:

```gdscript
extends Node

const MapGenerator := preload("res://game/world/map_generator.gd")

func _ready() -> void:
	var failures := 0
	for trial in 20:
		var text := MapGenerator.generate()
		var lines := text.split("\n")
		var grid_lines: Array[String] = []
		for line in lines:
			if line.begins_with(";") or line.strip_edges() == "" or line.begins_with("[legend]"):
				if line.begins_with("[legend]"):
					break
				continue
			grid_lines.append(line)

		if grid_lines.size() != 60:
			print("FAIL trial ", trial, ": expected 60 grid rows, got ", grid_lines.size())
			failures += 1
			continue

		var p_count := 0
		var k_count := 0
		var spawn_row_bad := false
		for row in grid_lines.size():
			var line: String = grid_lines[row]
			if line.length() != 60:
				print("FAIL trial ", trial, ": row ", row, " has length ", line.length(), " expected 60")
				failures += 1
				spawn_row_bad = true
			p_count += line.count("P")
			k_count += line.count("k")
		if spawn_row_bad:
			continue

		if p_count != 1:
			print("FAIL trial ", trial, ": expected exactly 1 'P', found ", p_count)
			failures += 1
		if k_count != 45:
			print("FAIL trial ", trial, ": expected exactly 45 'k', found ", k_count)
			failures += 1

		for token in ["S1", "H1", "S2", "H2", "S3", "H3"]:
			var found := false
			for row in grid_lines.size():
				var line: String = grid_lines[row]
				var idx := line.find(token[0])
				while idx != -1 and idx + 1 < line.length():
					if line[idx + 1] == token[1]:
						found = true
						break
					idx = line.find(token[0], idx + 1)
				if found:
					break
			if not found:
				print("FAIL trial ", trial, ": token ", token, " not found in grid")
				failures += 1

		var legend_section := text.split("[legend]")
		if legend_section.size() != 2:
			print("FAIL trial ", trial, ": no [legend] section found")
			failures += 1
		else:
			for token in ["S1", "H1", "S2", "H2", "S3", "H3"]:
				if not legend_section[1].contains(token):
					print("FAIL trial ", trial, ": legend missing entry for ", token)
					failures += 1

	if failures == 0:
		print("ALL 20 TRIALS PASSED")
	else:
		print("TOTAL FAILURES: ", failures)
	get_tree().quit()
```

Create `_map_gen_probe/Probe.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://_map_gen_probe/probe.gd" id="1"]

[node name="Probe" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: Run the probe and verify it passes**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . _map_gen_probe/Probe.tscn --quit`

Expected: the last two lines of output are `ALL 20 TRIALS PASSED` and no `SCRIPT ERROR`/`Parse Error` anywhere. If any trial fails, read the specific failure message, fix `map_generator.gd`, and re-run — do not proceed with failures.

This does not run inside the real game scene and does not touch `user://generated_forest.txt` or `user://savegame.json` at all, so there is no concurrency risk with the user's own Godot session.

- [ ] **Step 4: Delete the throwaway probe**

```bash
rm -rf _map_gen_probe
```

- [ ] **Step 5: Commit**

```bash
git add game/world/map_generator.gd
git commit -m "Add procedural forest map generator"
```

---

### Task 2: Save integration — generate and persist the map once per save

**Files:**
- Modify: `project.godot` (autoload order)
- Modify: `game/autoload/game.gd`

**Interfaces:**
- Consumes: `MapGenerator.generate() -> String` from Task 1.
- Produces: `Game.MAP_PATH` (a `const String`, value `"user://generated_forest.txt"`) — Task 3 references this constant directly rather than duplicating the path string.

- [ ] **Step 1: Reorder autoloads in `project.godot`**

`Game._ready()` will (after this task) call `MapGenerator.generate()`, which reads `Animals.all_ids()`/`Animals.get_by_id()`. Autoloads initialize before the main scene, but among themselves they initialize in the order `project.godot` lists them — today `Animals` is listed AFTER `Game`, so at the moment `Game._ready()` currently runs, `Animals` exists as an object but hasn't run its own `_ready()` yet, meaning `Animals.all_ids()` would return an empty array and every generated map would silently have zero animals. (`Items` already comes before `Game` today, which is why `Game._ready()` can already safely call `Items.all_ids()` — this is the same class of dependency, just currently unsatisfied for `Animals`.)

Find this block in `project.godot`:

```
[autoload]

Items="*res://game/autoload/items.gd"
Game="*res://game/autoload/game.gd"
Recipes="*res://game/autoload/recipes.gd"
Animals="*res://game/autoload/animals.gd"
```

Change it to:

```
[autoload]

Items="*res://game/autoload/items.gd"
Animals="*res://game/autoload/animals.gd"
Recipes="*res://game/autoload/recipes.gd"
Game="*res://game/autoload/game.gd"
```

(`Game` now loads last among these four, after every data autoload it might ever need — `Items` and `Animals` today, safely covering any future addition too.)

- [ ] **Step 2: Add map generation/persistence to `game/autoload/game.gd`**

At the top of the file, add the preload and a new constant, alongside the existing ones:

```gdscript
extends Node

const MapGenerator := preload("res://game/world/map_generator.gd")

signal inventory_changed(item_id: String)
signal energy_changed(value: float)

const MAX_ENERGY := 100.0
const SAVE_PATH := "user://savegame.json"
const MAP_PATH := "user://generated_forest.txt"
const SAVE_INTERVAL := 2.0
```

Change `_ready()` from:

```gdscript
func _ready() -> void:
	for id in Items.all_ids():
		_inventory[id] = 0
	_load()
```

to:

```gdscript
func _ready() -> void:
	for id in Items.all_ids():
		_inventory[id] = 0
	_ensure_map_exists()
	_load()
```

Add a new function (placement in the file doesn't matter — e.g. right after `_ready()`):

```gdscript
func _ensure_map_exists() -> void:
	if FileAccess.file_exists(MAP_PATH):
		return
	var map_text := MapGenerator.generate()
	var file := FileAccess.open(MAP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("game: could not write generated map at %s" % MAP_PATH)
		return
	file.store_string(map_text)
	file.close()
```

This only ever *creates* a file that doesn't already exist — it never reads, mutates, or deletes existing data, so it carries none of the risk this project's save-testing-isolation lesson warns about.

Change `reset_save()` from:

```gdscript
func reset_save() -> void:
	energy = MAX_ENERGY
	for id in _inventory.keys():
		_inventory[id] = 0
	_unlocked_buildings.clear()
	_building_progress.clear()
	_dirty = false
	_save_timer = 0.0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	energy_changed.emit(energy)
	for id in _inventory.keys():
		inventory_changed.emit(id)
```

to (one new block added after the existing `SAVE_PATH` deletion):

```gdscript
func reset_save() -> void:
	energy = MAX_ENERGY
	for id in _inventory.keys():
		_inventory[id] = 0
	_unlocked_buildings.clear()
	_building_progress.clear()
	_dirty = false
	_save_timer = 0.0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(MAP_PATH):
		DirAccess.remove_absolute(MAP_PATH)
	energy_changed.emit(energy)
	for id in _inventory.keys():
		inventory_changed.emit(id)
```

`DirAccess.remove_absolute()` on a `user://` path was already verified to work correctly in an earlier session of this project (see the project's own Godot-gotchas notes) — no need to re-verify that specific API call.

- [ ] **Step 3: Verify with a headless boot**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`

Expected: no `SCRIPT ERROR`/`Parse Error`. This boot will call `Game._ready()` for real, which will create a real `user://generated_forest.txt` if one doesn't already exist on this machine. This is safe: it's a brand-new file this project has never created before now, so there's no existing user data it could race or overwrite (unlike `user://savegame.json`, which already holds real accumulated progress and must never be touched by a test — this task's code never touches `SAVE_PATH` at all, and `reset_save()`'s new line only ever fires on an explicit button press in the running game, never during a passive boot-and-quit).

- [ ] **Step 4: Commit**

```bash
git add project.godot game/autoload/game.gd
git commit -m "Generate and persist a procedural map once per save"
```

---

### Task 3: level_loader.gd — prefer the generated map when present

**Files:**
- Modify: `game/world/level_loader.gd`

**Interfaces:**
- Consumes: `Game.MAP_PATH` (from Task 2).
- Produces: nothing consumed by other tasks — this is the last task in the plan.

- [ ] **Step 1: Change the top of `_ready()`**

`game/world/level_loader.gd`'s `_ready()` currently starts:

```gdscript
func _ready() -> void:
	var lines := _read_grid_lines(level_path)
	if lines.is_empty():
		push_warning("level_loader: no grid lines found in %s" % level_path)
		return

	var legend := _read_legend(level_path)
```

Change it to:

```gdscript
func _ready() -> void:
	var effective_level_path := level_path
	if FileAccess.file_exists(Game.MAP_PATH):
		effective_level_path = Game.MAP_PATH

	var lines := _read_grid_lines(effective_level_path)
	if lines.is_empty():
		push_warning("level_loader: no grid lines found in %s" % effective_level_path)
		return

	var legend := _read_legend(effective_level_path)
```

Nothing else in `_ready()` — or anywhere else in the file — changes. `level_path` (the `@export`ed default, `res://levels/forest_01.txt`) is left completely alone as a fallback: it's still what gets used if `user://generated_forest.txt` doesn't exist yet, and it's still there as a hand-tunable reference map for future development.

- [ ] **Step 2: Verify with a headless boot**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`

Expected: no `SCRIPT ERROR`/`Parse Error`. By this point in the plan, `user://generated_forest.txt` already exists on this machine (created during Task 2's own verification boot), so this boot naturally exercises the real end-to-end path: `Game` creates/reuses the generated map, `level_loader.gd` picks it up, and the entire existing spawn pipeline (trees, rocks, water, campfire, all three buildings, food, blocks, animals) runs against a fully procedurally generated 60×60 map for the first time. A second consecutive boot should show identical behavior (the file already exists, so it's reused, not regenerated) — running the boot command twice in a row and confirming no errors either time is a reasonable quick confirmation, though not a strict requirement of this step.

- [ ] **Step 3: Commit**

```bash
git add game/world/level_loader.gd
git commit -m "Use the generated forest map when one exists"
```

---

## Manual Playtest Follow-Up (not automatable)

After all three tasks land, ask the user to check:

1. Does a generated map actually appear (noticeably different from the old hand-authored `forest_01.txt` — much bigger, laid out differently)?
2. Are the house, tower, and castle build sites and blueprints all findable and not absurdly far apart or annoyingly close together?
3. Does traversal across the bigger map feel OK at the current move speed, or does it feel like a slog (a move-speed tuning follow-up was explicitly deferred in the spec if so)?
4. Does pressing "Nová hra" produce a genuinely different map layout on the next load?
5. Do animal encounters (2 fox/2 wolf/2 deer/1 bear) feel reasonably spread out rather than clustered?
6. General density feel — trees/rocks/food/kostičky — too sparse, too cluttered, or about right?

None of this is verifiable headlessly; the density/count/distance constants in this plan are explicitly starting values expected to need a tuning pass after this feedback, the same way the low-poly visual style's model-scale table did.

## Self-Review

**Spec coverage:** Every numbered step in the spec's "Generation algorithm" section (grid init, spawn, campfire, buildings with the two-tile marker convention, water, trees/rocks, food, blocks, animals, connectivity check + retry) maps directly onto `map_generator.gd`'s functions in Task 1, using the same constants and distances. "Text format emission" is covered by `_serialize()`. "Save integration" (persist-not-seed, `Game._ready()`/`reset_save()` changes) is Task 2. `level_loader.gd`'s one small addition is Task 3. No spec section lacks a task.

**Placeholder scan:** No TBD/TODO. Every code block is complete, runnable GDScript or exact JSON/`project.godot` text, not a description of what to write.

**Type consistency:** `Array[PackedStringArray]` is the grid type used consistently across every function signature in Task 1 that touches it (`_make_empty_grid`'s return type, `_tile_free`, `_marker_free`, `_place_marker`, `_carve_water`, `_scatter_trees_and_rocks`, `_scatter_food`, `_scatter_blocks`, `_scatter_animals`, `_is_fully_connected`, `_serialize`). `Vector2i(-1, -1)` is the consistent "placement failed" sentinel returned by every `_pick_*` function and checked the same way by every caller. `Game.MAP_PATH` is defined once (Task 2) and referenced, not redefined, in Task 3.

**A dependency-ordering bug caught during planning, not left to a subagent to discover:** `project.godot`'s existing autoload order lists `Animals` after `Game`, which would have made every generated map's animal population silently empty (no error, no crash — `Animals.all_ids()` would just return `[]` before `Animals._ready()` runs). Task 2 fixes this by reordering autoloads so `Game` loads last. This is exactly the kind of cross-cutting issue a plan should resolve up front rather than let a fix-loop discover later.
