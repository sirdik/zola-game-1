# Step 6 (Animals) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three friendly wandering/pettable animals (fox, wolf, deer) and one aggressive chasing animal (bear) to the forest, plus a horn item that scares the bear away, using runtime-baked navigation so animals path around trees and rocks.

**Architecture:** One data file (`data/animals.json`) plus one autoload (`Animals`) supply per-species config; one shared script (`game/animals/animal.gd`) implements a state machine (idle/wander/look/chase/flee) driven entirely by that config, so a new animal type never needs new code. Movement uses `NavigationAgent3D` against a `NavigationRegion3D` that `level_loader.gd` bakes **asynchronously** at the end of level generation (synchronous baking was tested and does not work in this Godot version — see Global Constraints). A small, self-contained knockback mechanism is added to `player.gd` so a bear hit can push the player back without being instantly overwritten by the player's own input-driven movement code.

**Tech Stack:** Godot 4.7.2, GDScript with static typing, `NavigationAgent3D`/`NavigationRegion3D`, `Tween`.

**Spec:** `docs/superpowers/specs/2026-09-13-step6-animals.md`

## Global Constraints

- Godot 4.7.2, GDScript, static typing throughout (mirror the existing style in `game/autoload/items.gd`, `game/pickups/pickup.gd`, `game/world/level_loader.gd`).
- No automated test framework exists. "Testing" means: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit` from the repo root must show no `SCRIPT ERROR` / `Parse Error` / unexpected `push_warning`, plus a manual playtest step described in each task (only the human user can actually do the manual part — implementers run the headless check and describe what to manually verify).
- **`NavigationRegion3D.bake_navigation_mesh(false)` (synchronous) does NOT work in this project/Godot version** — it reports a plausible polygon count but the result never actually registers with `NavigationServer3D`, so all path/closest-point queries silently return degenerate zero results. This was confirmed with a standalone reproduction before this plan was written. **Always bake with `bake_navigation_mesh(true)` (async, the default)** — do not "simplify" this to `false` for any reason, even though `true` looks like it requires more ceremony (a `bake_finished` signal). No signal handler is actually required for this plan (see Task 4) — `true` is passed and the bake proceeds in the background; animals simply won't move meaningfully until it completes a few frames later, which is harmless and unnoticeable (see Task 4).
- Defensive parsing everywhere per project convention (`data/animals.json` malformed entries are skipped with `push_warning`, never crash — mirror `game/autoload/items.gd` exactly).
- New content (a new animal species) must require a new `data/animals.json` entry only, never new code — do not special-case any animal `id` anywhere in scripts.
- `levels/forest_01.txt` already has `x`/`w`/`d`/`B`/`!` placed on the map and documented in its legend (from step 2) — **no map content changes are needed or in scope for this plan.**
- `CharacterBody3D`-typed nodes built programmatically in `level_loader.gd` and given a script via `set_script()` (not `class_name`-based typing) is the established pattern for every existing spawned entity (`campfire.gd`, `build_site.gd`, `water_source.gd`) — this project's `global_script_class_cache.cfg` is empty, so `class_name`-based global type resolution is unreliable outside the full editor GUI; always use `const XScript = preload("res://path/to/x.gd")` + `set_script(XScript)`, never rely on a bare `class_name` as a type name in a freshly-cloned/headless context.
- When a spawned node's script has an `@onready var x = $SomeChildName`, that child **must** be added to the new node **before** the new node itself is added to its own parent (`add_child` on `self`/`Level`) — `_ready()` (and therefore `@onready` resolution) fires the instant a node enters the scene tree. This is already established by `build_site.gd`'s `$Marker` in the current codebase; the same rule applies to `animal.gd`'s `$NavigationAgent3D` in Task 4.
- 3D `MeshInstance3D` nodes have **no `modulate` property** (that's a 2D `CanvasItem` thing) — to fade a mesh, animate its material's `albedo_color:a` instead, with the material's `transparency` set to `BaseMaterial3D.TRANSPARENCY_ALPHA`. This was confirmed with a standalone reproduction before this plan was written; Task 3's pet-heart-effect code below already does this correctly — do not "simplify" it to `modulate`.
- `Tween.tween_method(callable.bind(...), from, to, duration)` calls the bound callable with the **interpolated value first, then the bound arguments in the order bound** (`Callable.bind()` appends bound arguments after the caller-supplied ones) — this plan does not use `tween_method` anywhere (only `tween_property`/`tween_callback`, which don't have this hazard), but if any future edit adds one, get the parameter order right the first time; a past bug in this project (`build_site.gd`) shipped for an entire roadmap step with this exact mistake before being caught.

---

## Task 1: Animal data, `Animals` autoload, and the horn item

**Files:**
- Create: `data/animals.json`
- Create: `game/autoload/animals.gd`
- Modify: `project.godot` (register the `Animals` autoload)
- Modify: `data/items.json` (add the horn entry)

**Interfaces:**
- Produces: `Animals.get_by_id(animal_id: String) -> Dictionary`, `Animals.get_by_map_char(ch: String) -> Dictionary`, `Animals.all_ids() -> Array[String]` — same shape as the existing `Items` autoload. Every returned `Dictionary` is guaranteed (by this task's own validation) to have a valid string `"id"` and a valid hex-string `"color"`; every other field is optional and read by later tasks via `.get(key, default)`.

- [ ] **Step 1: Create `data/animals.json`**

```json
{
  "animals": [
    { "id": "fox", "name": "Liška", "map_char": "x", "color": "#E07A3E", "aggressive": false, "move_speed": 1.5, "wander_radius": 4.0, "notice_radius": 4.0, "pet_radius": 1.5 },
    { "id": "wolf", "name": "Vlk", "map_char": "w", "color": "#6E6E6E", "aggressive": false, "move_speed": 1.5, "wander_radius": 4.0, "notice_radius": 4.0, "pet_radius": 1.5 },
    { "id": "deer", "name": "Srnka", "map_char": "d", "color": "#A9754F", "aggressive": false, "move_speed": 1.8, "wander_radius": 5.0, "notice_radius": 5.0, "pet_radius": 1.5 },
    { "id": "bear", "name": "Medvěd", "map_char": "B", "color": "#5C4028", "aggressive": true, "move_speed": 1.2, "wander_radius": 4.0, "chase_radius": 6.0, "chase_speed": 3.0, "catch_radius": 1.2, "give_up_time": 8.0, "energy_drain_on_hit": 15.0, "knockback_force": 6.0, "flee_speed": 4.0, "flee_duration": 4.0, "horn_radius": 6.0, "horn_cooldown": 3.0 }
  ]
}
```

- [ ] **Step 2: Create `game/autoload/animals.gd`**

```gdscript
extends Node

