# Low-poly visual style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace procedural primitive-mesh visuals (trees, rocks, fox, wolf, deer) with real CC0 low-poly models from the Kenney Nature Kit and Quaternius Ultimate Animated Animal Pack, without changing any collision, physics, or gameplay behavior.

**Architecture:** Environment props (`_spawn_rock`/`_spawn_tree` in `level_loader.gd`) keep their existing invisible collision bodies and only swap the visible `MeshInstance3D` for a randomly-picked imported `.glb` scene. Animals reuse the already-existing but currently-unused `model_path`/model-instancing code path in `_spawn_animal()`, extended with a `model_scale` field; `animal.gd` gains a small, fully-defensive animation layer that only activates when a real model (with an `AnimationPlayer`) is present, so the procedural bear is completely unaffected.

**Tech Stack:** Godot 4.7.2, GDScript with static typing, no automated test framework — verification is a headless boot plus manual playtest, per this project's established convention.

**Spec:** `docs/superpowers/specs/2026-09-13-lowpoly-visual-style.md`

## Global Constraints

- Collision shapes for rocks (`BoxShape3D` 2×2×2) and tree trunks (`CylinderShape3D` radius 0.4, height 2.0) must not change — only the visual mesh changes.
- No gameplay-logic change: movement, collision, energy drain, the animal idle/wander/look/chase/flee state machine, and pet/horn mechanics are unchanged.
- The bear entry in `data/animals.json` must not get a `model_path` or `model_scale` key — it must keep using today's procedural capsule + `_add_animal_features("bear", ...)` path, completely unaffected by this work.
- All new asset files already exist in the repo (committed in `19c3ef1`): `assets/models/nature/{tree_pineRoundA,tree_pineRoundC,tree_pineTallA,tree_pineTallC,rock_smallA,rock_smallD,rock_largeA,rock_largeD}.glb` and `assets/models/animals/{Fox,Wolf,Deer}.gltf`. No downloading or copying — reference them by path.
- Verify every task with: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit` — must show no `SCRIPT ERROR` / `Parse Error` in the output. The project's main scene is `res://game/world/Forest.tscn` (see `project.godot`'s `run/main_scene`), which loads `levels/forest_01.txt` — a map that already contains rock (`#`), tree (`T`), fox (`x`), wolf (`w`), deer (`d`), and bear (`B`) tiles, so this one boot command exercises every code path this plan touches.
- Animation playback, model scale/proportions, and general appearance cannot be verified by a headless boot — flag this explicitly as a manual-playtest follow-up, never claim it's verified by the boot command.
- Do not add error handling or fallbacks beyond what's specified below (e.g. `has_animation` checks) — no speculative validation.

---

## File Structure

- **Modify `game/world/level_loader.gd`**: `_spawn_rock`/`_spawn_tree` swap their visual mesh construction for random model instancing (Task 1); `_spawn_animal` gains one new line applying `model_scale` (Task 2).
- **Modify `data/animals.json`**: add `model_path`/`model_scale` to the fox, wolf, and deer entries (Task 2).
- **Modify `game/animals/animal.gd`**: add animation-player lookup and state-driven playback (Task 3).

No new files are created (the asset files and `assets/CREDITS.md` already exist from the design phase).

---

### Task 1: Environment props — real low-poly trees and rocks

**Files:**
- Modify: `game/world/level_loader.gd` (the `_spawn_rock` function, currently lines ~173-194, and the `_spawn_tree` function, currently lines ~196-232 — line numbers are approximate; locate by function name, since exact lines will have shifted if other tasks land first)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a new private helper `_add_random_model(parent: Node3D, models: Array[Dictionary]) -> void` in `level_loader.gd`, used only within this file. Not consumed by Task 2 or Task 3.

- [ ] **Step 1: Read the current functions to confirm exact text**

Open `game/world/level_loader.gd` and find `_spawn_rock` and `_spawn_tree`. They currently look like this:

```gdscript
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
```

