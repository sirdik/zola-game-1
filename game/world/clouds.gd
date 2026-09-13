extends Node3D

const CLOUD_COUNT := 10
const HEIGHT_MIN := 28.0
const HEIGHT_MAX := 38.0
const AREA_MIN := -40.0
const AREA_MAX := 260.0
const DRIFT_SPEED_MIN := 0.4
const DRIFT_SPEED_MAX := 1.0
const CLOUD_COLOR := Color(0.98, 0.98, 1.0)

var _clouds: Array[Node3D] = []
var _speeds: Array[float] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var material := StandardMaterial3D.new()
	material.albedo_color = CLOUD_COLOR
	for i in CLOUD_COUNT:
		var cloud := _make_cloud(rng, material)
		cloud.position = Vector3(
			rng.randf_range(AREA_MIN, AREA_MAX),
			rng.randf_range(HEIGHT_MIN, HEIGHT_MAX),
			rng.randf_range(AREA_MIN, AREA_MAX)
		)
		add_child(cloud)
		_clouds.append(cloud)
		_speeds.append(rng.randf_range(DRIFT_SPEED_MIN, DRIFT_SPEED_MAX))

func _process(delta: float) -> void:
	for i in _clouds.size():
		var cloud := _clouds[i]
		cloud.position.x += _speeds[i] * delta
		if cloud.position.x > AREA_MAX:
			cloud.position.x = AREA_MIN

func _make_cloud(rng: RandomNumberGenerator, material: StandardMaterial3D) -> Node3D:
	var holder := Node3D.new()
	var puff_count := rng.randi_range(3, 5)
	for i in puff_count:
		var radius := rng.randf_range(1.5, 3.0)
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.material_override = material
		puff.position = Vector3(
			rng.randf_range(-2.5, 2.5),
			rng.randf_range(-0.5, 0.5),
			rng.randf_range(-1.5, 1.5)
		)
		holder.add_child(puff)
	return holder