const DATA_PATH := "res://data/animals.json"

var _by_id: Dictionary = {}
var _by_map_char: Dictionary = {}
var _order: Array[String] = []

func _ready() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("animals: could not open %s" % DATA_PATH)
		return
	var content := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary) or not parsed.has("animals") or not (parsed["animals"] is Array):
		push_warning("animals: malformed %s" % DATA_PATH)
		return
	for entry in parsed["animals"]:
		if not (entry is Dictionary) or not entry.has("id") or not (entry["id"] is String):
			push_warning("animals: skipping an entry with a missing or invalid id in %s" % DATA_PATH)
			continue
		var id: String = entry["id"]
		if not entry.has("color") or not (entry["color"] is String) or not Color.html_is_valid(entry["color"]):
			push_warning("animals: entry '%s' has a missing or invalid color, defaulting to white" % id)
			entry["color"] = "#ffffff"
		if not entry.has("aggressive") or not (entry["aggressive"] is bool):
			entry["aggressive"] = false
		_by_id[id] = entry
		_order.append(id)
		if entry.has("map_char"):
			_by_map_char[entry["map_char"]] = entry

func get_by_id(animal_id: String) -> Dictionary:
	return _by_id.get(animal_id, {})

func get_by_map_char(ch: String) -> Dictionary:
	return _by_map_char.get(ch, {})

func all_ids() -> Array[String]:
	return _order
```

- [ ] **Step 3: Register the `Animals` autoload in `project.godot`**

Find the `[autoload]` section (currently):

```
[autoload]

Items="*res://game/autoload/items.gd"
Game="*res://game/autoload/game.gd"
Recipes="*res://game/autoload/recipes.gd"
```

Append one line so it reads:

```
[autoload]

