extends CanvasLayer

const IconGenerator := preload("res://game/theme/icon_generator.gd")

const ENERGY_BAR_WIDTH := 200.0

@onready var resource_bar: HBoxContainer = $ResourceBar
@onready var energy_bar_fill: ColorRect = $EnergyBarBg/EnergyBarFill
@onready var eat_menu: VBoxContainer = $EatMenu

var _resource_labels: Dictionary = {}
var _eat_menu_entries: Array[Dictionary] = []
var _eat_menu_rows: Array[Label] = []
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

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.texture = IconGenerator.generate(item_data.get("icon", "circle"), Color.html(item_data["color"]))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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

var _near_campfire: bool = false

func set_near_campfire(value: bool) -> void:
	_near_campfire = value
	if not value and eat_menu.visible:
		close_eat_menu()

func open_eat_menu() -> void:
	_eat_menu_entries = []
	_eat_menu_rows = []

	for child in eat_menu.get_children():
		eat_menu.remove_child(child)
		child.queue_free()

	var raw_ids: Array[String] = []
	for id in Items.all_ids():
		var item_data := Items.get_by_id(id)
		if Game.get_count(id) > 0 and item_data.get("edible", true):
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

func close_eat_menu() -> void:
	eat_menu.visible = false
	Game.ui_blocking = false

func _update_eat_menu_highlight() -> void:
	for i in _eat_menu_rows.size():
		var entry: Dictionary = _eat_menu_entries[i]
		var base_color: Color = Color(1, 1, 1) if entry["craftable"] else Color(0.5, 0.5, 0.5)
		_eat_menu_rows[i].modulate = Color(1, 1, 0.4) if i == _eat_menu_selected else base_color

func _any_jump_pressed() -> bool:
	return Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump")

func _any_action_pressed() -> bool:
	return Input.is_action_just_pressed("p1_action") or Input.is_action_just_pressed("p2_action")

func _any_menu_next_pressed() -> bool:
	return Input.is_action_just_pressed("p1_move_back") or Input.is_action_just_pressed("p2_move_back")

func _any_menu_prev_pressed() -> bool:
	return Input.is_action_just_pressed("p1_move_forward") or Input.is_action_just_pressed("p2_move_forward")

func _process(_delta: float) -> void:
	if eat_menu.visible:
		if _any_jump_pressed():
			close_eat_menu()
			return
		if _eat_menu_entries.is_empty():
			if _any_action_pressed():
				close_eat_menu()
			return
		if _any_menu_next_pressed():
			_eat_menu_selected = (_eat_menu_selected + 1) % _eat_menu_entries.size()
			_update_eat_menu_highlight()
		elif _any_menu_prev_pressed():
			_eat_menu_selected = (_eat_menu_selected - 1 + _eat_menu_entries.size()) % _eat_menu_entries.size()
			_update_eat_menu_highlight()
		elif _any_action_pressed():
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
	elif _near_campfire and _any_action_pressed():
		open_eat_menu()
