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
		var bad_ingredients := false
		for item_id in entry["ingredients"]:
			var amount = entry["ingredients"][item_id]
			if not (item_id is String) or not (amount is float or amount is int):
				push_warning("recipes: skipping entry '%s' — ingredient '%s' must be a number" % [id, item_id])
				bad_ingredients = true
				break
		if bad_ingredients:
			continue
		if not entry.has("name") or not (entry["name"] is String):
			push_warning("recipes: entry '%s' has a missing or invalid name, using the id" % id)
			entry["name"] = id
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
