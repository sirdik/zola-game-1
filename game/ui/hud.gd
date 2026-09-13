extends CanvasLayer

const IconGenerator := preload("res://game/theme/icon_generator.gd")
const SoundGenerator := preload("res://game/audio/sound_generator.gd")

const ENERGY_BAR_WIDTH := 200.0
const RESET_CONFIRM_WINDOW := 3.0
const RESET_LABEL := "Nová hra"
const RESET_CONFIRM_LABEL := "Fakt smazat?"
const MUSIC_MUTE_LABEL := "Ztlumit hudbu"
const MUSIC_UNMUTE_LABEL := "Zapnout hudbu"

@onready var resource_bar: HBoxContainer = $ResourceBar
@onready var energy_bar_fill: ColorRect = $EnergyBarBg/EnergyBarFill
@onready var eat_menu: VBoxContainer = $EatMenu
@onready var reset_button: Button = $ResetButton
@onready var music_button: Button = $MusicButton

var _resource_labels: Dictionary = {}
var _eat_menu_entries: Array[Dictionary] = []
var _eat_menu_rows: Array[Control] = []
var _eat_menu_selected: int = 0
var _reset_pending: bool = false
var _reset_timer: float = 0.0

func _ready() -> void:
	add_to_group("hud")
	_build_resource_bar()
	Game.inventory_changed.connect(_on_inventory_changed)
	Game.energy_changed.connect(_on_energy_changed)
	_on_energy_changed(Game.energy)
	reset_button.pressed.connect(_on_reset_button_pressed)
	music_button.pressed.connect(_on_music_button_pressed)

func _build_resource_bar() -> void:
	for id in Items.all_ids():
		var item_data := Items.get_by_id(id)
		var row := HBoxContainer.new()
		resource_bar.add_child(row)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.texture = IconGenerator.resolve(item_data)
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

var _near_campfire_players: Array = []

func set_near_campfire(player_numbers: Array) -> void:
	_near_campfire_players = player_numbers
	if _near_campfire_players.is_empty() and eat_menu.visible:
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
			var icon := IconGenerator.resolve(item_data)
			var row := _add_eat_menu_row("%s x%d" % [item_data["name"], Game.get_count(id)], icon)
			_eat_menu_entries.append({"kind": "raw", "id": id, "craftable": true})
			_eat_menu_rows.append(row)

	var recipe_ids := Recipes.all_ids()
	if not recipe_ids.is_empty():
		_add_eat_menu_header("Recepty")
		for id in recipe_ids:
			var recipe_data := Recipes.get_by_id(id)
			var craftable := _can_cook(recipe_data["ingredients"])
			var icon := IconGenerator.resolve(recipe_data)
			var row := _add_eat_menu_row(recipe_data["name"], icon)
			_eat_menu_entries.append({"kind": "recipe", "id": id, "craftable": craftable})
			_eat_menu_rows.append(row)

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

func _add_eat_menu_row(text: String, icon: Texture2D) -> Control:
	var row := HBoxContainer.new()
	eat_menu.add_child(row)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(20, 20)
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_rect)

	var label := Label.new()
	label.text = text
	row.add_child(label)

	return row

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

func _any_nearby_action_pressed() -> bool:
	for player_number in _near_campfire_players:
		if Input.is_action_just_pressed("p%d_action" % player_number):
			return true
	return false

func _any_menu_next_pressed() -> bool:
	return Input.is_action_just_pressed("p1_move_back") or Input.is_action_just_pressed("p2_move_back")

func _any_menu_prev_pressed() -> bool:
	return Input.is_action_just_pressed("p1_move_forward") or Input.is_action_just_pressed("p2_move_forward")

func _on_reset_button_pressed() -> void:
	if _reset_pending:
		Game.reset_save()
		get_tree().reload_current_scene()
		return
	_reset_pending = true
	_reset_timer = RESET_CONFIRM_WINDOW
	reset_button.text = RESET_CONFIRM_LABEL
	reset_button.modulate = Color(1.0, 0.4, 0.4)

func _on_music_button_pressed() -> void:
	var music_player := get_tree().get_first_node_in_group("music_player") as AudioStreamPlayer
	if music_player == null:
		return
	music_player.stream_paused = not music_player.stream_paused
	music_button.text = MUSIC_UNMUTE_LABEL if music_player.stream_paused else MUSIC_MUTE_LABEL

func _process(delta: float) -> void:
	if _reset_pending:
		_reset_timer -= delta
		if _reset_timer <= 0.0:
			_reset_pending = false
			reset_button.text = RESET_LABEL
			reset_button.modulate = Color.WHITE

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
					SoundGenerator.play(self, "eat")
				close_eat_menu()
			elif entry["craftable"]:
				var recipe_data := Recipes.get_by_id(entry["id"])
				if Game.try_cook(recipe_data["ingredients"], recipe_data["energy_cooked"]):
					SoundGenerator.play(self, "eat")
				close_eat_menu()
	elif _any_nearby_action_pressed():
		open_eat_menu()
