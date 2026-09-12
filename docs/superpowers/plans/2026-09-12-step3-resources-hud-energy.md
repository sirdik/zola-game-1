# Krok 3: Sběr surovin, HUD, energie Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build roadmap step 3 from CLAUDE.md — resource pickups, a shared team inventory + energy system, a HUD showing counters and energy, and a campfire eat-menu that restores energy from raw food.

**Architecture:** Two new autoloads (`Items` for read-only item data, `Game` for mutable shared inventory/energy state) sit underneath everything else. The level loader spawns one reusable `Pickup` scene per food tile (data-driven via `Items`) and a `water_source.gd`-scripted `Area3D` per water tile. The player drains `Game`'s energy each frame based on movement/jumping. A `HUD` autoload-free `CanvasLayer` (found via group, not autoload, since it needs to live in the 3D scene tree alongside the camera/player) renders counters/energy from `Game`'s signals and owns the eat-menu; a new `campfire.gd`-scripted `Area3D` opens/closes that menu.

**Tech Stack:** Godot 4.7.2 (GDScript, static typing), Jolt Physics.

**Spec:** `docs/superpowers/specs/2026-09-12-step3-resources-hud-energy.md`

## Global Constraints

- GDScript with static typing throughout.
- `Items` and `Game` are real Godot autoloads (registered in `project.godot`'s `[autoload]` section), NOT the `const X = preload(...)` pattern used for `Palette` — autoloads are globally accessible by name from any script with no import needed, and are unaffected by this project's empty global-script-class-cache issue (that issue is specific to `class_name`-based global registration, which autoloads don't use).
- `Items` must be listed before `Game` in `[autoload]` — `Game._ready()` reads `Items.all_ids()`, and Godot initializes autoloads in the order they're listed.
- Colors for pickups come from `data/items.json`'s `color` field (hex string, parsed via `Color.html()`) — never hardcoded per-item colors in GDScript, since these are exactly the kind of thing kids should be able to retint by editing the JSON.
- `godot --headless --path . --quit` (binary: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe`, run from repo root) must exit with no `SCRIPT ERROR` / `Parse Error`. Because `Items`/`Game` are real autoloads, headless boot actually runs their `_ready()` against the real `data/items.json` starting with Task 1 — a malformed JSON or a script bug there will show up as a `push_warning` in the headless output, not just a script error, so check for warnings too, not only errors. There is no automated test framework for this project — that command plus a manual playtest by the user (who has the Godot editor open on this same project directory — remind them to reload `.tscn` files after edits) are the only verification available.

---

### Task 1: Data + autoloads

**Files:**
- Create: `data/items.json`
- Create: `game/autoload/items.gd`
- Create: `game/autoload/game.gd`
- Modify: `project.godot` (add `[autoload]` section)

**Interfaces:**
- Produces: autoload `Items` with `get_by_id(item_id: String) -> Dictionary`, `get_by_map_char(ch: String) -> Dictionary` (empty `Dictionary` if not found), `all_ids() -> Array[String]` (file order). Produces: autoload `Game` with `signal inventory_changed(item_id: String)`, `signal energy_changed(value: float)`, `const MAX_ENERGY := 100.0`, `var energy: float`, `get_count(item_id: String) -> int`, `add_item(item_id: String, amount: int = 1) -> void`, `try_consume(item_id: String, amount: int = 1) -> bool`, `drain(amount: float) -> void`, `restore(amount: float) -> void`. All later tasks consume these exact names/signatures.

- [ ] **Step 1: Write the item data**

Create `data/items.json`:

```json
{
  "items": [
    { "id": "mushroom", "name": "Houba", "map_char": "m", "color": "#F5F0E1", "energy_raw": 8 },
    { "id": "blackberry", "name": "Ostružina", "map_char": "b", "color": "#3B1F4D", "energy_raw": 8 },
    { "id": "raspberry", "name": "Malina", "map_char": "r", "color": "#C81E4B", "energy_raw": 8 },
    { "id": "blueberry", "name": "Borůvka", "map_char": "u", "color": "#4A6FA5", "energy_raw": 8 },
    { "id": "apple", "name": "Jablko", "map_char": "a", "color": "#D63447", "energy_raw": 8 },
    { "id": "hazelnut", "name": "Oříšek", "map_char": "n", "color": "#8B5A2B", "energy_raw": 8 },
    { "id": "water", "name": "Voda", "map_char": "~", "color": "#6BADD1", "energy_raw": 3 }
  ]
}
```

- [ ] **Step 2: Write the Items autoload**

Create `game/autoload/items.gd`:

```gdscript
extends Node

const DATA_PATH := "res://data/items.json"

var _by_id: Dictionary = {}
var _by_map_char: Dictionary = {}
var _order: Array[String] = []

func _ready() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("items: could not open %s" % DATA_PATH)
		return
	var content := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary) or not parsed.has("items"):
		push_warning("items: malformed %s" % DATA_PATH)
		return
	for entry in parsed["items"]:
		var id: String = entry["id"]
		_by_id[id] = entry
		_order.append(id)
		if entry.has("map_char"):
			_by_map_char[entry["map_char"]] = entry

func get_by_id(item_id: String) -> Dictionary:
	return _by_id.get(item_id, {})

func get_by_map_char(ch: String) -> Dictionary:
	return _by_map_char.get(ch, {})

func all_ids() -> Array[String]:
	return _order
```

- [ ] **Step 3: Write the Game autoload**

Create `game/autoload/game.gd`:

```gdscript
extends Node

signal inventory_changed(item_id: String)
signal energy_changed(value: float)

const MAX_ENERGY := 100.0

var energy: float = MAX_ENERGY
var _inventory: Dictionary = {}

func _ready() -> void:
	for id in Items.all_ids():
		_inventory[id] = 0

func get_count(item_id: String) -> int:
	return _inventory.get(item_id, 0)

func add_item(item_id: String, amount: int = 1) -> void:
	_inventory[item_id] = get_count(item_id) + amount
	inventory_changed.emit(item_id)

func try_consume(item_id: String, amount: int = 1) -> bool:
	if get_count(item_id) < amount:
		return false
	_inventory[item_id] = get_count(item_id) - amount
	inventory_changed.emit(item_id)
	return true

func drain(amount: float) -> void:
	energy = clamp(energy - amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy)

func restore(amount: float) -> void:
	energy = clamp(energy + amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy)
```

- [ ] **Step 4: Register both autoloads**

In `project.godot`, add a new `[autoload]` section (placement among the other top-level sections doesn't matter to Godot — add it after `[application]`, before `[display]`, or at the end; just don't put it inside another section):

```
[autoload]

Items="*res://game/autoload/items.gd"
Game="*res://game/autoload/game.gd"
```

`Items` must appear before `Game` — Godot initializes autoloads in listed order, and `Game._ready()` calls `Items.all_ids()`.

- [ ] **Step 5: Verify headless boot**

Run from the repo root:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error`, AND no `push_warning` output (a warning here means `data/items.json` failed to load/parse — since both autoloads now genuinely run at every boot, this headless check is real evidence the JSON is valid, not just that the scripts compile).

- [ ] **Step 6: Commit**

```bash
git add data/items.json game/autoload/items.gd game/autoload/game.gd project.godot
git commit -m "Add item data and Items/Game autoloads for shared inventory and energy"
```

---

### Task 2: Pickups, water source, level loader integration

**Files:**
- Create: `game/pickups/pickup.gd`
- Create: `game/pickups/Pickup.tscn`
- Create: `game/pickups/water_source.gd`
- Modify: `game/world/level_loader.gd`

**Interfaces:**
- Consumes: `Items.get_by_map_char(ch: String) -> Dictionary`, `Game.add_item(item_id: String, amount: int = 1) -> void` (both from Task 1).
- Produces: `Pickup.tscn` with an `@export var item_id: String` on its root `Area3D`'s script — no other task instantiates this directly (only `level_loader.gd`), so no further interface constraints.

This task's `level_loader.gd` edits are independent of Task 3 (player energy) — both touch different files/concerns. Task 5 will touch `level_loader.gd` again (`_spawn_campfire`), so dispatch that task with this task's actual final file content, not just this plan's sample text.

- [ ] **Step 1: Write the pickup script**

Create `game/pickups/pickup.gd`:

```gdscript
extends Area3D

@export var item_id: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	Game.add_item(item_id)
	queue_free()
```

- [ ] **Step 2: Write the Pickup scene**

Create `game/pickups/Pickup.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://game/pickups/pickup.gd" id="1_pickup"]

[sub_resource type="SphereShape3D" id="SphereShape_1"]
radius = 0.4

[sub_resource type="SphereMesh" id="SphereMesh_1"]
radius = 0.25
height = 0.5

[node name="Pickup" type="Area3D"]
script = ExtResource("1_pickup")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
position = Vector3(0, 0.4, 0)
shape = SubResource("SphereShape_1")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.4, 0)
mesh = SubResource("SphereMesh_1")
```

- [ ] **Step 3: Write the water source script**

Create `game/pickups/water_source.gd`:

```gdscript
extends Area3D

const COLLECT_INTERVAL := 2.0

var _timer: float = 0.0
var _player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = true
		_timer = 0.0

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_inside = false

func _process(delta: float) -> void:
	if not _player_inside:
		return
	_timer += delta
	if _timer >= COLLECT_INTERVAL:
		_timer -= COLLECT_INTERVAL
		Game.add_item("water", 1)
```

- [ ] **Step 4: Wire pickups and water sources into level_loader.gd**

The current `game/world/level_loader.gd` has this at the top:

```gdscript
extends Node3D

const Palette = preload("res://game/theme/palette.gd")

const TILE_SIZE := 2.0
const SKIP_CHARS := "mbruankxwdB!HS0123456789 "
```

Change it to:

```gdscript
extends Node3D

const Palette = preload("res://game/theme/palette.gd")
const PickupScript = preload("res://game/pickups/pickup.gd")
const PickupScene := preload("res://game/pickups/Pickup.tscn")
const WaterSourceScript := preload("res://game/pickups/water_source.gd")

const TILE_SIZE := 2.0
const SKIP_CHARS := "kxwdB!HS0123456789 "
```

(`m b r u a n` are removed from `SKIP_CHARS` — they're now handled via `Items` lookup, added below.)

The current `match ch:` block in `_ready()` reads:

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
				"F":
					_spawn_campfire(world_pos)
				"P":
					player_spawn_found = true
					player_spawn_pos = world_pos
				_:
					if not SKIP_CHARS.contains(ch):
						_spawn_unknown(world_pos, ch, row, col)
```

Change the `"~"` case and the `_:` default case (everything else in the `match` stays identical):

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

Add two new functions anywhere after `_spawn_water` (e.g. right after it):

```gdscript
func _spawn_water_source(pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.set_script(WaterSourceScript)
	add_child(area)

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
	var mesh_instance: MeshInstance3D = pickup.get_node("MeshInstance3D")
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(item_data["color"])
	mesh_instance.material_override = material
```

Do not touch `_spawn_rock`, `_spawn_tree`, `_spawn_campfire` (Task 5 touches `_spawn_campfire` separately), `_spawn_unknown`, `_build_ground`, or `_read_grid_lines`.

- [ ] **Step 5: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error` / unexpected `push_warning`. Every food/water character in `levels/forest_01.txt` (`m b r u a n ~`) should now resolve to a pickup or water source, not a warning.

- [ ] **Step 6: Ask the user to playtest**

Tell the user: reload the scene, press Play, walk into a mushroom/berry/apple/nut — it should disappear (no visible counter yet, that's Task 4 — for now just confirm the pickup vanishes and no errors appear in the Godot output panel). Standing next to water for a couple seconds shouldn't visibly do anything yet either (no HUD to show it) but shouldn't error.

- [ ] **Step 7: Commit**

```bash
git add game/pickups/pickup.gd game/pickups/Pickup.tscn game/pickups/water_source.gd game/world/level_loader.gd
git commit -m "Spawn food pickups and water sources from the level data"
```

---

### Task 3: Player energy drain and the action input

**Files:**
- Modify: `project.godot` (add `p1_action` to `[input]`)
- Modify: `game/player/player.gd`

**Interfaces:**
- Consumes: `Game.drain(amount: float) -> void` (from Task 1).
- Produces: InputMap action `p1_action` (Enter key) — consumed by Task 4 (eat-menu confirm/HUD navigation reuses `p1_move_forward`/`p1_move_back`, already existing) and Task 5 (campfire interaction).

- [ ] **Step 1: Add the p1_action InputMap entry**

In `project.godot`, in the existing `[input]` section, add a new action after `p1_jump`:

```
p1_action={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194309,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

(`physical_keycode = 4194309` is Enter in Godot 4's `Key` enum.)

- [ ] **Step 2: Add energy drain to player.gd**

Current `game/player/player.gd` has these exports and this `_physics_process`:

```gdscript
@export var player_number: int = 1
@export var move_speed: float = 4.0
@export var jump_velocity: float = 5.0
@export var turn_speed: float = 10.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _ready() -> void:
	add_to_group("players")
	var mesh_instance: MeshInstance3D = $MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PEACH
	mesh_instance.material_override = material

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(_action("jump")):
		velocity.y = jump_velocity

	var move_direction := _get_move_direction()
	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed

	if move_direction.length() > 0.01:
		var target_angle := atan2(-move_direction.x, -move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)

	move_and_slide()
```

Change to (adds three constants, one `Game.drain()` call in the jump branch, and wraps the rotation block to also drain energy — the rotation math itself is unchanged):

```gdscript
@export var player_number: int = 1
@export var move_speed: float = 4.0
@export var jump_velocity: float = 5.0
@export var turn_speed: float = 10.0

const IDLE_DRAIN := 0.5
const MOVE_DRAIN := 1.0
const JUMP_DRAIN := 3.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _ready() -> void:
	add_to_group("players")
	var mesh_instance: MeshInstance3D = $MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PEACH
	mesh_instance.material_override = material

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(_action("jump")):
		velocity.y = jump_velocity
		Game.drain(JUMP_DRAIN)

	var move_direction := _get_move_direction()
	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed

	if move_direction.length() > 0.01:
		Game.drain(MOVE_DRAIN * delta)
		var target_angle := atan2(-move_direction.x, -move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
	else:
		Game.drain(IDLE_DRAIN * delta)

	move_and_slide()
```

Do not touch `_get_move_direction()` or `_action()`.

- [ ] **Step 3: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error`.

- [ ] **Step 4: Ask the user to playtest**

Tell the user: reload the scene, press Play. There's no energy bar yet (Task 4), so this can't be visually confirmed directly — but the game should behave exactly as before (movement, jump, camera) with no new errors. Full confirmation that energy actually drains comes with Task 4's HUD.

- [ ] **Step 5: Commit**

```bash
git add project.godot game/player/player.gd
git commit -m "Add p1_action input and energy drain on movement/jump"
```

---

### Task 4: HUD — resource counters, energy bar, eat menu

**Files:**
- Create: `game/ui/hud.gd`
- Create: `game/ui/HUD.tscn`
- Modify: `game/world/Forest.tscn` (add HUD instance)

**Interfaces:**
- Consumes: `Items.all_ids() -> Array[String]`, `Items.get_by_id(item_id: String) -> Dictionary` (Task 1); `Game.get_count`, `Game.inventory_changed`, `Game.energy_changed`, `Game.MAX_ENERGY`, `Game.try_consume`, `Game.restore` (Task 1); InputMap actions `p1_move_forward`, `p1_move_back` (existing), `p1_action` (Task 3).
- Produces: group `"hud"` (added to by `HUD._ready()`), public methods `open_eat_menu() -> void` and `close_eat_menu() -> void` on the HUD's script — Task 5's `campfire.gd` calls these by looking up the group.

The eat-menu logic built in this task can't be triggered in-game yet (nothing calls `open_eat_menu()` until Task 5) — note that clearly to the user rather than claiming it's playtestable now. Resource counters and the energy bar ARE playtestable immediately since Tasks 2 and 3 already feed them real data.

- [ ] **Step 1: Write the HUD scene**

Create `game/ui/HUD.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/ui/hud.gd" id="1_hud"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1_hud")

[node name="ResourceBar" type="HBoxContainer" parent="."]
position = Vector2(16, 16)

[node name="EnergyBarBg" type="ColorRect" parent="."]
position = Vector2(16, 56)
size = Vector2(200, 20)
color = Color(0.2, 0.2, 0.2, 0.6)

[node name="EnergyBarFill" type="ColorRect" parent="EnergyBarBg"]
size = Vector2(200, 20)
color = Color(0.8, 0.3, 0.3, 1)

[node name="EatMenu" type="VBoxContainer" parent="."]
visible = false
position = Vector2(16, 96)
```

- [ ] **Step 2: Write the HUD script**

Create `game/ui/hud.gd`:

```gdscript
extends CanvasLayer

const ENERGY_BAR_WIDTH := 200.0

@onready var resource_bar: HBoxContainer = $ResourceBar
@onready var energy_bar_fill: ColorRect = $EnergyBarBg/EnergyBarFill
@onready var eat_menu: VBoxContainer = $EatMenu

var _resource_labels: Dictionary = {}
var _eat_menu_ids: Array[String] = []
var _eat_menu_selected: int = 0

func _ready() -> void:
	add_to_group("hud")
	_build_resource_bar()
	Game.inventory_changed.connect(_on_inventory_changed)
	Game.energy_changed.connect(_on_energy_changed)
	_on_energy_changed(Game.energy)

func _build_resource_bar() -> void:
	for id in Items.all_ids():
		var item_data := Items.get_by_id(id)
		var row := HBoxContainer.new()
		resource_bar.add_child(row)

		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.color = Color.html(item_data["color"])
		row.add_child(icon)

		var label := Label.new()
		label.text = str(Game.get_count(id))
		row.add_child(label)

		_resource_labels[id] = label

func _on_inventory_changed(item_id: String) -> void:
	if _resource_labels.has(item_id):
		_resource_labels[item_id].text = str(Game.get_count(item_id))

func _on_energy_changed(value: float) -> void:
	energy_bar_fill.size.x = ENERGY_BAR_WIDTH * (value / Game.MAX_ENERGY)

func open_eat_menu() -> void:
	_eat_menu_ids = []
	for id in Items.all_ids():
		if Game.get_count(id) > 0:
			_eat_menu_ids.append(id)

	for child in eat_menu.get_children():
		child.queue_free()

	if _eat_menu_ids.is_empty():
		var label := Label.new()
		label.text = "Nemáš žádné jídlo!"
		eat_menu.add_child(label)
	else:
		_eat_menu_selected = 0
		for id in _eat_menu_ids:
			var item_data := Items.get_by_id(id)
			var label := Label.new()
			label.text = "%s x%d" % [item_data["name"], Game.get_count(id)]
			eat_menu.add_child(label)
		_update_eat_menu_highlight()

	eat_menu.visible = true

func close_eat_menu() -> void:
	eat_menu.visible = false

func _update_eat_menu_highlight() -> void:
	for i in eat_menu.get_child_count():
		var label: Label = eat_menu.get_child(i)
		label.modulate = Color(1, 1, 0.4) if i == _eat_menu_selected else Color(1, 1, 1)

func _unhandled_input(event: InputEvent) -> void:
	if not eat_menu.visible or _eat_menu_ids.is_empty():
		return
	if event.is_action_pressed("p1_move_back"):
		_eat_menu_selected = (_eat_menu_selected + 1) % _eat_menu_ids.size()
		_update_eat_menu_highlight()
	elif event.is_action_pressed("p1_move_forward"):
		_eat_menu_selected = (_eat_menu_selected - 1 + _eat_menu_ids.size()) % _eat_menu_ids.size()
		_update_eat_menu_highlight()
	elif event.is_action_pressed("p1_action"):
		var id: String = _eat_menu_ids[_eat_menu_selected]
		if Game.try_consume(id):
			Game.restore(Items.get_by_id(id)["energy_raw"])
		close_eat_menu()
```

- [ ] **Step 3: Add the HUD instance to Forest.tscn**

Read the current `game/world/Forest.tscn` first to get its exact `load_steps` count and existing `ext_resource` ids (Tasks 1-3 didn't touch this file, so it should match step 2's final state, but confirm before editing).

Add a new `ext_resource` line for the HUD scene, and a new node instancing it as a child of `Forest` (position among siblings doesn't matter here — HUD is a `CanvasLayer`, not part of the 3D tree). Increment `load_steps` by 1 for the new `ext_resource`.

```
[ext_resource type="PackedScene" path="res://game/ui/HUD.tscn" id="5_hud"]
```
```
[node name="HUD" parent="." instance=ExtResource("5_hud")]
```

- [ ] **Step 4: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error`.

- [ ] **Step 5: Ask the user to playtest**

Tell the user: reload the scene, press Play. They should see a row of colored squares with numbers (starting at 0) in the top-left, and a dark bar with a red fill below it. Walking into food pickups should increment the matching counter immediately. The energy bar should slowly shrink over time, faster while moving, with a small extra drop on each jump. The eat-menu itself isn't reachable yet (Task 5) — don't try it.

- [ ] **Step 6: Commit**

```bash
git add game/ui/hud.gd game/ui/HUD.tscn game/world/Forest.tscn
git commit -m "Add HUD with resource counters, energy bar, and eat-menu logic"
```

---

### Task 5: Campfire interaction

**Files:**
- Create: `game/cooking/campfire.gd`
- Modify: `game/world/level_loader.gd` (`_spawn_campfire` only)

**Interfaces:**
- Consumes: group `"hud"` and `open_eat_menu()`/`close_eat_menu()` (Task 4); InputMap action `p1_action` (Task 3).
- Produces: nothing new consumed by other tasks — this is the last task in the plan.

Dispatch this task with the actual current `game/world/level_loader.gd` (post Task 2) pasted into the brief, since this task edits the same file and needs the real current `_spawn_campfire` function and the real current top-of-file `const` block to add one more `preload` line to.

- [ ] **Step 1: Write the campfire script**

Create `game/cooking/campfire.gd`:

```gdscript
extends Area3D

var _player_in_range: bool = false
var _hud: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	call_deferred("_find_hud")

func _find_hud() -> void:
	var huds := get_tree().get_nodes_in_group("hud")
	if huds.size() > 0:
		_hud = huds[0]

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_in_range = false
		if _hud != null:
			_hud.close_eat_menu()

func _process(_delta: float) -> void:
	if _hud == null:
		_find_hud()
		return
	if _player_in_range and Input.is_action_just_pressed("p1_action"):
		_hud.open_eat_menu()
```

- [ ] **Step 2: Restructure _spawn_campfire in level_loader.gd**

Add one more preload near the top of `game/world/level_loader.gd`, alongside the `PickupScript`/`PickupScene`/`WaterSourceScript` consts added in Task 2:

```gdscript
const CampfireScript := preload("res://game/cooking/campfire.gd")
```

The current `_spawn_campfire` (from step 2, untouched by Task 2) reads:

```gdscript
func _spawn_campfire(pos: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.3
	mesh.height = 0.4
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = pos + Vector3(0, 0.2, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.45, 0.2)
	mesh_instance.material_override = material
	add_child(mesh_instance)
```

Replace it with (same mesh/material, now a child of a new `Area3D` that carries the interaction script and a collision shape for range detection):

```gdscript
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
```

Do not touch any other function in this file.

- [ ] **Step 3: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error`.

- [ ] **Step 4: Ask the user to playtest**

Tell the user: reload the scene, press Play, collect a few food items, walk up to the campfire (the small orange cylinder), and press Enter. A menu should appear listing the food types they're carrying; Up/Down arrows move the highlight, Enter confirms — the selected food's count should drop by 1, the energy bar should jump up a little, and the menu should close. Walking away from the campfire while the menu is open should also close it. Pressing Enter at the campfire with no food should show "Nemáš žádné jídlo!" instead of a pickable list.

- [ ] **Step 5: Commit**

```bash
git add game/cooking/campfire.gd game/world/level_loader.gd
git commit -m "Add campfire interaction to open the eat menu"
```
