# Krok 1: Prázdný pastelový les Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build roadmap step 1 from CLAUDE.md — an empty pastel forest (terrain, sky, light) with Player 1 walking and jumping (arrow keys + spacebar) and a third-person chase camera.

**Architecture:** A `Forest.tscn` world scene holds environment/light/ground plus instances of a standalone `Player.tscn` (CharacterBody3D) and a `CoopCamera` (a `Camera3D` with a follow script). Movement reads from InputMap actions (`p1_move_*`, `p1_jump`), never hardcoded keys, and colors come from a shared `Palette` script.

**Tech Stack:** Godot 4.7.2 (GDScript, static typing), Jolt Physics (already configured in `project.godot`).

**Spec:** `docs/superpowers/specs/2026-09-12-step1-empty-forest.md`

## Global Constraints

- Godot version: 4.7 (project already configured; engine binary at `godot-editor/Godot_v4.7.2-stable_win64_console.exe` relative to repo root).
- GDScript with static typing throughout (`CLAUDE.md`: "statické typování").
- Never hardcode keys — all input goes through InputMap actions named `p1_move_forward`, `p1_move_back`, `p1_move_left`, `p1_move_right`, `p1_jump`.
- Colors come from `game/theme/palette.gd`, not literals scattered in scenes.
- The world in this step must stay empty (no trees/rocks/animals) — those arrive in roadmap step 2.
- After every `.tscn` edit, remind the user (who has the Godot editor open on this same project) to reload the scene.
- Verify with `./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit` (run from repo root) after every task — it must exit with no error output. This catches parse/script errors only; actual movement/camera feel needs the user to press Play in their open editor and try it — say so explicitly rather than claiming it "works."

---

### Task 1: World scaffolding — palette, sky, light, ground

**Files:**
- Create: `game/theme/palette.gd`
- Create: `game/world/forest.gd`
- Create: `game/world/Forest.tscn`
- Modify: `project.godot` (add `run/main_scene` under `[application]`)

**Interfaces:**
- Produces: `class_name Palette` with constants `Palette.PASTEL_GREEN`, `Palette.SKY_BLUE`, `Palette.PEACH`, `Palette.LAVENDER`, `Palette.CREAM` (all `Color`), consumed by Task 2's ground/player materials and any later UI work.
- Produces: `res://game/world/Forest.tscn`, a `Node3D` root that Task 2 will add `Player1` and `CoopCamera` children to.

- [ ] **Step 1: Write the palette script**

Create `game/theme/palette.gd`:

```gdscript
class_name Palette
extends RefCounted

const PASTEL_GREEN := Color(0.6588, 0.8784, 0.6275)
const SKY_BLUE := Color(0.6588, 0.8471, 0.9412)
const PEACH := Color(1.0, 0.8392, 0.7020)
const LAVENDER := Color(0.8471, 0.7843, 0.9098)
const CREAM := Color(1.0, 0.9725, 0.9059)
```

- [ ] **Step 2: Write the forest script**

`.tscn` text has no clean way to set a `StandardMaterial3D` color from a shared constant, so the ground material is applied from a small script instead — this keeps `Palette` as the single source of truth instead of duplicating a raw `Color` in the `.tscn`.

Create `game/world/forest.gd`:

```gdscript
extends Node3D

func _ready() -> void:
	var ground_mesh: MeshInstance3D = $Ground/MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PASTEL_GREEN
	ground_mesh.material_override = material
```

- [ ] **Step 3: Write the Forest scene**

Create `game/world/Forest.tscn`:

```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://game/world/forest.gd" id="1_forest"]

[sub_resource type="ProceduralSkyMaterial" id="SkyMat_1"]
sky_top_color = Color(0.5529, 0.7529, 0.9216, 1)
sky_horizon_color = Color(0.7529, 0.8510, 0.9490, 1)

[sub_resource type="Sky" id="Sky_1"]
sky_material = SubResource("SkyMat_1")

[sub_resource type="Environment" id="Env_1"]
background_mode = 2
sky = SubResource("Sky_1")
ambient_light_source = 3
ambient_light_color = Color(0.8471, 0.9020, 0.9490, 1)
ambient_light_energy = 0.6

[sub_resource type="BoxShape3D" id="GroundShape_1"]
size = Vector3(100, 1, 100)

[sub_resource type="BoxMesh" id="GroundMesh_1"]
size = Vector3(100, 1, 100)

[node name="Forest" type="Node3D"]
script = ExtResource("1_forest")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_1")

[node name="Sun" type="DirectionalLight3D" parent="."]
position = Vector3(0, 5, 0)
rotation_degrees = Vector3(-45, 30, 0)
light_color = Color(1, 0.96, 0.9, 1)
light_energy = 1.0
shadow_enabled = true

[node name="Ground" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="Ground"]
position = Vector3(0, -0.5, 0)
shape = SubResource("GroundShape_1")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Ground"]
position = Vector3(0, -0.5, 0)
mesh = SubResource("GroundMesh_1")
```

- [ ] **Step 4: Set the main scene**

In `project.godot`, under `[application]`, add a line so the section reads:

