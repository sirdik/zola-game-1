extends CharacterBody3D

enum State { IDLE, WANDER, LOOK, CHASE, FLEE }

const HIT_COOLDOWN := 1.5
const IDLE_MIN_TIME := 1.0
const IDLE_MAX_TIME := 3.0
const TURN_SPEED := 10.0
const HEART_COLOR := Color(0.95, 0.4, 0.55)
const HOP_SCALE := Vector3(1.2, 0.8, 1.2)

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

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _state: State = State.IDLE
var _spawn_position: Vector3 = Vector3.ZERO
var _player: Node3D = null
var _idle_timer: float = 0.0
var _chase_timer: float = 0.0
var _flee_timer: float = 0.0
var _hit_cooldown: float = 0.0
var _horn_cooldown_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_spawn_position = global_position
	_player = get_tree().get_first_node_in_group("players")
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

func _distance_to_player() -> float:
	return global_position.distance_to(_player.global_position)

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
		if dist <= chase_radius:
			_enter_chase()
			return true
	elif dist <= notice_radius:
		_state = State.LOOK
		return true
	return false

func _process_look(delta: float) -> void:
	if _distance_to_player() > notice_radius:
		_enter_idle()
		return
	_face_position(_player.global_position, delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if _distance_to_player() <= pet_radius and Input.is_action_just_pressed("p1_action"):
		_play_pet_effect()

func _play_pet_effect() -> void:
	var hop := create_tween()
	hop.tween_property(self, "scale", HOP_SCALE, 0.1)
	hop.tween_property(self, "scale", Vector3.ONE, 0.15)

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

func _process_chase(delta: float) -> void:
	_chase_timer += delta
	var dist := _distance_to_player()
	if _chase_timer >= give_up_time or dist > chase_radius * 1.5:
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
	if _distance_to_player() <= horn_radius and Game.get_count("horn") > 0 and Input.is_action_just_pressed("p1_action"):
		scare(_player.global_position)
