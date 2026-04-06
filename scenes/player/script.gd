extends CharacterBody3D

@export var name_label: Label3D
@export var camera: Camera3D
@export_range(0.1, 2.0, 0.05) var drive_multiplier := 0.3

const MAX_FORWARD_SPEED := 10.0
const MAX_REVERSE_SPEED := 10.0
const ACCELERATION := 28.0
const BRAKE_DECELERATION := 50.0
const COAST_DECELERATION := 50.0
const TURN_SPEED := 5.0

const LATERAL_GRIP := 18.0
const DRIFT_GRIP := 6.0
const DRIFT_START_SPEED_RATIO := 0.6
const DRIFT_LATERAL_IMPULSE := 0.75
const DRIFT_MAX_LATERAL_RATIO := 0.6
const MAX_DRIFT_SPEED_BOOST := 0.15

var player_id: int = -1
var _is_local := false

@export var powerup: String = "":
	set(value):
		powerup = value
		name_label.text = "%s (%s)" % [str(player_id), value]

func prepare(data: Dictionary):
	player_id = int(data["peer_id"])
	set_multiplayer_authority(player_id)
	name = str(player_id)


func _ready() -> void:
	name_label.text = str(player_id)

	_is_local = (multiplayer.get_unique_id() == player_id)

	camera.current = _is_local
	set_process_input(_is_local)
	set_physics_process(_is_local)

	if _is_local:
		name_label.visible = false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	var scaled_max_forward_speed := MAX_FORWARD_SPEED * drive_multiplier
	var scaled_max_reverse_speed := MAX_REVERSE_SPEED * drive_multiplier
	var scaled_acceleration := ACCELERATION * drive_multiplier
	var scaled_brake_deceleration := BRAKE_DECELERATION * drive_multiplier
	var scaled_coast_deceleration := COAST_DECELERATION * drive_multiplier
	var scaled_turn_speed := TURN_SPEED * drive_multiplier
	var scaled_lateral_grip := LATERAL_GRIP * drive_multiplier
	var scaled_drift_grip := DRIFT_GRIP * drive_multiplier
	var scaled_drift_lateral_impulse := DRIFT_LATERAL_IMPULSE * drive_multiplier

	var throttle := Input.get_action_strength("forward") - Input.get_action_strength("backward")
	var steering := Input.get_action_strength("turn_right") - Input.get_action_strength("turn_left")

	var forward := -transform.basis.z.normalized()
	var right := transform.basis.x.normalized()
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var forward_speed := planar_velocity.dot(forward)
	var lateral_speed := planar_velocity.dot(right)

	var target_speed := 0.0
	if throttle > 0.0:
		target_speed = throttle * scaled_max_forward_speed
	elif throttle < 0.0:
		target_speed = throttle * scaled_max_reverse_speed

	if throttle != 0.0:
		var accel := scaled_acceleration
		if sign(target_speed) != sign(forward_speed) and absf(forward_speed) > 0.1:
			accel = scaled_brake_deceleration
		forward_speed = move_toward(forward_speed, target_speed, accel * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, scaled_coast_deceleration * delta)

	var speed_ratio := clampf(absf(forward_speed) / scaled_max_forward_speed, 0.0, 1.0)
	if steering != 0.0:
		var steering_strength := 0.3 + 0.7 * speed_ratio
		var steer_direction := 1.0
		if forward_speed < -0.05:
			steer_direction = -1.0
		elif absf(forward_speed) <= 0.05 and throttle < 0.0:
			steer_direction = -1.0
		rotate_y(-steering * steer_direction * scaled_turn_speed * steering_strength * delta)

	var drift_ratio := clampf((speed_ratio - DRIFT_START_SPEED_RATIO) / (1.0 - DRIFT_START_SPEED_RATIO), 0.0, 1.0)
	var active_drift := drift_ratio * absf(steering)
	var grip := lerpf(scaled_lateral_grip, scaled_drift_grip, active_drift)

	# At higher speed and steering input, preserve more sideways momentum.
	lateral_speed += -steering * absf(forward_speed) * scaled_drift_lateral_impulse * active_drift * delta
	var max_lateral_speed := maxf(0.8, absf(forward_speed) * DRIFT_MAX_LATERAL_RATIO)
	lateral_speed = clampf(lateral_speed, -max_lateral_speed, max_lateral_speed)
	lateral_speed = move_toward(lateral_speed, 0.0, grip * delta)

	forward = - transform.basis.z.normalized()
	right = transform.basis.x.normalized()
	var car_velocity := forward * forward_speed + right * lateral_speed
	var max_planar_speed := scaled_max_forward_speed * (1.0 + MAX_DRIFT_SPEED_BOOST * active_drift)
	if car_velocity.length() > max_planar_speed:
		car_velocity = car_velocity.normalized() * max_planar_speed
	velocity.x = car_velocity.x
	velocity.z = car_velocity.z

	move_and_slide()


func _on_interaction_available(body: Node3D) -> void:
	if not _is_local:
		return

	if body.is_in_group("pickupable"):
		body.interact({})
