# Krok 5: Kostičky a stavby Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build roadmap step 5 from CLAUDE.md — kostičky and the house blueprint collect via the existing generic pickup mechanism, and a build site assembles `data/house.txt` block-by-block with a flying-arc animation once unlocked.

**Architecture:** `data/items.json` gains two needitelné (non-edible) entries (`block`, `blueprint_house`) that flow through the existing `Items`/`Game`/pickup machinery from step 3 with zero new pickup code — `blueprint_house` additionally triggers a new `Game.unlock_building()` via a data-driven `unlocks_building` field. A new stateless `building_loader.gd` parses the existing `data/house.txt` layer-text format into an ordered block list; a new `build_site.gd` (an `Area3D` mirroring `campfire.gd`'s proximity pattern, spawned by `level_loader.gd` exactly like the campfire) consumes that list and animates blocks flying into place on `p1_action`, deliberately without `Game.ui_blocking` since interrupting a build is expected.

**Tech Stack:** Godot 4.7.2 (GDScript, static typing), Jolt Physics.

**Spec:** `docs/superpowers/specs/2026-09-12-step5-blocks-buildings.md`

## Global Constraints

- GDScript with static typing throughout.
- `Items`, `Game`, `Recipes` are real Godot autoloads (globally accessible, no import). `building_loader.gd` is deliberately NOT an autoload — it's a stateless utility script accessed via `const BuildingLoader = preload(...)` and called as `BuildingLoader.parse(path)` (a static method), same pattern this project already uses for `Palette`.
- New `data/items.json` field `edible` (bool): missing/absent means `true` (so the existing 7 food entries are untouched) — read via `item_data.get("edible", true)`, never assume the key exists.
- New `data/items.json` field `unlocks_building` (string, optional): when present on an item, collecting it calls `Game.unlock_building(that_value)`.
- Building blocks use `BLOCK_SIZE := 0.5` (defined in `building_loader.gd`), distinct from `level_loader.gd`'s world-tile `TILE_SIZE := 2.0` — a building must look like a small house, not a city block.
- Build-site block placement does NOT set `Game.ui_blocking` — unlike the campfire menu, walking away mid-build is expected and fine (spec is explicit on this).
- **Known, already-verified project facts — do not treat these as bugs to fix:** `data/house.txt` (existing kid content) has 60 blocks across 4 layers, not the roadmap's estimated ~15 — left as-is. `levels/forest_01.txt` currently has only 8 `k` tiles, so the house will only partially assemble from this one map — expected, reflect this in the manual-playtest instructions, don't try to "fix" it by adding more `k` to the map yourself. Any `project.godot` edit may pick up harmless Godot-editor-style section reordering (confirmed in this project to come from the editor itself, not from how the edit was made) — verify no *values* changed before treating a reordering diff as a problem; never spend a fix round reverting pure reordering.
- `godot --headless --path . --quit` (binary: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe`, run from repo root) must exit with no `SCRIPT ERROR` / `Parse Error` / unexpected `push_warning`. There is no automated test framework for this project — that command plus a manual playtest by the user (who has the Godot editor open on this same project directory) are the only verification available. This plan does not touch any `.tscn` file (build sites are spawned procedurally by `level_loader.gd` exactly like the campfire, not placed as static scene nodes) — no scene-reload reminder is needed.

---

### Task 1: Item data, Game unlock state, HUD edible filter

**Files:**
- Modify: `data/items.json` (add `block`, `blueprint_house`)
- Modify: `game/autoload/game.gd` (add `unlock_building`/`is_building_unlocked`, extend `add_item`)
- Modify: `game/ui/hud.gd` (filter the "Syrové" section by `edible`)
- Modify: `game/world/level_loader.gd` (remove `k` and `H` from `SKIP_CHARS` only — `S` stays skipped until Task 3)

**Interfaces:**
- Produces: `Game.unlock_building(building_id: String) -> void`, `Game.is_building_unlocked(building_id: String) -> bool` — Task 3's `build_site.gd` consumes both.
- Produces: `data/items.json` entries `block` (`map_char: "k"`) and `blueprint_house` (`map_char: "H"`, `unlocks_building: "house"`) — no other task needs to know their exact fields beyond what's already in this plan.

This task is fully playable/testable on its own: kostičky and the blueprint can already be collected (via the pickup mechanism from step 3, unchanged), show up in the HUD's resource bar, and never appear in the campfire's eat menu. The blueprint's unlock effect (`Game.is_building_unlocked("house")` becoming `true`) has no visible confirmation yet — that comes with Task 3's build site.

- [ ] **Step 1: Add the two new items**

Current `data/items.json` ends with the `water` entry:

```json
{ "id": "water", "name": "Voda", "map_char": "~", "color": "#6BADD1", "energy_raw": 1 }
```

Add two more entries after it (don't forget the comma after `water`'s closing brace):

```json
{ "id": "water", "name": "Voda", "map_char": "~", "color": "#6BADD1", "energy_raw": 1 },
{ "id": "block", "name": "Kostička", "map_char": "k", "color": "#C9A876", "energy_raw": 0, "edible": false },
{ "id": "blueprint_house", "name": "Plánek domečku", "map_char": "H", "color": "#F5E6C8", "energy_raw": 0, "edible": false, "unlocks_building": "house" }
```

- [ ] **Step 2: Add building-unlock state and hook it into add_item**

Current `game/autoload/game.gd`:

```gdscript
extends Node

signal inventory_changed(item_id: String)
signal energy_changed(value: float)

const MAX_ENERGY := 100.0

var energy: float = MAX_ENERGY
var ui_blocking: bool = false
var _inventory: Dictionary = {}

func _ready() -> void:
	for id in Items.all_ids():
		_inventory[id] = 0

func get_count(item_id: String) -> int:
	return _inventory.get(item_id, 0)

func add_item(item_id: String, amount: int = 1) -> void:
	_inventory[item_id] = get_count(item_id) + amount
	inventory_changed.emit(item_id)
```

Change the `var` block and `add_item`, and add two new functions at the end of the file (after `try_cook`):

```gdscript
extends Node

signal inventory_changed(item_id: String)
signal energy_changed(value: float)

const MAX_ENERGY := 100.0

var energy: float = MAX_ENERGY
var ui_blocking: bool = false
var _inventory: Dictionary = {}
var _unlocked_buildings: Dictionary = {}

func _ready() -> void:
	for id in Items.all_ids():
		_inventory[id] = 0

func get_count(item_id: String) -> int:
	return _inventory.get(item_id, 0)

func add_item(item_id: String, amount: int = 1) -> void:
	_inventory[item_id] = get_count(item_id) + amount
	inventory_changed.emit(item_id)
	var item_data := Items.get_by_id(item_id)
	if item_data.has("unlocks_building"):
		unlock_building(item_data["unlocks_building"])
```

And at the very end of the file, after the existing `try_cook` function, add:

```gdscript

func unlock_building(building_id: String) -> void:
	_unlocked_buildings[building_id] = true

func is_building_unlocked(building_id: String) -> bool:
	return _unlocked_buildings.get(building_id, false)
```

Do not touch `try_consume`, `drain`, `restore`, or `try_cook`.

- [ ] **Step 3: Filter non-edible items out of the campfire's raw-food list**

Current `game/ui/hud.gd`'s `open_eat_menu()` builds the raw list like this:

```gdscript
	var raw_ids: Array[String] = []
	for id in Items.all_ids():
		if Game.get_count(id) > 0:
			raw_ids.append(id)
```

Change to:

```gdscript
	var raw_ids: Array[String] = []
	for id in Items.all_ids():
		var item_data := Items.get_by_id(id)
		if Game.get_count(id) > 0 and item_data.get("edible", true):
			raw_ids.append(id)
```

Do not touch anything else in `hud.gd` — the resource bar (`_build_resource_bar`) stays as-is, so blocks/blueprints still get a HUD counter (that's intentional, per the spec).

- [ ] **Step 4: Let kostičky and the blueprint flow through the existing pickup path**

Current `game/world/level_loader.gd` has:

```gdscript
const SKIP_CHARS := "kxwdB!HS0123456789 "
```

Change to (removes `k` and `H` only — `S` stays skipped, Task 3 handles it):

```gdscript
const SKIP_CHARS := "xwdB!S0123456789 "
```

Do not change anything else in this file — the existing default `match` case (`Items.get_by_map_char(ch)` → `_spawn_pickup`) already handles any character with a matching `data/items.json` entry, so `k` and `H` need no new code at all.

- [ ] **Step 5: Verify headless boot**

Run from the repo root:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error` / unexpected `push_warning`. `data/items.json` is well-formed, so `Items`' existing validation should produce zero warnings against the two new entries.

- [ ] **Step 6: Ask the user to playtest**

Tell the user: reload the scene if needed, press Play. Walking into a `k` tile should collect a kostička (disappears, a new counter appears in the HUD's top row). Walking into the `H` tile should collect the blueprint the same way. Neither should ever show up in the campfire's eat menu (open it and check — only real food should be listed, even after collecting blocks/the blueprint). There's no visible confirmation yet that collecting the blueprint "unlocked" anything — that's Task 3.

- [ ] **Step 7: Commit**

```bash
git add data/items.json game/autoload/game.gd game/ui/hud.gd game/world/level_loader.gd
git commit -m "Add block/blueprint items, building-unlock state, and HUD edible filter"
```

---

### Task 2: Building layer-format parser

**Files:**
- Create: `game/building/building_loader.gd`

**Interfaces:**
- Produces: `const BLOCK_SIZE := 0.5` and `static func parse(path: String) -> Array[Dictionary]` (each entry: `{"position": Vector3, "color": Color}`, in placement order: layers ascending, rows top-to-bottom, columns left-to-right within a row) — Task 3's `build_site.gd` consumes both via `const BuildingLoader = preload("res://game/building/building_loader.gd")`.

This task has no automated way to verify its parsing logic in isolation — it's not an autoload, so nothing calls it until Task 3 exists. Headless boot only proves the script has no syntax errors; the real functional verification (does it parse `data/house.txt` into the correct 60 blocks with the right colors/positions) happens visually in Task 3's playtest. Say this plainly in the report rather than claiming more than headless boot can prove.

- [ ] **Step 1: Write the parser**

Create `game/building/building_loader.gd`:

```gdscript
extends RefCounted

const BLOCK_SIZE := 0.5

const LAYER_COLORS := {
	"g": Color(0.45, 0.65, 0.45),
	"y": Color(0.9, 0.8, 0.3),
	"r": Color(0.75, 0.35, 0.3),
}

static func parse(path: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("building_loader: could not open %s" % path)
		return blocks
	var content := file.get_as_text()
	file.close()

	var layer_index := -1
	var row_index := 0
	for raw_line in content.split("\n"):
		var line: String = raw_line.replace("\r", "")
		if line.begins_with(";"):
			continue
		if line.strip_edges() == "":
			continue
		if line.begins_with("[layer"):
			layer_index += 1
			row_index = 0
			continue
		if layer_index < 0:
			continue
		for col in range(line.length()):
			var ch: String = line[col]
			if LAYER_COLORS.has(ch):
				blocks.append({
					"position": Vector3(col * BLOCK_SIZE, layer_index * BLOCK_SIZE, row_index * BLOCK_SIZE),
					"color": LAYER_COLORS[ch],
				})
		row_index += 1

	return blocks
```

This mirrors `level_loader.gd`'s `_read_grid_lines` conventions (skip `;` comments and blank lines, never crash on a malformed file — an unopenable or layer-less file just returns an empty list with a warning, exactly like `level_loader.gd`'s own empty-grid handling).

- [ ] **Step 2: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error` (this only confirms the script parses as valid GDScript — see the note above about why deeper verification waits for Task 3).

- [ ] **Step 3: Commit**

```bash
git add game/building/building_loader.gd
git commit -m "Add building_loader.gd to parse the layer-text building format"
```

---

### Task 3: Build site — interaction and block-flying animation

**Files:**
- Create: `game/building/build_site.gd`
- Modify: `game/world/level_loader.gd` (`S` gets its own `match` case + `_spawn_build_site`)

**Interfaces:**
- Consumes: `BuildingLoader.parse(path: String) -> Array[Dictionary]` and `BuildingLoader.BLOCK_SIZE` (Task 2); `Game.is_building_unlocked(building_id: String) -> bool`, `Game.try_consume(item_id: String, amount: int = 1) -> bool` (Task 1 / pre-existing).
- Produces: nothing new consumed by other tasks — this is the last task in the plan.

Dispatch this task with the actual current `game/world/level_loader.gd` (post Task 1) pasted into the brief, since Task 1 already touched this file (removed `k`/`H` from `SKIP_CHARS`) and this task edits it again.

- [ ] **Step 1: Write the build site script**

Create `game/building/build_site.gd`:

```gdscript
extends Area3D

const BuildingLoader = preload("res://game/building/building_loader.gd")

const ARC_HEIGHT := 1.0
const FLY_DURATION := 0.4
const BLOCK_DELAY := 0.15
const UNLOCKED_COLOR := Color(0.85, 0.7, 0.4)

@export var building_id: String = "house"
@export var data_path: String = "res://data/house.txt"

@onready var marker: MeshInstance3D = $Marker

var _blocks: Array[Dictionary] = []
var _next_index: int = 0
var _placing: bool = false
var _player_in_range: bool = false
var _was_unlocked: bool = false

func _ready() -> void:
	_blocks = BuildingLoader.parse(data_path)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_in_range = false

func _process(_delta: float) -> void:
	var unlocked := Game.is_building_unlocked(building_id)
	if unlocked and not _was_unlocked:
		_was_unlocked = true
		var material := StandardMaterial3D.new()
		material.albedo_color = UNLOCKED_COLOR
		marker.material_override = material

	if unlocked and _player_in_range and not _placing and Input.is_action_just_pressed("p1_action"):
		_place_next_block()

func _place_next_block() -> void:
	if _next_index >= _blocks.size():
		return
	if not Game.try_consume("block"):
		return
	_placing = true

	var block_data: Dictionary = _blocks[_next_index]
	_next_index += 1

	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * BuildingLoader.BLOCK_SIZE
	block.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = block_data["color"]
	block.material_override = material
	add_child(block)

	var start_pos: Vector3 = global_position + Vector3(0, 2.0, 0)
	var end_pos: Vector3 = global_position + block_data["position"]
	block.global_position = start_pos

	var tween := create_tween()
	tween.tween_method(_fly_step.bind(block, start_pos, end_pos), 0.0, 1.0, FLY_DURATION)
	tween.tween_callback(_land_block.bind(block, end_pos))
	tween.tween_interval(BLOCK_DELAY)
	tween.tween_callback(_finish_placing)

func _fly_step(block: MeshInstance3D, start_pos: Vector3, end_pos: Vector3, t: float) -> void:
	var pos: Vector3 = start_pos.lerp(end_pos, t)
	pos.y += sin(t * PI) * ARC_HEIGHT
	block.global_position = pos

func _land_block(block: MeshInstance3D, end_pos: Vector3) -> void:
	block.global_position = end_pos
	var squash := create_tween()
	squash.tween_property(block, "scale", Vector3(1.3, 0.7, 1.3), 0.08)
	squash.tween_property(block, "scale", Vector3.ONE, 0.12)

func _finish_placing() -> void:
	_placing = false
	_place_next_block()
```

`_finish_placing` calling `_place_next_block()` again is what makes one action press place the whole currently-available run of blocks (stopping only when `try_consume("block")` fails or `_next_index` reaches the end) — this is deliberate, matching the spec's "kostičky jedna po druhé odlétnou" description of a single continuous sequence, not one press per block.

- [ ] **Step 2: Wire the build site into level_loader.gd**

The current `game/world/level_loader.gd` (post Task 1) has this at the top:

```gdscript
extends Node3D

const Palette = preload("res://game/theme/palette.gd")
const PickupScript = preload("res://game/pickups/pickup.gd")
const PickupScene := preload("res://game/pickups/Pickup.tscn")
const WaterSourceScript := preload("res://game/pickups/water_source.gd")
const CampfireScript := preload("res://game/cooking/campfire.gd")

const TILE_SIZE := 2.0
const SKIP_CHARS := "xwdB!S0123456789 "
```

Add one more preload and remove `S` from `SKIP_CHARS`:

```gdscript
extends Node3D

const Palette = preload("res://game/theme/palette.gd")
const PickupScript = preload("res://game/pickups/pickup.gd")
const PickupScene := preload("res://game/pickups/Pickup.tscn")
const WaterSourceScript := preload("res://game/pickups/water_source.gd")
const CampfireScript := preload("res://game/cooking/campfire.gd")
const BuildSiteScript := preload("res://game/building/build_site.gd")

const TILE_SIZE := 2.0
const SKIP_CHARS := "xwdB!0123456789 "
```

The current `match ch:` block has (post Task 1, `S` still falls through to the `_:` default case and gets silently skipped via `SKIP_CHARS`):

```gdscript
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
				"P":
					player_spawn_found = true
					player_spawn_pos = world_pos
				_:
					var item_data := Items.get_by_map_char(ch)
					if not item_data.is_empty():
						_spawn_pickup(world_pos, item_data)
					elif not SKIP_CHARS.contains(ch):
						_spawn_unknown(world_pos, ch, row, col)
```

Add an `"S"` case (anywhere among the explicit cases — placing it after `"F"` keeps interactive-object cases grouped together):

```gdscript
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
					elif not SKIP_CHARS.contains(ch):
						_spawn_unknown(world_pos, ch, row, col)
```

Add a new function anywhere after `_spawn_campfire` (e.g. right after it):

```gdscript
func _spawn_build_site(pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.set_script(BuildSiteScript)

	var shape := SphereShape3D.new()
	shape.radius = 2.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 1.0, 0)
	area.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.1, 2.0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Marker"
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, 0.05, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.55)
	mesh_instance.material_override = material
	area.add_child(mesh_instance)

	add_child(area)
```

**Important ordering detail, different from `_spawn_campfire`/`_spawn_water_source`:** this function adds `collision` and `mesh_instance` to `area` BEFORE calling `add_child(area)` on `self` — the opposite order from every other `_spawn_*` function in this file. This is deliberate and required: `build_site.gd`'s `@onready var marker: MeshInstance3D = $Marker` resolves during `_ready()`, and `_ready()` fires the moment `area` actually enters the scene tree. If `add_child(area)` ran first (like the other spawn functions), `area` would enter the tree — and fire `_ready()` — before it has a "Marker" child, and `$Marker` would fail. Building the whole subtree first, then attaching it in one `add_child(area)` call, guarantees `Marker` already exists when `build_site.gd`'s `_ready()` runs. Do not "fix" this to match the other functions' ordering — that would break `$Marker`.

Do not touch `_spawn_rock`, `_spawn_tree`, `_spawn_water`, `_spawn_water_source`, `_spawn_pickup`, `_spawn_campfire`, `_spawn_unknown`, `_build_ground`, `_read_grid_lines`, or `_ready()`.

- [ ] **Step 3: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error`. This is also the first real exercise of `BuildingLoader.parse()` against the actual `data/house.txt` (via `build_site.gd`'s `_ready()`), so a `push_warning` here would mean something is genuinely wrong with the parser or the data file — investigate rather than dismiss.

- [ ] **Step 4: Ask the user to playtest**

Tell the user: reload the scene, press Play. The build site (a flat gray platform, near the campfire on the map) should be visible from the start but do nothing when you press Enter near it. Collect the blueprint (`H` tile) — the platform should immediately change to a warm tan color (no need to be near it when you collect the blueprint; the color change happens as soon as `Game.is_building_unlocked("house")` becomes true, checked every frame). Collect a few kostičky (`k` tiles, there are 8 on this map), stand near the now-tan build site, and press Enter — kostičky should fly out one at a time in a small arc with a squash-and-stretch landing, building up the bottom-left corner of the house. Since the map only has 8 `k` tiles and the house needs 60, only a small partial corner will appear — that's expected, not a bug (more `k` tiles can be added to `levels/forest_01.txt` later). Walking away mid-animation shouldn't cause any errors — the remaining queued blocks (if you pressed Enter with more than 8... there won't be, but conceptually) keep animating independently of the player.

- [ ] **Step 5: Commit**

```bash
git add game/building/build_site.gd game/world/level_loader.gd
git commit -m "Add build site: unlock visual, block-flying animation, level_loader wiring"
```
