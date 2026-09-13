extends CharacterBody3D

enum State { IDLE, WANDER, LOOK, CHASE, FLEE }

const HIT_COOLDOWN := 1.5
const IDLE_MIN_TIME := 1.0
const IDLE_MAX_TIME := 3.0
const TURN_SPEED := 10.0
const HEART_COLOR := Color(0.95, 0.4, 0.55)
const HOP_SCALE := Vector3(1.2, 0.8, 1.2)
const CALM_TIME := 5.0
const PET_COOLDOWN := 0.4
const PET_ENERGY_RECIPE := "mushroom_soup"
const PET_ENERGY_FALLBACK := 40.0

const PlayerScript = preload("res://game/player/player.gd")
const SoundGenerator = preload("res://game/audio/sound_generator.gd")

var animal_id: String = ""
var aggressive: bool = false
var move_speed: float = 1.5
var wander_radius: float = 4.0
var notice_radius: float = 4.0
var pet_radius: float = 1.5
var chase_radius: float = 6.0
var chase_speed: float = 3.0
var catch_radius: float = 1.2
var give_up_time: float = 8.0
var energy_drain_on_hit: float = 15.0
var knockback_force: float = 6.0
var flee_speed: float = 4.0
var flee_duration: float = 4.0
var horn_radius: float = 6.0
var horn_cooldown: float = 3.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh_node: Node3D = $Mesh

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _state: State = State.IDLE
var _spawn_position: Vector3 = Vector3.ZERO
var _player: PlayerScript = null
var _idle_timer: float = 0.0
var _chase_timer: float = 0.0
var _flee_timer: float = 0.0
var _hit_cooldown: float = 0.0
var _horn_cooldown_timer: float = 0.0
var _calm_timer: float = 0.0
var _pet_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()
var _anim_player: AnimationPlayer = null

func _ready() -> void:
	_rng.randomize()
	_spawn_position = global_position
	_anim_player = _find_anim_player()
	_setup_animations()
	_enter_idle()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta
	if _horn_cooldown_timer > 0.0:
		_horn_cooldown_timer -= delta
	if _calm_timer > 0.0:
		_calm_timer -= delta
	if _pet_cooldown > 0.0:
		_pet_cooldown -= delta

	_update_nearest_player()

	if _player != null:
		match _state:
			State.IDLE:
				_process_idle(delta)
			State.WANDER:
				_process_wander(delta)
			State.LOOK:
				_process_look(delta)
			State.CHASE:
				_process_chase(delta)
			State.FLEE:
				_process_flee(delta)

		if aggressive and _state != State.FLEE:
			_check_horn_use()

	move_and_slide()

func _find_anim_player() -> AnimationPlayer:
	var found: Array = mesh_node.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return null
	return found[0]

func _setup_animations() -> void:
	if _anim_player == null:
		return
	for loop_name in ["Idle", "Walk"]:
		if _anim_player.has_animation(loop_name):
			_anim_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	if _anim_player.has_animation("Eating"):
		_anim_player.get_animation("Eating").loop_mode = Animation.LOOP_NONE
	_anim_player.animation_finished.connect(_on_animation_finished)

func _play_anim(anim_name: String) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	if _anim_player.current_animation != anim_name or not _anim_player.is_playing():
		_anim_player.play(anim_name)

func _play_state_animation() -> void:
	match _state:
		State.IDLE, State.LOOK:
			_play_anim("Idle")
		State.WANDER:
			_play_anim("Walk")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Eating":
		_play_state_animation()

func _distance_to_player() -> float:
	return global_position.distance_to(_player.global_position)