Items="*res://game/autoload/items.gd"
Game="*res://game/autoload/game.gd"
Recipes="*res://game/autoload/recipes.gd"
Animals="*res://game/autoload/animals.gd"
```

Edit this as a plain text change (do not open `project.godot` in the Godot editor GUI to do this — that triggers unrelated section-reordering churn that is harmless but not part of this task's diff). Do not reorder or otherwise touch the existing three lines.

- [ ] **Step 4: Add the horn item to `data/items.json`**

Current file:

```json
{
  "items": [
    { "id": "mushroom", "name": "Houba", "map_char": "m", "color": "#F5F0E1", "energy_raw": 3 },
    { "id": "blackberry", "name": "Ostružina", "map_char": "b", "color": "#3B1F4D", "energy_raw": 3 },
    { "id": "raspberry", "name": "Malina", "map_char": "r", "color": "#C81E4B", "energy_raw": 3 },
    { "id": "blueberry", "name": "Borůvka", "map_char": "u", "color": "#4A6FA5", "energy_raw": 3 },
    { "id": "apple", "name": "Jablko", "map_char": "a", "color": "#D63447", "energy_raw": 3 },
    { "id": "hazelnut", "name": "Oříšek", "map_char": "n", "color": "#8B5A2B", "energy_raw": 3 },
    { "id": "water", "name": "Voda", "map_char": "~", "color": "#6BADD1", "energy_raw": 1 },
    { "id": "block", "name": "Kostička", "map_char": "k", "color": "#C9A876", "energy_raw": 0, "edible": false },
    { "id": "blueprint_house", "name": "Plánek domečku", "map_char": "H", "color": "#F5E6C8", "energy_raw": 0, "edible": false, "unlocks_building": "house" }
  ]
}
```

Add one entry after `blueprint_house` (so the `items` array has 10 entries total):

```json
    { "id": "horn", "name": "Klakson", "map_char": "!", "color": "#E8C93A", "energy_raw": 0, "edible": false }
```

The horn is never consumed anywhere in this plan — it has no `unlocks_building` field and nothing ever calls `Game.try_consume("horn")`. Once picked up it stays in inventory permanently (checked only via `Game.get_count("horn") > 0` in Task 3).

- [ ] **Step 5: Verify headless boot**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit` from the repo root.

Expected: prints the Godot version banner and exits with no `SCRIPT ERROR`, no `Parse Error`, and no `push_warning` about `animals.json` or `items.json` (both files are well-formed at this point, so the new defensive-parsing code paths in `animals.gd` should not fire).

- [ ] **Step 6: Commit**

```bash
git add data/animals.json game/autoload/animals.gd project.godot data/items.json
git commit -m "Add animal data, Animals autoload, and the horn item"
```

---

## Task 2: Player knockback

**Files:**
- Modify: `game/player/player.gd`