- [ ] **Step 2: Add the model tables and helper, and rewrite both functions**

Near the top of the file, after the existing `const TILE_SIZE := 2.0` line, add:

```gdscript
const ROCK_MODELS: Array[Dictionary] = [
	{"path": "res://assets/models/nature/rock_smallA.glb", "scale": 2.2},
	{"path": "res://assets/models/nature/rock_smallD.glb", "scale": 2.2},
	{"path": "res://assets/models/nature/rock_largeA.glb", "scale": 1.6},
	{"path": "res://assets/models/nature/rock_largeD.glb", "scale": 1.6},
]

const TREE_MODELS: Array[Dictionary] = [
	{"path": "res://assets/models/nature/tree_pineRoundA.glb", "scale": 1.9},
	{"path": "res://assets/models/nature/tree_pineRoundC.glb", "scale": 1.9},
	{"path": "res://assets/models/nature/tree_pineTallA.glb", "scale": 1.75},
	{"path": "res://assets/models/nature/tree_pineTallC.glb", "scale": 1.75},
]
```

Replace the whole body of `_spawn_rock` and `_spawn_tree` (keeping the collision setup exactly as it is, only removing the `MeshInstance3D`-building code below it) with:

```gdscript
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
```

Note the model's own position stays at the default `Vector3.ZERO` relative to `body` (which is already placed at `pos`, ground level) — the Kenney models are authored with their base at ground level, unlike the old primitive meshes which were centered at `y = 1.0`.

The `Palette` constant is still used elsewhere in this file (e.g. `_spawn_water`), so do not remove its `preload` even though the tree crown color that used it is gone.

- [ ] **Step 3: Verify with a headless boot**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`

Expected: the import pipeline picks up the (already-committed) `.glb` files without needing any action, and the console output ends with no `SCRIPT ERROR` or `Parse Error` lines. `forest_01.txt` contains multiple `#` (rock) and `T` (tree) tiles, so this boot instantiates `_spawn_rock`/`_spawn_tree` for real.

- [ ] **Step 4: Commit**

```bash
git add game/world/level_loader.gd
git commit -m "Replace procedural tree/rock meshes with Kenney low-poly models"
```

---

### Task 2: Animal data — wire up fox/wolf/deer models and scale

**Files:**
- Modify: `data/animals.json`
- Modify: `game/world/level_loader.gd` (the `_spawn_animal` function, currently lines ~322-378 — locate by function name)