```
[application]

config/name="zola-game-1"
config/features=PackedStringArray("4.7", "Mobile")
config/icon="res://icon.svg"
run/main_scene="res://game/world/Forest.tscn"
```

- [ ] **Step 5: Verify headless boot**

Run from the repo root:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: exits with no `SCRIPT ERROR` / `Parse Error` / `res://... not found` lines. Godot always prints some informational lines (renderer, "Redirecting stderr...", etc.) on Windows — those are fine; only script/scene errors mean the task isn't done.

- [ ] **Step 6: Ask the user to look at the scene**

Tell the user: reload `game/world/Forest.tscn` in the open editor if it was already open (or just open it), and look at the 3D viewport — they should see a large pastel-green ground plane under a soft blue sky with a directional light casting soft shadows. No need to press Play yet (no camera exists until Task 2).

- [ ] **Step 7: Commit**

```bash
git add game/theme/palette.gd game/world/Forest.tscn game/world/forest.gd project.godot
git commit -m "Add empty pastel forest world: sky, light, ground"
```

---

### Task 2: Player movement, jump, and chase camera

**Files:**
- Modify: `project.godot` (add `[input]` section)
- Create: `game/player/player.gd`
- Create: `game/player/Player.tscn`
- Create: `game/camera/coop_camera.gd`
- Modify: `game/world/Forest.tscn` (add `Player1` and `CoopCamera` nodes)

**Interfaces:**
- Consumes: `Palette.PEACH` from Task 1's `game/theme/palette.gd`; `game/world/Forest.tscn` root `Node3D` from Task 1.
- Produces: `class_name Player extends CharacterBody3D` with `@export var player_number: int`, added to group `"players"` — consumed by `CoopCamera` (finds its target via `get_tree().get_nodes_in_group("players")`) and by any later HUD/coop work that needs to enumerate players.
- Produces: `class_name CoopCamera extends Camera3D` — self-contained, no other task depends on its internals yet (step 7 will extend `_find_target`/`_process` to average multiple players).

- [ ] **Step 1: Add the InputMap actions**

