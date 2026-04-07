extends VehicleBody3D

const STEERING_ANGLE := 0.45
const THROTTLE_FORCE := 100.0
const IDLE_TURN_SPEED := 1.8
const IDLE_TURN_SPEED_THRESHOLD := 0.8
const IDLE_TURN_DAMPING := 8.0

@onready var camera: Camera3D = $Camera

var player_id: int = -1
var _is_local := false

var powerup: String = ""

func prepare(data: Dictionary) -> void:
	player_id = int(data["peer_id"])
	set_multiplayer_authority(player_id)
	name = str(player_id)


func _ready() -> void:
	_is_local = multiplayer.get_unique_id() == player_id
	camera.current = _is_local
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
