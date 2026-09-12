# Krok 2: Level loader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build roadmap step 2 from CLAUDE.md — load `levels/forest_01.txt` and spawn trees/rocks/water/campfire/player-start from it, replacing step 1's flat hardcoded ground, and fix the chase camera so it no longer couples to the player's facing (a known bug from step 1) and gets obstacle-avoidance for the trees/rocks this step adds.

**Architecture:** Task 1 reworks `CoopCamera` into a `Node3D` + `SpringArm3D` + `Camera3D` rig that only translates (never rotates) to follow the player, independent of anything level-related. Task 2 adds `game/world/level_loader.gd` on a new `Level` node that parses the map text file at `_ready()` and spawns primitive meshes (with `Palette` colors) for each recognized tile, rebuilds the ground to match the map's size, and repositions the player to the map's start tile.

**Tech Stack:** Godot 4.7.2 (GDScript, static typing), Jolt Physics.

**Spec:** `docs/superpowers/specs/2026-09-12-step2-level-loader.md`

## Global Constraints

- GDScript with static typing throughout.
- `TILE_SIZE = 2.0` — tile `(row, col)` (0-indexed from the top-left of the text file) sits at world position `Vector3(col * TILE_SIZE, 0, row * TILE_SIZE)`. No centering.
- Colors come from `game/theme/palette.gd` where a `Palette` constant exists for them (ground, water); one-off colors not part of the game's core theme (rock gray, tree trunk brown, tree crown green-darkened, campfire orange, unknown-tile magenta) are literals local to `level_loader.gd`, matching the spec's table.
- Map characters this step implements: `.` `#` `T` `~` `F` `P`. Characters documented in `levels/CLAUDE.md`'s legend but not yet implemented (`m b r u a n k x w d B !`, `H`/`S`, and bare digits `0`-`9` — see spec's note on why `H1`/`S1` split into two independently-skipped characters) are silently skipped: no spawn, no warning. Anything else triggers `push_warning()` plus a magenta placeholder box — never a crash.
- Map rows may have ragged lengths (short rows are padded with `.` / grass) — never index out of bounds.
- `godot --headless --path . --quit` (binary: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe`, run from repo root) must exit with no `SCRIPT ERROR` / `Parse Error` after every task. There is no automated test framework for this project — that command plus a manual playtest by the user (who has the Godot editor open on this same project directory — remind them to reload `.tscn` files after edits) are the only verification available. Never claim visual/gameplay correctness beyond what headless boot can prove.

---

### Task 1: Camera rework — fixed-offset rig with obstacle avoidance

**Files:**
- Modify: `game/camera/coop_camera.gd` (full rewrite)
- Modify: `game/world/Forest.tscn` (restructure the `CoopCamera` node only — nothing else in this file changes)

**Interfaces:**
- Consumes: the `"players"` group (already populated by `Player._ready()` in `game/player/player.gd`, unchanged).
- Produces: `class_name CoopCamera extends Node3D` (was `extends Camera3D`) — no other task or file references `CoopCamera` by type, confirmed via repo-wide search, so this is a safe breaking change to the class's base type.

This task is fully independent of Task 2 — it works correctly against the existing flat step-1 world, and is testable on its own (the "no circling" behavior is visible with or without trees).

- [ ] **Step 1: Rewrite the camera script**

Replace the full contents of `game/camera/coop_camera.gd` with:

```gdscript
class_name CoopCamera
extends Node3D

@export var follow_speed: float = 5.0

var _target: Node3D

func _ready() -> void:
	call_deferred("_find_target")

func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_target = players[0] as Node3D

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_find_target()
		return

	var target_pos: Vector3 = _target.global_transform.origin
	var t: float = clamp(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(target_pos, t)
```

The rig never rotates — it only translates its own position toward the player's position. The downward tilt and follow distance move to the `SpringArm3D` in Step 2 (fixed values, not runtime logic), which is also what gives the camera obstacle collision for free.

- [ ] **Step 2: Restructure the CoopCamera node in Forest.tscn**

Current `game/world/Forest.tscn` has this node (verify against the live file before editing — this is exactly what step 1 left it as):

```
[node name="CoopCamera" type="Camera3D" parent="."]
script = ExtResource("2_camera")
position = Vector3(0, 3, 5)
```

Replace it with:

```
[node name="CoopCamera" type="Node3D" parent="."]
script = ExtResource("2_camera")

[node name="SpringArm3D" type="SpringArm3D" parent="CoopCamera"]
position = Vector3(0, 1.6, 0)
rotation_degrees = Vector3(-20, 0, 0)
spring_length = 4.0

[node name="Camera3D" type="Camera3D" parent="CoopCamera/SpringArm3D"]
current = true
```

Nothing else in the file changes — `load_steps`, the `ext_resource`/`sub_resource` blocks, `WorldEnvironment`, `Sun`, `Ground`, and `Player1` all stay exactly as they are. The `2_camera` ext_resource still points at the same `coop_camera.gd` path, so no `ext_resource` line changes.

- [ ] **Step 3: Verify headless boot**

Run from the repo root:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error` lines.

- [ ] **Step 4: Ask the user to playtest**

Tell the user: reload `game/world/Forest.tscn` in the editor, press Play, and try arrow keys in every direction. The camera should now hold a constant viewing angle and only slide to follow the player — no orbiting or "spinning world" when holding Left/Right, which was the bug they reported after step 1. Holding Left/Right now strafes the character visibly sideways on screen rather than circling.

- [ ] **Step 5: Commit**

```bash
git add game/camera/coop_camera.gd game/world/Forest.tscn
git commit -m "Rework chase camera as a fixed-offset SpringArm3D rig"
```

---

### Task 2: Level loader — parse forest_01.txt into the world

**Files:**
- Modify: `game/theme/palette.gd` (add one constant)
- Create: `game/world/level_loader.gd`
- Modify: `game/world/forest.gd` (remove the now-dangling `Ground` material code)
- Modify: `game/world/Forest.tscn` (remove `Ground`, add `Level`)

**Interfaces:**
- Consumes: `Palette.PASTEL_GREEN` (existing) and `Palette.WATER_BLUE` (added by this task's Step 1) from `game/theme/palette.gd`; the `Player1` node produced by Task 1's (and step 1's) `Forest.tscn`, addressed via a relative `NodePath`, not the `"players"` group (group membership timing between sibling `_ready()` calls is not guaranteed — see spec).
- Produces: nothing new consumed by other tasks in this plan — this is the last task.

This task depends on Task 1 only in that both edit `Forest.tscn`; it does not depend on Task 1's camera behavior. Dispatch this task with the actual current `Forest.tscn` (post Task 1) pasted into the brief, since Task 1's implementer's exact formatting may differ slightly from this plan's sample text.

- [ ] **Step 1: Add the water color to the palette**

In `game/theme/palette.gd`, add one line after the existing `CREAM` constant:

```gdscript
const WATER_BLUE := Color(0.42, 0.68, 0.82)
```

- [ ] **Step 2: Write the level loader script**

Create `game/world/level_loader.gd`:

```gdscript
extends Node3D

const Palette = preload("res://game/theme/palette.gd")

const TILE_SIZE := 2.0
const SKIP_CHARS := "mbruankxwdB!HS0123456789 "

@export var level_path: String = "res://levels/forest_01.txt"
@export var player_path: NodePath = NodePath("../Player1")

func _ready() -> void:
	var lines := _read_grid_lines(level_path)
	if lines.is_empty():
		push_warning("level_loader: no grid lines found in %s" % level_path)
		return

	var cols := 0
	for line in lines:
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
				"F":
					_spawn_campfire(world_pos)
				"P":
					player_spawn_found = true
					player_spawn_pos = world_pos
				_:
					if not SKIP_CHARS.contains(ch):
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
	for raw_line in content.split("\n"):
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

- [ ] **Step 3: Remove the dangling Ground code from forest.gd**

Current `game/world/forest.gd` (verify against the live file — this is exactly what step 1's fix round left it as):

```gdscript
extends Node3D

const Palette = preload("res://game/theme/palette.gd")

func _ready() -> void:
	var ground_mesh: MeshInstance3D = $Ground/MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PASTEL_GREEN
	ground_mesh.material_override = material

	var env: Environment = $WorldEnvironment.environment
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
	sky_mat.sky_top_color = Palette.SKY_BLUE.darkened(0.15)
	sky_mat.sky_horizon_color = Palette.CREAM.lerp(Palette.SKY_BLUE, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.CREAM.lerp(Palette.SKY_BLUE, 0.3)
```

Replace with (only the `Ground`-referencing lines removed — sky/ambient code is untouched):

```gdscript
extends Node3D

const Palette = preload("res://game/theme/palette.gd")

func _ready() -> void:
	var env: Environment = $WorldEnvironment.environment
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
	sky_mat.sky_top_color = Palette.SKY_BLUE.darkened(0.15)
	sky_mat.sky_horizon_color = Palette.CREAM.lerp(Palette.SKY_BLUE, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.CREAM.lerp(Palette.SKY_BLUE, 0.3)
```

- [ ] **Step 4: Remove Ground and add Level in Forest.tscn**

Read the actual current `game/world/Forest.tscn` first (it now has Task 1's `CoopCamera` rig — this step doesn't touch that node at all, only `Ground` and the resource header).

Remove the `Ground` node entirely — this whole block:
```
[node name="Ground" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="Ground"]
position = Vector3(0, -0.5, 0)
shape = SubResource("GroundShape_1")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Ground"]
position = Vector3(0, -0.5, 0)
mesh = SubResource("GroundMesh_1")
```

Remove the now-unused sub-resources it referenced:
```
[sub_resource type="BoxShape3D" id="GroundShape_1"]
size = Vector3(100, 1, 100)

[sub_resource type="BoxMesh" id="GroundMesh_1"]
size = Vector3(100, 1, 100)
```

Add a new `ext_resource` line (after the existing three) for the level loader script:
```
[ext_resource type="Script" path="res://game/world/level_loader.gd" id="4_level"]
```

Add the `Level` node in `Ground`'s old position in the file, immediately before the `CoopCamera` node:
```
[node name="Level" type="Node3D" parent="."]
script = ExtResource("4_level")
```

Update the `load_steps` count at the top of the file: this file had 3 `ext_resource` + 5 `sub_resource` = 8 resources (`load_steps=9`). After this step it has 4 `ext_resource` (`1_forest`, `2_camera`, `3_player`, `4_level`) + 3 `sub_resource` (`SkyMat_1`, `Sky_1`, `Env_1` — the two `Ground*` ones are removed) = 7 resources, so `load_steps=8`.

Everything else in the file (`WorldEnvironment`, `Sun`, `CoopCamera` and its children from Task 1, `Player1`) stays exactly as-is — only add/remove what's listed above.

- [ ] **Step 5: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error` lines, and no unexpected `push_warning` output — the only warnings that should appear (if any) are for genuinely unrecognized map characters, and `levels/forest_01.txt` shouldn't have any (every character in it is in the spec's implemented-or-silently-skipped list). If a warning DOES appear for a character you expected to be silently skipped, that's a bug in `SKIP_CHARS` or the `match` statement — fix it before proceeding, don't just note it.

- [ ] **Step 6: Ask the user to playtest**

Tell the user: reload `game/world/Forest.tscn`, press Play. They should see: the player spawning at the `P` position from `levels/forest_01.txt` (not the map's center), trees (brown trunk + green cone) and gray rock blocks scattered around matching the map, a blue water patch in the middle, a small orange campfire cylinder, and the ground now sized to the map instead of a fixed 100×100. Walking into a tree or rock should stop the player; walking onto water should not. Walking behind a tree/rock relative to the camera should pull the camera closer (SpringArm3D collision) instead of clipping through.

- [ ] **Step 7: Commit**

```bash
git add game/theme/palette.gd game/world/level_loader.gd game/world/forest.gd game/world/Forest.tscn
git commit -m "Add level loader: build forest from levels/forest_01.txt"
```