In `project.godot`, add a new `[input]` section (after `[physics]`, before `[rendering]` works fine, order of top-level sections doesn't matter to Godot):

```
[input]

p1_move_forward={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
p1_move_back={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
p1_move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
p1_move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
p1_jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

(`physical_keycode` values: 4194319=Left, 4194320=Up, 4194321=Right, 4194322=Down, 32=Space — Godot 4's `Key` enum.)

- [ ] **Step 2: Write the player script**

Create `game/player/player.gd`:

```gdscript
class_name Player
extends CharacterBody3D

const Palette = preload("res://game/theme/palette.gd")

@export var player_number: int = 1
@export var move_speed: float = 4.0
@export var jump_velocity: float = 5.0
@export var turn_speed: float = 10.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _ready() -> void:
	add_to_group("players")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(_action("jump")):
		velocity.y = jump_velocity

	var move_direction := _get_move_direction()
	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed

	if move_direction.length() > 0.01:
		var target_angle := atan2(move_direction.x, move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)

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

- [ ] **Step 3: Write the Player scene**

Create `game/player/Player.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://game/player/player.gd" id="1_script"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape_1"]
radius = 0.4
height = 1.6

[sub_resource type="CapsuleMesh" id="CapsuleMesh_1"]
radius = 0.4
height = 1.6

[node name="Player" type="CharacterBody3D"]
script = ExtResource("1_script")
player_number = 1

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
position = Vector3(0, 0.8, 0)
shape = SubResource("CapsuleShape_1")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.8, 0)
mesh = SubResource("CapsuleMesh_1")
```

The mesh's peach placeholder color is set from code in Step 4's `player.gd` addition below (keeps `Palette` as the single source of truth instead of duplicating a raw `Color` in the `.tscn`). Note: `Palette` is referenced via the `const Palette = preload(...)` line already added at the top of `player.gd` in Step 2 — Task 1's review found that Godot 4.7.2's `class_name` global registration only takes effect after the project has been opened once in the full editor GUI (this project has so far only been run headless), so a bare `Palette.PEACH` reference would fail to resolve until then. Using `preload` sidesteps that entirely.

Add to `game/player/player.gd`, inside `_ready()`:

```gdscript
func _ready() -> void:
	add_to_group("players")
	var mesh_instance: MeshInstance3D = $MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PEACH
	mesh_instance.material_override = material
```

(Replace the whole `_ready()` function from Step 2 with this version — same signature, just adds the two lookup lines.)

- [ ] **Step 4: Write the camera script**

Create `game/camera/coop_camera.gd`:

```gdscript
class_name CoopCamera
extends Camera3D

@export var follow_distance: float = 4.0
@export var follow_height: float = 2.5
@export var follow_speed: float = 5.0

var _target: Node3D

func _ready() -> void:
	current = true
	call_deferred("_find_target")

func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_target = players[0]

func _process(delta: float) -> void:
	if _target == null:
		_find_target()
		return

	var target_pos: Vector3 = _target.global_transform.origin
	var forward: Vector3 = -_target.global_transform.basis.z
	forward.y = 0.0
	if forward.length() > 0.001:
		forward = forward.normalized()

	var desired_pos: Vector3 = target_pos - forward * follow_distance + Vector3.UP * follow_height
	var t: float = clamp(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired_pos, t)
	look_at(target_pos + Vector3.UP * 1.0, Vector3.UP)
```

- [ ] **Step 5: Wire Player1 and CoopCamera into Forest.tscn**

Edit `game/world/Forest.tscn`. Bump `load_steps` again (from 7 to 9) and add two `ext_resource` lines after the existing ones:

```
[ext_resource type="Script" path="res://game/camera/coop_camera.gd" id="2_camera"]
[ext_resource type="PackedScene" path="res://game/player/Player.tscn" id="3_player"]
```

Add two nodes at the end of the file (children of `Forest`, i.e. `parent="."`):

```
[node name="CoopCamera" type="Camera3D" parent="."]
script = ExtResource("2_camera")
position = Vector3(0, 3, 5)

[node name="Player1" parent="." instance=ExtResource("3_player")]
position = Vector3(0, 0.05, 0)
```

- [ ] **Step 6: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error` lines.

- [ ] **Step 7: Ask the user to playtest**

Tell the user: reload `game/world/Forest.tscn` if open, then press Play. They should see a peach capsule standing on the green ground, and be able to:
- move it with arrow keys (it should turn to face the direction it's walking)
- jump with spacebar
- see the camera follow from behind/above, turning to stay behind the capsule as it turns

Correction from the final whole-branch review: the earlier note here suggested flipping the sign in `coop_camera.gd` if the camera looked wrong. That was the wrong file — `coop_camera.gd`'s math is correct. The actual bug was a 180°-inverted sign in `player.gd`'s `atan2(move_direction.x, move_direction.z)` (should be `atan2(-move_direction.x, -move_direction.z)`), which made the player face backward and, combined with the camera deriving its offset from the player's facing, created an unstable oscillation loop. Fixed directly in the code (see ledger). No camera-file fix needed — if the camera ever looks wrong after this, the bug is elsewhere.

- [ ] **Step 8: Commit**

```bash
git add project.godot game/player/player.gd game/player/Player.tscn game/camera/coop_camera.gd game/world/Forest.tscn
git commit -m "Add player movement, jump, and third-person chase camera"
```

---

### Task 3: CC0 character placeholder (optional, can be skipped if sourcing fails)

**Files:**
- Create: `assets/models/` (downloaded `.glb`)
- Create: `assets/CREDITS.md`
- Modify: `game/player/Player.tscn` (swap capsule mesh for the character model, only if this task succeeds)

**Interfaces:**
- Consumes: `game/player/Player.tscn` and `player.gd` from Task 2 (the `CharacterBody3D` root and its `CollisionShape3D` sizing stay unchanged — only the visual mesh child changes).
- Produces: nothing new consumed by other tasks — this is a leaf, visual-only change.

- [ ] **Step 1: Find a CC0 character model**

Use the WebSearch tool to find a free-to-use (CC0) low-poly humanoid character pack on `quaternius.com`, suitable for a children's game (simple, rounded, non-realistic), that includes at least idle and walk animations. Confirm the license is explicitly CC0 (public domain, no attribution required) on the page before downloading — if unclear, pick a different pack rather than guessing.

- [ ] **Step 2: Download and extract**

Download the pack's `.zip` (or direct `.glb`, if offered) with `curl` into a scratch location, extract it, and pick one character `.glb` file. Copy it to `assets/models/character_placeholder.glb`.

If the download fails, the site structure has changed, or nothing suitable is found after a reasonable search: stop here, leave Task 2's peach capsule as the player's visual, and tell the user this task didn't pan out — don't block on it.

- [ ] **Step 3: Add the credit entry**

Create `assets/CREDITS.md` (or append if it already exists from a parallel task) with:

```markdown
# Asset Credits

| Asset | Source | License | Author |
|---|---|---|---|
| `models/character_placeholder.glb` | quaternius.com | CC0 | Quaternius |
```

(Fill in the actual pack name/URL you used in place of the generic row above.)

- [ ] **Step 4: Swap the mesh in Player.tscn**

In `game/player/Player.tscn`, replace the `MeshInstance3D` sub-resource-based mesh with an instance of the downloaded `.glb` as a child scene, keeping the existing `CollisionShape3D` (capsule) as the collision body. Remove the `material_override` code added in Task 2 Step 3 from `player.gd`'s `_ready()` (the imported model brings its own materials) — keep the `add_to_group("players")` line.

- [ ] **Step 5: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no import/parse errors for the new `.glb`.

- [ ] **Step 6: Ask the user to look**

Tell the user to reload the scene and press Play — they should see the real character model instead of the peach capsule, walking/idling appropriately if animations were wired up.

- [ ] **Step 7: Commit**

```bash
git add assets/models/character_placeholder.glb assets/CREDITS.md game/player/Player.tscn game/player/player.gd
git commit -m "Replace player placeholder capsule with CC0 character model"
```
