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
	if not (parsed is Dictionary) or not parsed.has("items") or not (parsed["items"] is Array):
		push_warning("items: malformed %s" % DATA_PATH)
		return
	for entry in parsed["items"]:
		if not (entry is Dictionary) or not entry.has("id") or not (entry["id"] is String):
			push_warning("items: skipping an entry with a missing or invalid id in %s" % DATA_PATH)
			continue
		var id: String = entry["id"]
		if not entry.has("color") or not (entry["color"] is String) or not Color.html_is_valid(entry["color"]):
			push_warning("items: entry '%s' has a missing or invalid color, defaulting to white" % id)
			entry["color"] = "#ffffff"
		if not entry.has("energy_raw"):
			push_warning("items: entry '%s' is missing energy_raw, defaulting to 0" % id)
			entry["energy_raw"] = 0
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