**Interfaces:**
- Consumes: nothing from Task 1 (different function in the same file).
- Produces: the `model_scale` field convention in `data/animals.json`, and the fact that the instantiated model node now has its `scale` property set before `_spawn_animal` adds it as a child — Task 3 does not depend on this directly (its animation code works regardless of the model's `scale`), but Task 3's headless-boot verification is only meaningful for real models if this task lands first, so do this task before Task 3.

- [ ] **Step 1: Update `data/animals.json`**

The file currently reads:

```json
{
  "animals": [
    { "id": "fox", "name": "Liška", "map_char": "x", "color": "#E07A3E", "shape": "fox", "aggressive": false, "move_speed": 1.5, "wander_radius": 4.0, "notice_radius": 4.0, "pet_radius": 1.5 },
    { "id": "wolf", "name": "Vlk", "map_char": "w", "color": "#6E6E6E", "shape": "wolf", "aggressive": false, "move_speed": 1.5, "wander_radius": 4.0, "notice_radius": 4.0, "pet_radius": 1.5 },
    { "id": "deer", "name": "Srnka", "map_char": "d", "color": "#A9754F", "shape": "deer", "aggressive": false, "move_speed": 1.8, "wander_radius": 5.0, "notice_radius": 5.0, "pet_radius": 1.5 },
    { "id": "bear", "name": "Medvěd", "map_char": "B", "color": "#5C4028", "shape": "bear", "aggressive": true, "move_speed": 1.2, "wander_radius": 4.0, "chase_radius": 6.0, "chase_speed": 3.0, "catch_radius": 1.2, "give_up_time": 8.0, "energy_drain_on_hit": 15.0, "knockback_force": 6.0, "flee_speed": 4.0, "flee_duration": 4.0, "horn_radius": 6.0, "horn_cooldown": 3.0 }
  ]
}
```

Replace it with (only the fox, wolf, and deer lines change — `model_path` and `model_scale` are added; the `bear` line is untouched):

```json
{
  "animals": [
    { "id": "fox", "name": "Liška", "map_char": "x", "color": "#E07A3E", "shape": "fox", "aggressive": false, "move_speed": 1.5, "wander_radius": 4.0, "notice_radius": 4.0, "pet_radius": 1.5, "model_path": "res://assets/models/animals/Fox.gltf", "model_scale": 0.45 },
    { "id": "wolf", "name": "Vlk", "map_char": "w", "color": "#6E6E6E", "shape": "wolf", "aggressive": false, "move_speed": 1.5, "wander_radius": 4.0, "notice_radius": 4.0, "pet_radius": 1.5, "model_path": "res://assets/models/animals/Wolf.gltf", "model_scale": 0.5 },
    { "id": "deer", "name": "Srnka", "map_char": "d", "color": "#A9754F", "shape": "deer", "aggressive": false, "move_speed": 1.8, "wander_radius": 5.0, "notice_radius": 5.0, "pet_radius": 1.5, "model_path": "res://assets/models/animals/Deer.gltf", "model_scale": 0.35 },
    { "id": "bear", "name": "Medvěd", "map_char": "B", "color": "#5C4028", "shape": "bear", "aggressive": true, "move_speed": 1.2, "wander_radius": 4.0, "chase_radius": 6.0, "chase_speed": 3.0, "catch_radius": 1.2, "give_up_time": 8.0, "energy_drain_on_hit": 15.0, "knockback_force": 6.0, "flee_speed": 4.0, "flee_duration": 4.0, "horn_radius": 6.0, "horn_cooldown": 3.0 }
  ]
}
```

- [ ] **Step 2: Apply `model_scale` in `_spawn_animal`**

`game/world/level_loader.gd`'s `_spawn_animal` currently has this block:

```gdscript
	var color := Color.html(animal_data["color"])
	var model_path: String = animal_data.get("model_path", "")
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		var model: Node3D = model_scene.instantiate()
		model.name = "Mesh"
		model.position = Vector3(0, 0.6, 0)
		animal.add_child(model)
	else:
```

Add one line so it reads:

```gdscript
	var color := Color.html(animal_data["color"])
	var model_path: String = animal_data.get("model_path", "")
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		var model: Node3D = model_scene.instantiate()
		model.name = "Mesh"
		model.position = Vector3(0, 0.6, 0)
		model.scale = Vector3.ONE * float(animal_data.get("model_scale", 1.0))
		animal.add_child(model)
	else:
```

(The `else` branch — the procedural capsule/features fallback used by the bear — is unchanged.)

- [ ] **Step 3: Verify with a headless boot**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`

Expected: no `SCRIPT ERROR` or `Parse Error`. `forest_01.txt` contains `x` (fox), `w` (wolf), `d` (deer), and `B` (bear) tiles, so this exercises both the new model-loading-with-scale path and confirms the bear still falls through to the untouched procedural `else` branch.

- [ ] **Step 4: Commit**

```bash
git add data/animals.json game/world/level_loader.gd
git commit -m "Wire up real fox/wolf/deer models with per-species scale"
```

---

### Task 3: Animal animation playback

**Files:**
- Modify: `game/animals/animal.gd`

**Interfaces:**
- Consumes: `mesh_node` (existing `@onready var mesh_node: Node3D = $Mesh`, populated by Task 2's `_spawn_animal` — for fox/wolf/deer this is the instantiated Quaternius scene root, which contains a descendant `AnimationPlayer`; for the bear this is a plain `MeshInstance3D` with no `AnimationPlayer` descendant).
- Produces: nothing consumed by other tasks — this is the last task in the plan.

- [ ] **Step 1: Add the `_anim_player` variable**

`game/animals/animal.gd` currently has this block:

```gdscript
var _pet_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_spawn_position = global_position
	_enter_idle()
```

Replace it with:

```gdscript
var _pet_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()
var _anim_player: AnimationPlayer = null

func _ready() -> void:
	_rng.randomize()
	_spawn_position = global_position
	_anim_player = _find_anim_player()
	_setup_animations()
	_enter_idle()
```

- [ ] **Step 2: Add the animation helper functions**

Immediately before the existing `func _enter_idle() -> void:` function, add:

```gdscript
func _find_anim_player() -> AnimationPlayer:
	var found: Array = mesh_node.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return null
	return found[0]

func _setup_animations() -> void:
	if _anim_player == null:
		return
	for loop_name in ["Idle", "Walk"]:
		if _anim_player.has_animation(loop_name):
			_anim_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	if _anim_player.has_animation("Eating"):
		_anim_player.get_animation("Eating").loop_mode = Animation.LOOP_NONE
	_anim_player.animation_finished.connect(_on_animation_finished)

func _play_anim(anim_name: String) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	if _anim_player.current_animation != anim_name or not _anim_player.is_playing():
		_anim_player.play(anim_name)

func _play_state_animation() -> void:
	match _state:
		State.IDLE, State.LOOK:
			_play_anim("Idle")
		State.WANDER:
			_play_anim("Walk")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Eating":
		_play_state_animation()
```

(`Idle`/`Walk` are forced to `Animation.LOOP_LINEAR` because glTF has no native "loop" flag and Godot's importer defaults imported clips to play once — without this, animals would freeze on the last frame of their locomotion animation after one cycle. `Eating` is forced to `Animation.LOOP_NONE` so `animation_finished` reliably fires exactly once when it completes, which is what `_on_animation_finished` depends on to resume normal playback.)

- [ ] **Step 3: Hook the state transitions**

`_enter_idle` currently reads:

```gdscript
func _enter_idle() -> void:
	_state = State.IDLE
	_idle_timer = _rng.randf_range(IDLE_MIN_TIME, IDLE_MAX_TIME)
	velocity.x = 0.0
	velocity.z = 0.0
```

Add a call at the end:

```gdscript
func _enter_idle() -> void:
	_state = State.IDLE
	_idle_timer = _rng.randf_range(IDLE_MIN_TIME, IDLE_MAX_TIME)
	velocity.x = 0.0
	velocity.z = 0.0
	_play_state_animation()
```

`_enter_wander` currently reads:

```gdscript
func _enter_wander() -> void:
	_state = State.WANDER
	var offset := Vector3(
		_rng.randf_range(-wander_radius, wander_radius),
		0.0,
		_rng.randf_range(-wander_radius, wander_radius)
	)
	nav_agent.target_position = _spawn_position + offset
```

Add a call at the end:

```gdscript
func _enter_wander() -> void:
	_state = State.WANDER
	var offset := Vector3(
		_rng.randf_range(-wander_radius, wander_radius),
		0.0,
		_rng.randf_range(-wander_radius, wander_radius)
	)
	nav_agent.target_position = _spawn_position + offset
	_play_state_animation()
```

`_check_aggro_or_notice` currently reads:

```gdscript
func _check_aggro_or_notice() -> bool:
	var dist := _distance_to_player()
	if aggressive:
		if _calm_timer <= 0.0 and dist <= chase_radius:
			_enter_chase()
			return true
	elif dist <= notice_radius:
		_state = State.LOOK
		return true
	return false
```

Add a call in the `elif` branch:

```gdscript
func _check_aggro_or_notice() -> bool:
	var dist := _distance_to_player()
	if aggressive:
		if _calm_timer <= 0.0 and dist <= chase_radius:
			_enter_chase()
			return true
	elif dist <= notice_radius:
		_state = State.LOOK
		_play_state_animation()
		return true
	return false
```

- [ ] **Step 4: Play "Eating" when petted**

`_play_pet_effect` currently starts like this:

```gdscript
func _play_pet_effect() -> void:
	var hop := create_tween()
	hop.tween_property(mesh_node, "scale", HOP_SCALE, 0.1)
	hop.tween_property(mesh_node, "scale", Vector3.ONE, 0.15)
```

Add a call at the top of the function:

```gdscript
func _play_pet_effect() -> void:
	_play_anim("Eating")
	var hop := create_tween()
	hop.tween_property(mesh_node, "scale", HOP_SCALE, 0.1)
	hop.tween_property(mesh_node, "scale", Vector3.ONE, 0.15)
```

(The rest of `_play_pet_effect` — the heart particle effect — is unchanged. Petting only happens in `State.LOOK`, per the existing `_process_look` code that calls this function, so when `_on_animation_finished` resumes state-driven playback after "Eating" completes, `_play_state_animation()` correctly plays "Idle" again since `_state` is still `LOOK`.)

- [ ] **Step 5: Verify with a headless boot**

Run: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit`

Expected: no `SCRIPT ERROR` or `Parse Error`. This confirms the script compiles and that `_find_anim_player()`/`_setup_animations()` run without error for all four animal types in `forest_01.txt` — including the bear, where `_find_anim_player()` must return `null` (no `AnimationPlayer` under a plain `MeshInstance3D`) and every subsequent `_play_anim` call must silently no-op.

This does **not** verify that animations actually play correctly, that "Idle"/"Walk" loop smoothly, or that "Eating" plays once and resumes correctly — that requires watching the game run.

- [ ] **Step 6: Commit**

```bash
git add game/animals/animal.gd
git commit -m "Add state-driven animation playback for fox/wolf/deer models"
```

---

## Manual Playtest Follow-Up (not automatable)

After all three tasks land, ask the user to open the game and check:

1. Trees and rocks look like real low-poly models (not boxes/cylinders) and are reasonably sized against the player and the 2 m tile grid — adjust the `scale` values in `ROCK_MODELS`/`TREE_MODELS` (Task 1) if they look too small/large.
2. Fox, wolf, and deer look like real animated animals, roughly the size of the old capsule collider, and visibly play an idle animation when standing still and a walk animation when wandering — adjust `model_scale` in `data/animals.json` (Task 2) if they look too small/large.
3. Petting a fox/wolf/deer plays a distinct "eating" animation briefly, then returns to idle — it should not get stuck playing "eating" forever, and should not glitch/freeze.
4. The bear is completely unaffected — still the procedural capsule with round ears, still chases/flees exactly as before.

## Self-Review

**Spec coverage:** Environment integration (spec's table + collision-preservation rule) → Task 1. Animal integration's `model_path`/`model_scale` data wiring → Task 2. Animal integration's animation-playback contract (Idle/Walk/Eating, bear unaffected) → Task 3. Asset acquisition/CREDITS → already done in the design phase, no task needed. Testing convention (headless boot + manual playtest) → verification step in every task plus the final Manual Playtest Follow-Up section. No spec section is uncovered.

**Placeholder scan:** No TBD/TODO markers; every step has literal code or JSON to write; every test step names the exact command and expected result.

**Type consistency:** `ROCK_MODELS`/`TREE_MODELS` are `Array[Dictionary]` with `"path"` (String) and `"scale"` (float, read via `float(choice["scale"])`) in both declaration (Task 1) and use — consistent. `model_scale` is read the same way (`float(animal_data.get("model_scale", 1.0))`) in Task 2 as it's written in `data/animals.json` (a JSON number, which GDScript's JSON parser yields as float/int convertible via `float()`). `_anim_player`'s type (`AnimationPlayer`, nullable) and every function that reads it (`_play_anim`, `_setup_animations`, `_on_animation_finished`) agree in Task 3.
