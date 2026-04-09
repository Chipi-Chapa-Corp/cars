extends VehicleBody3D

const STEERING_ANGLE := 0.45
const THROTTLE_FORCE := 100.0
const IDLE_TURN_SPEED := 1.8
const IDLE_TURN_SPEED_THRESHOLD := 0.8
const IDLE_TURN_DAMPING := 8.0
const IDLE_TURN_DELAY := 0.1
const WHEEL_STEER_INTERPOLATION_SPEED := 8.0
const CAR_TYPES := ["speedster", "retro"]
const WHEEL_GROUPS := [
	"wheel-left-front",
	"wheel-right-front",
	"wheel-left-rear",
	"wheel-right-rear",
]

@onready var camera: Camera3D = $Camera

@export var name_plate: Label3D
@export var healthbar: TextureProgressBar
@export var powerup_slot: Node3D
@export var powerup_scene_by_type: Dictionary[String, PackedScene] = {}

var _hitpoints: int = 100
@export var hitpoints: int = 100:
	set(value):
		_hitpoints = maxi(0, value)
		_sync_healthbar()
	get:
		return _hitpoints

var _car_type: String = "speedster"
@export_enum("speedster", "retro") var car_type: String = "speedster":
	get:
		return _car_type
	set(value):
		_set_car_type(value)

@export var synced_wheel_steering: float = 0.0
@export var synced_wheel_spin: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var player_id: int = -1
var player_name: String = ""
var _is_local := false
var _wheel_nodes: Dictionary = {}
var _wheel_base_rotation: Dictionary = {}
var _wheel_spin: Dictionary = {}
var _visual_steering := 0.0
var _powerup_scene_instance: Node
var _idle_turn_elapsed := 0.0
var _idle_turn_direction := 0.0

@onready var _physics_wheels: Dictionary = {
	"wheel-left-front": $FrontLeft as VehicleWheel3D,
	"wheel-right-front": $FrontRight as VehicleWheel3D,
	"wheel-left-rear": $RearLeft as VehicleWheel3D,
	"wheel-right-rear": $RearRight as VehicleWheel3D,
}

var _powerup: String = ""
@export var powerup: String = "":
	set(value):
		_powerup = value
		_sync_label()
		_sync_powerup_scene()
	get:
		return _powerup

func prepare(data: Dictionary) -> void:
	player_id = int(data["peer_id"])
	player_name = str(player_id)
	set_multiplayer_authority(player_id)


func _ready() -> void:
	_is_local = multiplayer.get_unique_id() == player_id
	if is_multiplayer_authority():
		car_type = CAR_TYPES.pick_random()
	else:
		_set_car_type(car_type)
	camera.current = _is_local
	_sync_label()
	_sync_powerup_scene()
	_sync_healthbar()
	set_physics_process(_is_local)
	set_process(not _is_local)
	if not _is_local:
		_apply_synced_wheel_visuals()

func _physics_process(delta: float) -> void:
	var turn_input := Input.get_axis("turn_right", "turn_left")
	var throttle_input := Input.get_axis("backward", "forward")

	steering = turn_input * STEERING_ANGLE
	engine_force = throttle_input * THROTTLE_FORCE
	_visual_steering = move_toward(_visual_steering, steering, WHEEL_STEER_INTERPOLATION_SPEED * delta)
	_update_wheel_visuals(delta)

	if absf(throttle_input) <= 0.01 and linear_velocity.length() <= IDLE_TURN_SPEED_THRESHOLD:
		var next_angular_velocity := angular_velocity
		if absf(turn_input) > 0.01:
			var turn_direction: float = signf(turn_input)
			if turn_direction != _idle_turn_direction:
				_idle_turn_direction = turn_direction
				_idle_turn_elapsed = 0.0
			else:
				_idle_turn_elapsed += delta

			if _idle_turn_elapsed >= IDLE_TURN_DELAY:
				next_angular_velocity.y = turn_input * IDLE_TURN_SPEED
			else:
				next_angular_velocity.y = move_toward(next_angular_velocity.y, 0.0, IDLE_TURN_DAMPING * delta)
		else:
			_idle_turn_elapsed = 0.0
			_idle_turn_direction = 0.0
			next_angular_velocity.y = move_toward(next_angular_velocity.y, 0.0, IDLE_TURN_DAMPING * delta)
		angular_velocity = next_angular_velocity
	else:
		_idle_turn_elapsed = 0.0
		_idle_turn_direction = 0.0

	if Input.is_action_just_pressed("activate"):
		_activate_powerup()

