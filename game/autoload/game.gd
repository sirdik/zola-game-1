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

func try_cook(ingredients: Dictionary, energy_cooked: float) -> bool:
	for item_id in ingredients:
		if get_count(item_id) < int(ingredients[item_id]):
			return false
	for item_id in ingredients:
		_inventory[item_id] = get_count(item_id) - int(ingredients[item_id])
		inventory_changed.emit(item_id)
	restore(energy_cooked)
	return true