**Interfaces:**
- Consumes: nothing new (uses the file's existing `_gravity`, `Game.ui_blocking`, `Game.drain`, `_get_move_direction()`, `_action()`).
- Produces: `apply_knockback(direction: Vector3, force: float, duration: float = 0.3) -> void` — a public method any other script can call on a `Player` node (via a generic `Node3D`-or-looser reference; no import needed by the caller, since GDScript resolves the call dynamically against whatever script is actually attached at runtime — see Global Constraints' note on `class_name` resolution).

Current full file:

```gdscript
class_name Player
extends CharacterBody3D

const Palette = preload("res://game/theme/palette.gd")

@export var player_number: int = 1
@export var move_speed: float = 4.0
@export var jump_velocity: float = 5.0
@export var turn_speed: float = 10.0

const IDLE_DRAIN := 0.1
const MOVE_DRAIN := 0.3
const JUMP_DRAIN := 1.0

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
	elif not Game.ui_blocking and Input.is_action_just_pressed(_action("jump")):
		velocity.y = jump_velocity
		Game.drain(JUMP_DRAIN)

	var move_direction := Vector3.ZERO if Game.ui_blocking else _get_move_direction()
	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed

	if move_direction.length() > 0.01:
		Game.drain(MOVE_DRAIN * delta)
		var target_angle := atan2(-move_direction.x, -move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
	else:
		Game.drain(IDLE_DRAIN * delta)

	move_and_slide()

func _get_move_direction() -> Vector3:
	var input_dir := Vector2.ZERO
	input_dir.y -= 1.0 if Input.is_action_pressed(_action("move_forward")) else 0.0
	input_dir.y += 1.0 if Input.is_action_pressed(_action("move_back")) else 0.0
	input_dir.x -= 1.0 if Input.is_action_pressed(_action("move_left")) else 0.0
	input_dir.x += 1.0 if Input.is_action_pressed(_action("move_right")) else 0.0

	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_dir.x, 0.0, -input_dir.y).normalized()

	var cam_basis := camera.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()
	return (forward * -input_dir.y + right * input_dir.x).normalized()

func _action(action_name: String) -> String:
	return "p%d_%s" % [player_number, action_name]
```

- [ ] **Step 1: Add knockback state variables**

Add these two lines right after the existing `var _gravity: ...` line:

```gdscript
var _knockback_velocity: Vector3 = Vector3.ZERO
var _knockback_timer: float = 0.0
```

- [ ] **Step 2: Make `_physics_process` use knockback velocity while it's active**

Replace the whole `_physics_process` function with:

```gdscript
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif not Game.ui_blocking and Input.is_action_just_pressed(_action("jump")):
		velocity.y = jump_velocity
		Game.drain(JUMP_DRAIN)

	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
	else:
		var move_direction := Vector3.ZERO if Game.ui_blocking else _get_move_direction()
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

This is why the knockback needs its own state rather than just calling `velocity.x = ...` once from outside: without this `if _knockback_timer > 0.0` branch, the `else` branch's `velocity.x = move_direction.x * move_speed` would overwrite any externally-set velocity on the very next physics frame (60 times a second), making an external push invisible.

- [ ] **Step 3: Add the `apply_knockback` method**

Add this new function anywhere after `_physics_process` (e.g., right before `_get_move_direction`):

```gdscript
func apply_knockback(direction: Vector3, force: float, duration: float = 0.3) -> void:
	_knockback_velocity = Vector3(direction.x, 0.0, direction.z).normalized() * force
	_knockback_timer = duration
```

`direction` does not need to be pre-normalized by the caller — this normalizes it (ignoring any Y component) before scaling by `force`. If `direction` is the zero vector, `Vector3.normalized()` in Godot returns `Vector3.ZERO` (not an error/NaN), so this degrades gracefully to "no knockback" rather than crashing.

- [ ] **Step 4: Verify headless boot**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`

Expected: clean boot, no errors. (This change cannot be exercised by headless boot alone — nothing calls `apply_knockback` yet. That happens in Task 3/4. This step only confirms the edit didn't break parsing.)

- [ ] **Step 5: Commit**

```bash
git add game/player/player.gd
git commit -m "Add player knockback for future bear/animal interactions"
```

---

## Task 3: `animal.gd` — the shared state machine

**Files:**
- Create: `game/animals/animal.gd`

**Interfaces:**
- Consumes: `Game.drain(amount: float) -> void`, `Game.get_count(item_id: String) -> int` (both already exist in `game/autoload/game.gd`), the `"players"` group (already populated by `player.gd`'s `_ready()`), and `apply_knockback(direction, force, duration)` on whatever node is found in the `"players"` group (Task 2's addition — see Global Constraints for why this works without a compile-time dependency on `player.gd`'s exact type).
- Produces: a `CharacterBody3D`-derived script with these **public fields**, all read by `level_loader.gd` in Task 4 via direct assignment after `set_script()` (no constructor/init function — mirrors `pickup.gd`'s `item_id` pattern):
  `animal_id: String`, `aggressive: bool`, `move_speed: float`, `wander_radius: float`, `notice_radius: float`, `pet_radius: float`, `chase_radius: float`, `chase_speed: float`, `catch_radius: float`, `give_up_time: float`, `energy_drain_on_hit: float`, `knockback_force: float`, `flee_speed: float`, `flee_duration: float`, `horn_radius: float`, `horn_cooldown: float`.
  It also **requires** a child node named exactly `NavigationAgent3D` of type `NavigationAgent3D` to exist before `_ready()` runs (Task 4 creates this child before adding the animal to the scene tree — same rule as `build_site.gd`'s `$Marker`, see Global Constraints).
  Also produces a public method `scare(from_position: Vector3) -> bool` (returns `true` if the animal was actually scared into fleeing, `false` if it's not an aggressive animal or is already on cooldown) — this is how a future horn-use action would trigger a flee from outside, and is also used internally by this task's own horn-detection code (see Step 8).

- [ ] **Step 1: Create the file with state enum, exported fields, and `_ready()`**

```gdscript
extends CharacterBody3D

enum State { IDLE, WANDER, LOOK, CHASE, FLEE }

const HIT_COOLDOWN := 1.5
const IDLE_MIN_TIME := 1.0
const IDLE_MAX_TIME := 3.0
const TURN_SPEED := 10.0
const HEART_COLOR := Color(0.95, 0.4, 0.55)
const HOP_SCALE := Vector3(1.2, 0.8, 1.2)

var animal_id: String = ""
var aggressive: bool = false
var move_speed: float = 1.5
var wander_radius: float = 4.0
var notice_radius: float = 4.0
var pet_radius: float = 1.5
var chase_radius: float = 6.0
var chase_speed: float = 3.0
var catch_radius: float = 1.2
var give_up_time: float = 8.0
var energy_drain_on_hit: float = 15.0
var knockback_force: float = 6.0
var flee_speed: float = 4.0
var flee_duration: float = 4.0
var horn_radius: float = 6.0
var horn_cooldown: float = 3.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _state: State = State.IDLE
var _spawn_position: Vector3 = Vector3.ZERO
var _player: Node3D = null
var _idle_timer: float = 0.0
var _chase_timer: float = 0.0
var _flee_timer: float = 0.0
var _hit_cooldown: float = 0.0
var _horn_cooldown_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_spawn_position = global_position
	_player = get_tree().get_first_node_in_group("players")
	_enter_idle()
```

`get_tree().get_first_node_in_group("players")` returns `null` if no player exists yet — every place below that uses `_player` guards against `null` first (see `_physics_process`), so this never crashes even if an animal somehow spawns before the player does.

- [ ] **Step 2: Add `_physics_process` and the small helpers it calls**

```gdscript
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta
	if _horn_cooldown_timer > 0.0:
		_horn_cooldown_timer -= delta

	if _player != null:
		match _state:
			State.IDLE:
				_process_idle(delta)
			State.WANDER:
				_process_wander(delta)
			State.LOOK:
				_process_look(delta)
			State.CHASE:
				_process_chase(delta)
			State.FLEE:
				_process_flee(delta)

		if aggressive and _state != State.FLEE:
			_check_horn_use()

	move_and_slide()

func _distance_to_player() -> float:
	return global_position.distance_to(_player.global_position)

func _move_toward_nav_target(speed: float, delta: float) -> void:
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = next_pos - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_face_position(global_position + direction, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _face_position(target: Vector3, delta: float) -> void:
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	if to_target.length() > 0.01:
		var target_angle := atan2(-to_target.x, -to_target.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)
```

`_move_toward_nav_target` is the one function every locomotion state (`WANDER`, `CHASE`, `FLEE`) calls — it reads the next step along the currently-baked path from `nav_agent` and turns it into a `velocity` + facing update, exactly like `player.gd`'s own `atan2(-x, -z)` facing convention (same sign convention, so animals and the player turn to face the same way given the same direction vector).

- [ ] **Step 3: Add the IDLE and WANDER states**

```gdscript
func _enter_idle() -> void:
	_state = State.IDLE
	_idle_timer = _rng.randf_range(IDLE_MIN_TIME, IDLE_MAX_TIME)
	velocity.x = 0.0
	velocity.z = 0.0

func _process_idle(delta: float) -> void:
	if _check_aggro_or_notice():
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_enter_wander()

func _enter_wander() -> void:
	_state = State.WANDER
	var offset := Vector3(
		_rng.randf_range(-wander_radius, wander_radius),
		0.0,
		_rng.randf_range(-wander_radius, wander_radius)
	)
	nav_agent.target_position = _spawn_position + offset

func _process_wander(delta: float) -> void:
	if _check_aggro_or_notice():
		return
	if nav_agent.is_navigation_finished():
		_enter_idle()
		return
	_move_toward_nav_target(move_speed, delta)

func _check_aggro_or_notice() -> bool:
	var dist := _distance_to_player()
	if aggressive:
		if dist <= chase_radius:
			_enter_chase()
			return true
	elif dist <= notice_radius:
		_state = State.LOOK
		return true
	return false
```

`_check_aggro_or_notice()` is called from both `IDLE` and `WANDER` (matching the spec: the player's approach interrupts wandering mid-walk, not just while idle) — for a friendly animal it jumps straight into `LOOK` (no separate "entering" step needed, `LOOK`'s own per-frame logic in Step 4 takes over immediately); for the bear it calls `_enter_chase()`.

- [ ] **Step 4: Add the LOOK state and the pet effect**

```gdscript
func _process_look(delta: float) -> void:
	if _distance_to_player() > notice_radius:
		_enter_idle()
		return
	_face_position(_player.global_position, delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if _distance_to_player() <= pet_radius and Input.is_action_just_pressed("p1_action"):
		_play_pet_effect()

func _play_pet_effect() -> void:
	var hop := create_tween()
	hop.tween_property(self, "scale", HOP_SCALE, 0.1)
	hop.tween_property(self, "scale", Vector3.ONE, 0.15)

	var heart := MeshInstance3D.new()
	var heart_mesh := SphereMesh.new()
	heart_mesh.radius = 0.2
	heart_mesh.height = 0.4
	heart.mesh = heart_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = HEART_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	heart.material_override = material
	heart.position = Vector3(0, 1.6, 0)
	add_child(heart)

	var float_up := create_tween()
	float_up.tween_property(heart, "position:y", 2.2, 0.8)
	float_up.parallel().tween_property(material, "albedo_color:a", 0.0, 0.8)
	float_up.tween_callback(heart.queue_free)
```

The fade uses `material.albedo_color:a` (a property on the `StandardMaterial3D` **resource**, which `tween_property` can animate directly, not just properties on `Node`s), with `transparency` set to `TRANSPARENCY_ALPHA` so the alpha channel actually affects rendering — **not** `modulate`, which `MeshInstance3D` does not have (see Global Constraints; this was verified with a standalone reproduction before writing this plan — do not "simplify" it back to `modulate`, that will silently do nothing).

- [ ] **Step 5: Add the CHASE state and the hit/knockback logic**

```gdscript
func _enter_chase() -> void:
	_state = State.CHASE
	_chase_timer = 0.0

func _process_chase(delta: float) -> void:
	_chase_timer += delta
	var dist := _distance_to_player()
	if _chase_timer >= give_up_time or dist > chase_radius * 1.5:
		_enter_idle()
		return
	nav_agent.target_position = _player.global_position
	_move_toward_nav_target(chase_speed, delta)
	if dist <= catch_radius and _hit_cooldown <= 0.0:
		_hit_player()

func _hit_player() -> void:
	Game.drain(energy_drain_on_hit)
	var away: Vector3 = _player.global_position - global_position
	_player.apply_knockback(away, knockback_force)
	_hit_cooldown = HIT_COOLDOWN
```

The give-up check (`_chase_timer >= give_up_time or dist > chase_radius * 1.5`) runs **before** updating the nav target or checking for a hit each frame, so a bear that's given up never takes one more swing on its way back to idle.

- [ ] **Step 6: Add the FLEE state and `scare()`**

```gdscript
func scare(from_position: Vector3) -> bool:
	if not aggressive or _horn_cooldown_timer > 0.0:
		return false
	_horn_cooldown_timer = horn_cooldown
	_state = State.FLEE
	var away: Vector3 = global_position - from_position
	if away.length() < 0.01:
		away = Vector3(1.0, 0.0, 0.0)
	nav_agent.target_position = global_position + away.normalized() * (chase_radius * 2.0)
	_flee_timer = flee_duration
	return true

func _process_flee(delta: float) -> void:
	_flee_timer -= delta
	if _flee_timer <= 0.0:
		_enter_idle()
		return
	_move_toward_nav_target(flee_speed, delta)
```

`scare()` is public and safe to call on ANY animal (friendly ones just return `false` immediately via the `not aggressive` check — a fox can never be "scared" by the horn, matching the spec). The `away.length() < 0.01` guard handles the edge case where `from_position` happens to exactly coincide with the bear's own position (would otherwise normalize a zero vector into a meaningless direction); it just picks an arbitrary flee direction in that case rather than getting stuck.

- [ ] **Step 7: Add the horn-detection check**

```gdscript
func _check_horn_use() -> void:
	if _distance_to_player() <= horn_radius and Game.get_count("horn") > 0 and Input.is_action_just_pressed("p1_action"):
		scare(_player.global_position)
```

This is called once per frame from `_physics_process` (Step 2) only when `aggressive` and not already `FLEE`ing. It never consumes the horn (`Game.get_count`, never `Game.try_consume`) — per the spec, the horn is a permanent tool, not a single-use item.

- [ ] **Step 8: Verify headless boot**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`

Expected: clean boot, no errors. Nothing references `animal.gd` yet (that's Task 4), so this only confirms the file parses correctly on its own — there is no way to exercise the state machine at runtime until Task 4 wires it into `level_loader.gd`. Read through the state transition logic once more by hand before moving on: every state-entry function (`_enter_idle`, `_enter_wander`, `_enter_chase`) sets `_state` itself, and every `_process_*` function is only ever reached via the `match _state:` block in `_physics_process`, so there is no path that leaves `_state` and the active `_process_*` function out of sync.

- [ ] **Step 9: Commit**

```bash
git add game/animals/animal.gd
git commit -m "Add shared animal state machine (idle/wander/look/chase/flee)"
```

---

## Task 4: Wire animals and navigation into `level_loader.gd`

**Files:**
- Modify: `game/world/level_loader.gd`

**Interfaces:**
- Consumes: `Animals.get_by_map_char(ch) -> Dictionary` (Task 1), `game/animals/animal.gd`'s public fields and required `$NavigationAgent3D` child (Task 3).
- Produces: nothing new for later tasks — this is the final integration task for this plan.

The **current** full file (verify it still matches this before editing — if it doesn't, stop and report which lines differ rather than guessing):

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
					elif not SKIP_CHARS.contains(ch):
						_spawn_unknown(world_pos, ch, row, col)

	if player_spawn_found:
		var player := get_node_or_null(player_path)
		if player is Node3D:
			player.global_position = player_spawn_pos + Vector3(0, 0.05, 0)

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
	var mesh_instance: MeshInstance3D = pickup.get_node("MeshInstance3D")
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(item_data["color"])
	mesh_instance.material_override = material

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
```

- [ ] **Step 1: Add the `AnimalScript` preload**

Add one line to the top block of consts:

```gdscript
const AnimalScript := preload("res://game/animals/animal.gd")
```

- [ ] **Step 2: Shrink `SKIP_CHARS`**

Change:

```gdscript
const SKIP_CHARS := "xwdB!0123456789 "
```

to:

```gdscript
const SKIP_CHARS := "0123456789 "
```

(`x`, `w`, `d`, `B` will now be resolved by the `Animals` lookup added in Step 5 below; `!` will be resolved by the existing `Items` lookup, since `data/items.json`'s new `horn` entry has `"map_char": "!"`.)

- [ ] **Step 3: Tag static obstacles for navigation baking**

In `_build_ground`, right after the existing `add_child(body)` line (the first one, for the ground `StaticBody3D`), add:

```gdscript
	body.add_to_group("nav_source")
```

In `_spawn_rock`, right after its `add_child(body)` line, add the same:

```gdscript
	body.add_to_group("nav_source")
```

In `_spawn_tree`, right after its `add_child(body)` line, add the same:

```gdscript
	body.add_to_group("nav_source")
```

Do **not** add this group to anything else — animals move, so they must never be treated as static navigation-mesh source geometry.

- [ ] **Step 4: Bake navigation after the grid is fully built**

In `_ready()`, right after the existing player-repositioning block (`if player_spawn_found: ...`), add:

```gdscript
	var nav_region := NavigationRegion3D.new()
	add_child(nav_region)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = "nav_source"
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 1.2
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_region.navigation_mesh = nav_mesh
	nav_region.bake_navigation_mesh(true)
```

`bake_navigation_mesh(true)` runs the actual mesh generation on a background thread and returns immediately — do not change this to `false` (see Global Constraints: `false` silently produces an unusable result in this project). No signal connection is needed here: baking finishes a few frames later on its own, and every animal simply sits in `IDLE` (an already-safe, static state) until then, since `nav_agent.target_position` is never set until an animal actually decides to wander/chase/flee, and `NavigationAgent3D.get_next_path_position()` degrades gracefully (returns the agent's current position, causing no movement) when the navigation map has no usable data yet.

- [ ] **Step 5: Add `_spawn_animal` and wire it into the match statement's fallback**

Change the `_:` (default) branch of the `match ch:` block from:

```gdscript
				_:
					var item_data := Items.get_by_map_char(ch)
					if not item_data.is_empty():
						_spawn_pickup(world_pos, item_data)
					elif not SKIP_CHARS.contains(ch):
						_spawn_unknown(world_pos, ch, row, col)
```

to:

```gdscript
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
```

Add a new function (placed anywhere among the other `_spawn_*` functions, e.g., right after `_spawn_build_site`):

```gdscript
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
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, 0.6, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(animal_data["color"])
	mesh_instance.material_override = material
	animal.add_child(mesh_instance)

	var nav_agent := NavigationAgent3D.new()
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
```

Note the order: the `CollisionShape3D`, `MeshInstance3D`, and `NavigationAgent3D` children are all added to `animal`, and all of `animal`'s public fields are assigned, **before** `add_child(animal)` is called on `self` (the `Level` node) at the very end. This is required for the same reason as `build_site.gd`'s `$Marker` (see Global Constraints): `add_child(animal)` is the moment `animal`'s `_ready()` fires, and `_ready()` both resolves `@onready var nav_agent = $NavigationAgent3D` (needs the child to already exist) and calls `_enter_idle()` (harmless either way, but there's no reason to race it — assigning config after the node is already live in the tree would work too, but matching the established "fully configure, then attach" order is the safer, consistent habit this codebase already follows).

- [ ] **Step 6: Verify headless boot**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`

Expected: clean boot, no `SCRIPT ERROR`, no `Parse Error`, and — importantly — no `push_warning` at all (this is the first time `NavigationRegion3D.bake_navigation_mesh(true)` and `animal.gd`'s full `_ready()`/`_physics_process()` actually run for real, exercising the `x`/`w`/`d`/`B` map characters and the new navigation code together for the first time). If you see any warning mentioning cell size mismatches, missing navigation mesh, or a script error inside `animal.gd`, investigate — do not dismiss it as unrelated noise.

- [ ] **Step 7: Commit**

```bash
git add game/world/level_loader.gd
git commit -m "Wire animal spawning and runtime navigation baking into level_loader"
```

- [ ] **Step 8: Note the manual playtest checklist for the human user**

There is no way to verify animal behavior, navigation quality, petting, chasing, knockback, or the horn without actually playing. When reporting this task (or the whole plan) as done, include this checklist for the user:

- Reload the scene / restart Play in the Godot editor.
- A fox, a wolf, and a deer should each wander around near their map position, occasionally stopping — walking toward and around trees/rocks rather than through them (this is the first real test of the navmesh baking).
- Walking close to one of them should make it stop and turn to face you; getting closer still and pressing Enter should pop up a small pink heart and make the animal hop.
- The bear should behave the same way at a distance, but once you get close it should start running at you instead of stopping. Touching it should reduce your energy bar and visibly push you backward; it should not do this more than roughly once per second and a half even if you stay in contact.
- If you keep running from the bear, it should give up and go back to wandering after several seconds.
- Find and pick up the horn (`!` on the map) — it should show up in your resource counters and never disappear. Standing near the bear and pressing Enter (while carrying the horn) should make it turn and flee for a few seconds; immediately pressing Enter again should NOT re-scare it (cooldown).

---

## Self-Review Notes

- **Spec coverage:** every section of `docs/superpowers/specs/2026-09-13-step6-animals.md` maps to a task above — data/autoload (Task 1), player knockback (Task 2), animal FSM (Task 3), level_loader wiring + navigation (Task 4). The spec's "mimo rozsah" (coop, sounds, bigger/generated maps) is intentionally not addressed by any task.
- **Placeholder scan:** no TBD/TODO; every step has literal, complete code.
- **Type consistency:** `animal_data` field names (Task 1's JSON keys) match `animal.gd`'s public var names (Task 3) match `_spawn_animal`'s `.get(key, default)` calls (Task 4) — cross-checked name by name. `apply_knockback(direction, force, duration)`'s signature (Task 2) matches its call site in `animal.gd`'s `_hit_player()` (Task 3, called with 2 args, relying on the third's default). `scare(from_position: Vector3) -> bool` is defined once (Task 3) and not called from `level_loader.gd` in this plan (only from `animal.gd`'s own `_check_horn_use`) — it's exposed publicly for future use (e.g., a dedicated horn item's own script, if step 9's kid-content pass ever wants a different trigger), not dead code, but this plan itself has exactly one caller.
