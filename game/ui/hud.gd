extends CanvasLayer

const ENERGY_BAR_WIDTH := 200.0

@onready var resource_bar: HBoxContainer = $ResourceBar
@onready var energy_bar_fill: ColorRect = $EnergyBarBg/EnergyBarFill
@onready var eat_menu: VBoxContainer = $EatMenu

var _resource_labels: Dictionary = {}
var _eat_menu_ids: Array[String] = []
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

		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.color = Color.html(item_data["color"])
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

func close_eat_menu() -> void:
	eat_menu.visible = false
	Game.ui_blocking = false

func _update_eat_menu_highlight() -> void:
	for i in eat_menu.get_child_count():
		var label: Label = eat_menu.get_child(i)
		label.modulate = Color(1, 1, 0.4) if i == _eat_menu_selected else Color(1, 1, 1)

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
