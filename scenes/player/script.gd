extends VehicleBody3D

const STEERING_ANGLE := 0.45
const THROTTLE_FORCE := 100.0
const IDLE_TURN_SPEED := 1.8
const IDLE_TURN_SPEED_THRESHOLD := 0.8
const IDLE_TURN_DAMPING := 8.0
const CAR_TYPES := ["speedster", "retro"]

@onready var camera: Camera3D = $Camera

@export var name_plate: Label3D

@export var hitpoints: int = 100

var _car_type: String = "speedster"
@export_enum("speedster", "retro") var car_type: String = "speedster":
	get:
		return _car_type
	set(value):
		_set_car_type(value)

var player_id: int = -1
var player_name: String = ""
var _is_local := false

var powerup: String = ""

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
	set_physics_process(_is_local)

func _physics_process(delta: float) -> void:
	var turn_input := Input.get_axis("turn_right", "turn_left")
	var throttle_input := Input.get_axis("backward", "forward")

	steering = turn_input * STEERING_ANGLE
	engine_force = throttle_input * THROTTLE_FORCE

	if absf(throttle_input) <= 0.01 and linear_velocity.length() <= IDLE_TURN_SPEED_THRESHOLD:
		var next_angular_velocity := angular_velocity
		if absf(turn_input) > 0.01:
			next_angular_velocity.y = turn_input * IDLE_TURN_SPEED
		else:
			next_angular_velocity.y = move_toward(next_angular_velocity.y, 0.0, IDLE_TURN_DAMPING * delta)
		angular_velocity = next_angular_velocity


func _on_interaction_available(body: Node3D) -> void:
	if _is_local and body.is_in_group("pickupable"):
		body.interact({})

func _sync_label() -> void:
	if _is_local:
		name_plate.text = ""
		return
	name_plate.text = "%s (%s)" % [player_name, powerup] if powerup else player_name

func _set_car_type(value: String) -> void:
	_car_type = value

	for type_name: String in CAR_TYPES:
		var is_selected: bool = type_name == value
		for node: Node in get_tree().get_nodes_in_group("%s-car" % type_name):
			if node == self or not is_ancestor_of(node):
				continue
			if node is Node3D:
				node.visible = is_selected
			if node is CollisionShape3D:
				node.disabled = not is_selected
