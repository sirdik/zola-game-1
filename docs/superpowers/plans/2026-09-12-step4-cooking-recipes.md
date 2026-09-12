# Krok 4: Vaření a recepty Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build roadmap step 4 from CLAUDE.md — recipes data, a `Recipes` autoload, atomic multi-ingredient cooking on `Game`, and a two-section (Syrové / Recepty) campfire menu where unaffordable recipes are visible but inert.

**Architecture:** `Recipes` is a pure-data autoload mirroring the existing `Items` autoload (no dependency between them). `Game` gains one new atomic method, `try_cook()`. `game/ui/hud.gd`'s eat-menu is restructured from a flat `Array[String]` of item ids into an `Array[Dictionary]` of `{kind, id, craftable}` entries with a parallel `Array[Label]` of only the selectable rows (section headers aren't part of either array, so keyboard navigation skips them automatically).

**Tech Stack:** Godot 4.7.2 (GDScript, static typing), Jolt Physics.

**Spec:** `docs/superpowers/specs/2026-09-12-step4-cooking-recipes.md`

## Global Constraints

- GDScript with static typing throughout.
- `Items`, `Game`, `Recipes` are real Godot autoloads (globally accessible by name, no import). `Recipes` has no dependency on `Items` or `Game` and can be listed anywhere in `project.godot`'s `[autoload]` section relative to them — it only parses its own JSON file.
- `Recipes` mirrors `Items`' defensive-parsing style exactly: never a hard crash on malformed `data/recipes.json`. A recipe entry with a missing/invalid `id` OR missing/non-`Dictionary` `ingredients` is skipped entirely (with `push_warning`) since a recipe without valid ingredients can't be checked for craftability. Missing `color` defaults to `"#ffffff"`; missing `energy_cooked` defaults to `0` — both with `push_warning`, both still included (unlike the id/ingredients case).
- `Game.try_cook(ingredients: Dictionary, energy_cooked: float) -> bool` must be atomic: check every ingredient's count is sufficient BEFORE consuming any of them, so a recipe can never be half-consumed.
- The eat-menu's "Recepty" section lists every recipe from `Recipes.all_ids()`, even ones the player can't currently afford — those show in gray (`Color(0.5, 0.5, 0.5)`) and confirming on them does nothing (menu stays open, no error message — this is a deliberate simplicity choice for young children, not an oversight).
- `godot --headless --path . --quit` (binary: `./godot-editor/Godot_v4.7.2-stable_win64_console.exe`, run from repo root) must exit with no `SCRIPT ERROR` / `Parse Error`. `Recipes` is a third real autoload whose `_ready()` genuinely executes at boot — check for unexpected `push_warning` output too, not just errors. There is no automated test framework for this project — that command plus a manual playtest by the user (who has the Godot editor open on this same project directory) are the only verification available. This step does not touch any `.tscn` file (confirmed: `HUD.tscn`'s `EatMenu` container has no static children — everything in it is built at runtime), so no scene-reload reminder is needed this time.

---

### Task 1: Recipe data, Recipes autoload, Game.try_cook()

**Files:**
- Create: `data/recipes.json`
- Create: `game/autoload/recipes.gd`
- Modify: `project.godot` (add `Recipes` to `[autoload]`)
- Modify: `game/autoload/game.gd` (add `try_cook`)

**Interfaces:**
- Produces: autoload `Recipes` with `get_by_id(recipe_id: String) -> Dictionary`, `all_ids() -> Array[String]` (file order) — same shape as `Items`.
- Produces: `Game.try_cook(ingredients: Dictionary, energy_cooked: float) -> bool`.

This task has no visible in-game effect yet (nothing calls `Recipes` or `try_cook` until Task 2) — headless boot is the only verification available for it.

- [ ] **Step 1: Write the recipe data**

Create `data/recipes.json`:

```json
{
  "recipes": [
    {
      "id": "mushroom_soup",
      "name": "Houbová polévka",
      "ingredients": { "mushroom": 3, "water": 1 },
      "energy_cooked": 40,
      "color": "#E8C874"
    },
    {
      "id": "forest_jam",
      "name": "Lesní marmeláda",
      "ingredients": { "raspberry": 3, "blackberry": 3 },
      "energy_cooked": 25,
      "color": "#8B2F5E"
    },
    {
      "id": "blueberry_pie",
      "name": "Borůvkový koláč",
      "ingredients": { "blueberry": 5, "hazelnut": 2 },
      "energy_cooked": 40,
      "color": "#5B4A8A"
    },
    {
      "id": "apple_juice",
      "name": "Jablečný džus",
      "ingredients": { "apple": 2, "water": 1 },
      "energy_cooked": 15,
      "color": "#F2A93B"
    }
  ]
}
```

- [ ] **Step 2: Write the Recipes autoload**

Create `game/autoload/recipes.gd`:

```gdscript
extends Node

const DATA_PATH := "res://data/recipes.json"

var _by_id: Dictionary = {}
var _order: Array[String] = []

func _ready() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("recipes: could not open %s" % DATA_PATH)
		return
	var content := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary) or not parsed.has("recipes") or not (parsed["recipes"] is Array):
		push_warning("recipes: malformed %s" % DATA_PATH)
		return
	for entry in parsed["recipes"]:
		if not (entry is Dictionary) or not entry.has("id") or not (entry["id"] is String):
			push_warning("recipes: skipping an entry with a missing or invalid id in %s" % DATA_PATH)
			continue
		var id: String = entry["id"]
		if not entry.has("ingredients") or not (entry["ingredients"] is Dictionary):
			push_warning("recipes: skipping entry '%s' with missing or invalid ingredients in %s" % [id, DATA_PATH])
			continue
		if not entry.has("color") or not (entry["color"] is String) or not Color.html_is_valid(entry["color"]):
			push_warning("recipes: entry '%s' has a missing or invalid color, defaulting to white" % id)
			entry["color"] = "#ffffff"
		if not entry.has("energy_cooked"):
			push_warning("recipes: entry '%s' is missing energy_cooked, defaulting to 0" % id)
			entry["energy_cooked"] = 0
		_by_id[id] = entry
		_order.append(id)

func get_by_id(recipe_id: String) -> Dictionary:
	return _by_id.get(recipe_id, {})

func all_ids() -> Array[String]:
	return _order
```

- [ ] **Step 3: Register the Recipes autoload**

Current `project.godot` `[autoload]` section:

```
[autoload]

Items="*res://game/autoload/items.gd"
Game="*res://game/autoload/game.gd"
```

Add `Recipes` as a third line:

```
[autoload]

Items="*res://game/autoload/items.gd"
Game="*res://game/autoload/game.gd"
Recipes="*res://game/autoload/recipes.gd"
```

- [ ] **Step 4: Add Game.try_cook()**

Current `game/autoload/game.gd` ends with:

```gdscript
func drain(amount: float) -> void:
	energy = clamp(energy - amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy)

func restore(amount: float) -> void:
	energy = clamp(energy + amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy)
```

Add a new function after `restore`:

```gdscript
func drain(amount: float) -> void:
	energy = clamp(energy - amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy)

func restore(amount: float) -> void:
	energy = clamp(energy + amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy)

func try_cook(ingredients: Dictionary, energy_cooked: float) -> bool:
	for item_id in ingredients:
		if get_count(item_id) < int(ingredients[item_id]):
			return false
	for item_id in ingredients:
		_inventory[item_id] = get_count(item_id) - int(ingredients[item_id])
		inventory_changed.emit(item_id)
	restore(energy_cooked)
	return true
```

Do not touch `inventory_changed`, `energy_changed`, `MAX_ENERGY`, `energy`, `ui_blocking`, `_inventory`, `_ready`, `get_count`, `add_item`, or `try_consume`.

- [ ] **Step 5: Verify headless boot**

Run from the repo root:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error` / unexpected `push_warning`. `data/recipes.json` is well-formed, so `Recipes`' new validation code should produce zero warnings against it.

- [ ] **Step 6: Commit**

```bash
git add data/recipes.json game/autoload/recipes.gd project.godot game/autoload/game.gd
git commit -m "Add recipe data, Recipes autoload, and Game.try_cook()"
```

---

### Task 2: Two-section campfire menu (Syrové / Recepty)

**Files:**
- Modify: `game/ui/hud.gd`

**Interfaces:**
- Consumes: `Recipes.all_ids() -> Array[String]`, `Recipes.get_by_id(recipe_id: String) -> Dictionary` (Task 1); `Game.try_cook(ingredients: Dictionary, energy_cooked: float) -> bool` (Task 1); `Game.get_count`, `Game.try_consume`, `Game.restore`, `Items.all_ids`, `Items.get_by_id` (all pre-existing, unchanged).
- Produces: nothing new consumed by other tasks — this is the last task in the plan.

This task only touches `game/ui/hud.gd`. Read the actual current file before editing — it should match the "current" code blocks quoted below exactly (this project's `hud.gd` was last touched by step 3's final-review fix round, already committed and reviewed clean).

- [ ] **Step 1: Replace the eat-menu state variables**

Current:

```gdscript
var _resource_labels: Dictionary = {}
var _eat_menu_ids: Array[String] = []
var _eat_menu_selected: int = 0
```

Replace with:

```gdscript
var _resource_labels: Dictionary = {}
var _eat_menu_entries: Array[Dictionary] = []
var _eat_menu_rows: Array[Label] = []
var _eat_menu_selected: int = 0
```

- [ ] **Step 2: Rewrite open_eat_menu() for two sections**

Current:

```gdscript
func open_eat_menu() -> void:
	_eat_menu_ids = []
	for id in Items.all_ids():
		if Game.get_count(id) > 0:
			_eat_menu_ids.append(id)

	for child in eat_menu.get_children():
		eat_menu.remove_child(child)
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
	Game.ui_blocking = true
```

Replace with:

```gdscript
func open_eat_menu() -> void:
	_eat_menu_entries = []
	_eat_menu_rows = []

	for child in eat_menu.get_children():
		eat_menu.remove_child(child)
		child.queue_free()

	var raw_ids: Array[String] = []
	for id in Items.all_ids():
		if Game.get_count(id) > 0:
			raw_ids.append(id)

	if not raw_ids.is_empty():
		_add_eat_menu_header("Syrové")
		for id in raw_ids:
			var item_data := Items.get_by_id(id)
			var label := _add_eat_menu_row("%s x%d" % [item_data["name"], Game.get_count(id)])
			_eat_menu_entries.append({"kind": "raw", "id": id, "craftable": true})
			_eat_menu_rows.append(label)

	var recipe_ids := Recipes.all_ids()
	if not recipe_ids.is_empty():
		_add_eat_menu_header("Recepty")
		for id in recipe_ids:
			var recipe_data := Recipes.get_by_id(id)
			var craftable := _can_cook(recipe_data["ingredients"])
			var label := _add_eat_menu_row(recipe_data["name"])
			_eat_menu_entries.append({"kind": "recipe", "id": id, "craftable": craftable})
			_eat_menu_rows.append(label)

	if _eat_menu_entries.is_empty():
		var label := Label.new()
		label.text = "Nemáš žádné jídlo!"
		eat_menu.add_child(label)
	else:
		_eat_menu_selected = 0
		_update_eat_menu_highlight()

	eat_menu.visible = true
	Game.ui_blocking = true

func _add_eat_menu_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	eat_menu.add_child(label)

func _add_eat_menu_row(text: String) -> Label:
	var label := Label.new()
	label.text = text
	eat_menu.add_child(label)
	return label

func _can_cook(ingredients: Dictionary) -> bool:
	for item_id in ingredients:
		if Game.get_count(item_id) < ingredients[item_id]:
			return false
	return true
```

- [ ] **Step 3: Rewrite _update_eat_menu_highlight() to use the parallel rows array**

Current:

```gdscript
func _update_eat_menu_highlight() -> void:
	for i in eat_menu.get_child_count():
		var label: Label = eat_menu.get_child(i)
		label.modulate = Color(1, 1, 0.4) if i == _eat_menu_selected else Color(1, 1, 1)
```

Replace with:

```gdscript
func _update_eat_menu_highlight() -> void:
	for i in _eat_menu_rows.size():
		var entry: Dictionary = _eat_menu_entries[i]
		var base_color: Color = Color(1, 1, 1) if entry["craftable"] else Color(0.5, 0.5, 0.5)
		_eat_menu_rows[i].modulate = Color(1, 1, 0.4) if i == _eat_menu_selected else base_color
```

(This is why the parallel `_eat_menu_rows` array matters: `eat_menu.get_child_count()` would also count the section header labels, which aren't selectable and have no matching `_eat_menu_entries` entry — indexing by `_eat_menu_rows.size()` instead correctly skips them.)

- [ ] **Step 4: Rewrite _process() for the two entry kinds**

Current:

```gdscript
func _process(_delta: float) -> void:
	if eat_menu.visible:
		if _eat_menu_ids.is_empty():
			if Input.is_action_just_pressed("p1_action"):
				close_eat_menu()
			return
		if Input.is_action_just_pressed("p1_move_back"):
			_eat_menu_selected = (_eat_menu_selected + 1) % _eat_menu_ids.size()
			_update_eat_menu_highlight()
		elif Input.is_action_just_pressed("p1_move_forward"):
			_eat_menu_selected = (_eat_menu_selected - 1 + _eat_menu_ids.size()) % _eat_menu_ids.size()
			_update_eat_menu_highlight()
		elif Input.is_action_just_pressed("p1_action"):
			var id: String = _eat_menu_ids[_eat_menu_selected]
			if Game.try_consume(id):
				Game.restore(Items.get_by_id(id)["energy_raw"])
			close_eat_menu()
	elif _near_campfire and Input.is_action_just_pressed("p1_action"):
		open_eat_menu()
```

Replace with:

```gdscript
func _process(_delta: float) -> void:
	if eat_menu.visible:
		if _eat_menu_entries.is_empty():
			if Input.is_action_just_pressed("p1_action"):
				close_eat_menu()
			return
		if Input.is_action_just_pressed("p1_move_back"):
			_eat_menu_selected = (_eat_menu_selected + 1) % _eat_menu_entries.size()
			_update_eat_menu_highlight()
		elif Input.is_action_just_pressed("p1_move_forward"):
			_eat_menu_selected = (_eat_menu_selected - 1 + _eat_menu_entries.size()) % _eat_menu_entries.size()
			_update_eat_menu_highlight()
		elif Input.is_action_just_pressed("p1_action"):
			var entry: Dictionary = _eat_menu_entries[_eat_menu_selected]
			if entry["kind"] == "raw":
				var id: String = entry["id"]
				if Game.try_consume(id):
					Game.restore(Items.get_by_id(id)["energy_raw"])
				close_eat_menu()
			elif entry["craftable"]:
				var recipe_data := Recipes.get_by_id(entry["id"])
				Game.try_cook(recipe_data["ingredients"], recipe_data["energy_cooked"])
				close_eat_menu()
	elif _near_campfire and Input.is_action_just_pressed("p1_action"):
		open_eat_menu()
```

Note the last branch (`entry["kind"] == "recipe"` and NOT `craftable`): neither the `if` nor the `elif` fires, so nothing happens and the menu stays open exactly as the spec requires — no `else` needed.

Do not touch `_ready()`, `_build_resource_bar()`, `_on_inventory_changed()`, `_on_energy_changed()`, `_near_campfire`, `set_near_campfire()`, `close_eat_menu()`, `resource_bar`/`energy_bar_fill`/`eat_menu` (`@onready` vars), or `ENERGY_BAR_WIDTH`.

- [ ] **Step 5: Verify headless boot**

Run:
```
./godot-editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit
```
Expected: no `SCRIPT ERROR` / `Parse Error`.

- [ ] **Step 6: Ask the user to playtest**

Tell the user: reload the scene if needed (this task didn't touch any `.tscn` file, so a fresh Play should already pick up the script changes), press Play, collect enough of one recipe's ingredients (e.g. 3 mushroom + 1 water for Houbová polévka), walk to the campfire, press Enter. They should see two sections in the menu: "Syrové" (their raw items, as before) and "Recepty" below it (all 4 recipes, with unaffordable ones shown in gray). Selecting and confirming Houbová polévka should consume exactly 3 mushroom + 1 water, add 40 energy, and close the menu. Selecting a gray (unaffordable) recipe and pressing Enter should do nothing — menu stays open. Arrow-key navigation should move smoothly through both sections without landing on the section header text.

- [ ] **Step 7: Commit**

```bash
git add game/ui/hud.gd
git commit -m "Add cooking to the campfire menu: two sections, Syrové and Recepty"
```
