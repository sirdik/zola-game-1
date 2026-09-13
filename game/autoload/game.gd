extends Node

signal inventory_changed(item_id: String)
signal energy_changed(value: float)

const MAX_ENERGY := 100.0
const SAVE_PATH := "user://savegame.json"
const SAVE_INTERVAL := 2.0

var energy: float = MAX_ENERGY
var ui_blocking: bool = false
var _inventory: Dictionary = {}
var _unlocked_buildings: Dictionary = {}
var _building_progress: Dictionary = {}
var _dirty: bool = false
var _save_timer: float = 0.0

func _ready() -> void:
	for id in Items.all_ids():
		_inventory[id] = 0
	_load()

func _process(delta: float) -> void:
	if _dirty:
		_save_timer += delta
		if _save_timer >= SAVE_INTERVAL:
			_save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _dirty:
			_save()

func get_count(item_id: String) -> int:
	return _inventory.get(item_id, 0)

func add_item(item_id: String, amount: int = 1) -> void:
	_inventory[item_id] = get_count(item_id) + amount
	inventory_changed.emit(item_id)
	var item_data := Items.get_by_id(item_id)
	if item_data.has("unlocks_building"):
		unlock_building(item_data["unlocks_building"])
	_mark_dirty()

func try_consume(item_id: String, amount: int = 1) -> bool:
	if get_count(item_id) < amount:
		return false
	_inventory[item_id] = get_count(item_id) - amount
	inventory_changed.emit(item_id)
	_mark_dirty()
	return true

func drain(amount: float) -> void:
	energy = clamp(energy - amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy)
	_mark_dirty()

func restore(amount: float) -> void:
	energy = clamp(energy + amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy)
	_mark_dirty()

func try_cook(ingredients: Dictionary, energy_cooked: float) -> bool:
	for item_id in ingredients:
		if get_count(item_id) < int(ingredients[item_id]):
			return false
	for item_id in ingredients:
		_inventory[item_id] = get_count(item_id) - int(ingredients[item_id])
		inventory_changed.emit(item_id)
	restore(energy_cooked)
	return true

func unlock_building(building_id: String) -> void:
	_unlocked_buildings[building_id] = true
	_mark_dirty()

func is_building_unlocked(building_id: String) -> bool:
	return _unlocked_buildings.get(building_id, false)

func get_building_progress(building_id: String) -> int:
	return _building_progress.get(building_id, 0)

func set_building_progress(building_id: String, next_index: int) -> void:
	_building_progress[building_id] = next_index
	_mark_dirty()

func _mark_dirty() -> void:
	_dirty = true

func _save() -> void:
	var data := {
		"energy": energy,
		"inventory": _inventory,
		"unlocked_buildings": _unlocked_buildings,
		"building_progress": _building_progress,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("game: could not write save file at %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data))
	file.close()
	_dirty = false
	_save_timer = 0.0

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("game: could not open save file at %s" % SAVE_PATH)
		return
	var content := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary):
		push_warning("game: malformed save file, starting fresh")
		return

	if parsed.get("energy") is float or parsed.get("energy") is int:
		energy = clamp(float(parsed["energy"]), 0.0, MAX_ENERGY)

	var saved_inventory: Variant = parsed.get("inventory")
	if saved_inventory is Dictionary:
		for item_id in saved_inventory:
			if _inventory.has(item_id) and (saved_inventory[item_id] is int or saved_inventory[item_id] is float):
				_inventory[item_id] = int(saved_inventory[item_id])

	var saved_unlocked: Variant = parsed.get("unlocked_buildings")
	if saved_unlocked is Dictionary:
		for building_id in saved_unlocked:
			if building_id is String and saved_unlocked[building_id] is bool:
				_unlocked_buildings[building_id] = saved_unlocked[building_id]

	var saved_progress: Variant = parsed.get("building_progress")
	if saved_progress is Dictionary:
		for building_id in saved_progress:
			if building_id is String and (saved_progress[building_id] is int or saved_progress[building_id] is float):
				_building_progress[building_id] = int(saved_progress[building_id])