func _update_nearest_player() -> void:
	var nearest: PlayerScript = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group("players"):
		if node is PlayerScript:
			var dist: float = global_position.distance_to(node.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = node
	_player = nearest

func _player_action(action_name: String) -> String:
	return "p%d_%s" % [_player.player_number, action_name]

func _move_toward_nav_target(speed: float, delta: float) -> void:
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = next_pos - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_face_position(global_position + direction, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _face_position(target: Vector3, delta: float) -> void:
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	if to_target.length() > 0.01:
		var target_angle := atan2(-to_target.x, -to_target.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)

func _enter_idle() -> void:
	_state = State.IDLE
	_idle_timer = _rng.randf_range(IDLE_MIN_TIME, IDLE_MAX_TIME)
	velocity.x = 0.0
	velocity.z = 0.0
	_play_state_animation()

func _process_idle(delta: float) -> void:
	if _check_aggro_or_notice():
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_enter_wander()

func _enter_wander() -> void:
	_state = State.WANDER
	var offset := Vector3(
		_rng.randf_range(-wander_radius, wander_radius),
		0.0,
		_rng.randf_range(-wander_radius, wander_radius)
	)
	nav_agent.target_position = _spawn_position + offset
	_play_state_animation()

func _process_wander(delta: float) -> void:
	if _check_aggro_or_notice():
		return
	if nav_agent.is_navigation_finished():
		_enter_idle()
		return
	_move_toward_nav_target(move_speed, delta)

func _check_aggro_or_notice() -> bool:
	var dist := _distance_to_player()
	if aggressive:
		if _calm_timer <= 0.0 and dist <= chase_radius:
			_enter_chase()
			return true
	elif dist <= notice_radius:
		_state = State.LOOK
		_play_state_animation()
		return true
	return false

func _process_look(delta: float) -> void:
	if _distance_to_player() > notice_radius:
		_enter_idle()
		return
	_face_position(_player.global_position, delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if _distance_to_player() <= pet_radius and _pet_cooldown <= 0.0 and not Game.ui_blocking and Input.is_action_just_pressed(_player_action("action")):
		_play_pet_effect()
		_pet_cooldown = PET_COOLDOWN
		Game.restore(Recipes.get_by_id(PET_ENERGY_RECIPE).get("energy_cooked", PET_ENERGY_FALLBACK))

func _play_pet_effect() -> void:
	_play_anim("Eating")
	var base_scale := mesh_node.scale
	var hop := create_tween()
	hop.tween_property(mesh_node, "scale", base_scale * HOP_SCALE, 0.1)
	hop.tween_property(mesh_node, "scale", base_scale, 0.15)

	var heart := MeshInstance3D.new()
	var heart_mesh := SphereMesh.new()
	heart_mesh.radius = 0.2
	heart_mesh.height = 0.4
	heart.mesh = heart_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = HEART_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	heart.material_override = material
	heart.position = Vector3(0, 1.6, 0)
	add_child(heart)

	var float_up := create_tween()
	float_up.tween_property(heart, "position:y", 2.2, 0.8)
	float_up.parallel().tween_property(material, "albedo_color:a", 0.0, 0.8)
	float_up.tween_callback(heart.queue_free)

func _enter_chase() -> void:
	_state = State.CHASE
	_chase_timer = 0.0
	SoundGenerator.play(self, "growl")

func _process_chase(delta: float) -> void:
	_chase_timer += delta
	var dist := _distance_to_player()
	if _chase_timer >= give_up_time or dist > chase_radius * 1.5:
		_calm_timer = CALM_TIME
		_enter_idle()
		return
	nav_agent.target_position = _player.global_position
	_move_toward_nav_target(chase_speed, delta)
	if dist <= catch_radius and _hit_cooldown <= 0.0:
		_hit_player()

func _hit_player() -> void:
	Game.drain(energy_drain_on_hit)
	var away: Vector3 = _player.global_position - global_position
	_player.apply_knockback(away, knockback_force)
	_hit_cooldown = HIT_COOLDOWN

func scare(from_position: Vector3) -> bool:
	if not aggressive or _horn_cooldown_timer > 0.0:
		return false
	_horn_cooldown_timer = horn_cooldown
	_state = State.FLEE
	var away: Vector3 = global_position - from_position
	if away.length() < 0.01:
		away = Vector3(1.0, 0.0, 0.0)
	nav_agent.target_position = global_position + away.normalized() * (chase_radius * 2.0)
	_flee_timer = flee_duration
	return true

func _process_flee(delta: float) -> void:
	_flee_timer -= delta
	if _flee_timer <= 0.0:
		_enter_idle()
		return
	_move_toward_nav_target(flee_speed, delta)

func _check_horn_use() -> void:
	if _distance_to_player() <= horn_radius and Game.get_count("horn") > 0 and not Game.ui_blocking and Input.is_action_just_pressed(_player_action("action")):
		if scare(_player.global_position):
			SoundGenerator.play(self, "honk")