func _process(_delta: float) -> void:
	if not _is_local:
		_apply_synced_wheel_visuals()


func _on_interaction_available(body: Node3D) -> void:
	if _is_local and _powerup == "" and body.is_in_group("pickupable"):
		body.interact({})

func _activate_powerup() -> void:
	if _powerup_scene_instance == null:
		return
	var cleanup = _powerup_scene_instance.will_dispose
	_powerup_scene_instance.interact({})
	if cleanup:
		_powerup_scene_instance = null
		powerup = ""

func _sync_label() -> void:
	if name_plate == null:
		return
	if _is_local:
		name_plate.text = ""
		return
	name_plate.text = "%s (%s)" % [player_name, powerup] if powerup else player_name

func _sync_powerup_scene() -> void:
	_clear_powerup_scene()
	if _powerup == "":
		return
	var scene := powerup_scene_by_type.get(_powerup, null) as PackedScene
	_powerup_scene_instance = scene.instantiate()
	powerup_slot.add_child(_powerup_scene_instance)

func _clear_powerup_scene() -> void:
	if _powerup_scene_instance == null:
		return
	_powerup_scene_instance.queue_free()
	_powerup_scene_instance = null

func _sync_healthbar() -> void:
	if healthbar == null:
		return
	healthbar.value = clampf(float(hitpoints), healthbar.min_value, healthbar.max_value)

func _set_car_type(value: String) -> void:
	_car_type = value
	var car_group := "%s-car" % value
	_wheel_nodes.clear()
	_wheel_base_rotation.clear()
	_wheel_spin.clear()
	_visual_steering = steering

	for node: Node in find_children("*", "", true, false):
		var is_car_part := false
		for type_name: String in CAR_TYPES:
			if node.is_in_group("%s-car" % type_name):
				is_car_part = true
				break

		if not is_car_part:
			continue

		var is_selected := node.is_in_group(car_group)
		if node is Node3D:
			node.visible = is_selected
			if is_selected:
				var wheel := node as Node3D
				for wheel_group: String in WHEEL_GROUPS:
					if wheel.is_in_group(wheel_group):
						_wheel_nodes[wheel_group] = wheel
						_wheel_base_rotation[wheel_group] = wheel.rotation
						_wheel_spin[wheel_group] = 0.0
						break
		if node is CollisionShape3D:
			node.disabled = not is_selected
	if not _is_local:
		_apply_synced_wheel_visuals()

func _update_wheel_visuals(delta: float) -> void:
	for wheel_group: String in WHEEL_GROUPS:
		var wheel: Node3D = _wheel_nodes.get(wheel_group, null)
		if wheel == null:
			continue

		var physics_wheel: VehicleWheel3D = _physics_wheels.get(wheel_group, null)
		var spin: float = _wheel_spin.get(wheel_group, 0.0)
		if physics_wheel != null:
			spin = wrapf(spin + (physics_wheel.get_rpm() * TAU / 60.0 * delta), -PI, PI)
			_wheel_spin[wheel_group] = spin

		var base_rotation: Vector3 = _wheel_base_rotation.get(wheel_group, wheel.rotation)
		var steer_offset := 0.0
		if wheel_group.ends_with("-front"):
			steer_offset = _visual_steering

		wheel.rotation = Vector3(base_rotation.x + spin, base_rotation.y + steer_offset, base_rotation.z)
	_sync_wheel_visual_state()

func _sync_wheel_visual_state() -> void:
	synced_wheel_steering = _visual_steering
	var spin_values := PackedFloat32Array()
	spin_values.resize(WHEEL_GROUPS.size())
	for i: int in WHEEL_GROUPS.size():
		spin_values[i] = _wheel_spin.get(WHEEL_GROUPS[i], 0.0)
	synced_wheel_spin = spin_values

func _apply_synced_wheel_visuals() -> void:
	if synced_wheel_spin.size() < WHEEL_GROUPS.size():
		return
	for i: int in WHEEL_GROUPS.size():
		var wheel_group: String = WHEEL_GROUPS[i]
		var wheel: Node3D = _wheel_nodes.get(wheel_group, null)
		if wheel == null:
			continue

		var base_rotation: Vector3 = _wheel_base_rotation.get(wheel_group, wheel.rotation)
		var steer_offset := 0.0
		if wheel_group.ends_with("-front"):
			steer_offset = synced_wheel_steering

		var spin: float = synced_wheel_spin[i]
		wheel.rotation = Vector3(base_rotation.x + spin, base_rotation.y + steer_offset, base_rotation.z)
