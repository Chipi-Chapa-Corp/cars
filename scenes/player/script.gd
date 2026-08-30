extends RigidBody3D

signal light_attack_hit(target: Node3D, damage: int)

enum LightAttackState {
	READY,
	CHARGING,
}

const MAX_FORWARD_SPEED := 7.0
const MAX_REVERSE_SPEED := 6.0
const ENGINE_FORCE := 210.0
const REVERSE_ENGINE_MULTIPLIER := 0.7
const ENGINE_TAPER_SPEED := 1.0
const THROTTLE_RESPONSE := 2.5
const THROTTLE_DEADZONE := 0.05

const LOW_SPEED_STEERING_ANGLE := 0.52
const HIGH_SPEED_STEERING_ANGLE := 0.11
const HANDBRAKE_STEERING_MULTIPLIER := 1.8
const STEERING_RESPONSE := 7.0
const WHEEL_STEER_INTERPOLATION_SPEED := 10.0

const SERVICE_BRAKE_FORCE := 360.0
const COAST_BRAKE_FORCE := 80.0
const HANDBRAKE_FORCE := 240.0
const HANDBRAKE_ENGAGE_SPEED := 18.0
const HANDBRAKE_RELEASE_SPEED := 2.5
const BRAKE_DIRECTION_CHANGE_SPEED := 0.35
const STOP_SPEED := 0.08

const WHEEL_RADIUS := 0.1
const SUSPENSION_REST_LENGTH := 0.12
const SUSPENSION_TRAVEL := 0.06
const SUSPENSION_STIFFNESS := 5000.0
const SUSPENSION_DAMPING := 350.0
const SUSPENSION_MAX_FORCE := 650.0
const ANTI_ROLL_STIFFNESS := 1800.0
const ANTI_ROLL_MAX_FORCE := 140.0

const FRONT_TIRE_GRIP := 2.6
const REAR_TIRE_GRIP := 2.35
const HANDBRAKE_REAR_GRIP := 0.55
const TIRE_LATERAL_STIFFNESS := 260.0
const TIRE_GRIP_PEAK_SLIP_ANGLE := 0.17
const TIRE_GRIP_FULL_SLIDE_ANGLE := 0.62
const FRONT_TIRE_SLIDE_GRIP_MULTIPLIER := 0.85
const REAR_TIRE_SLIDE_GRIP_MULTIPLIER := 0.75
const LONGITUDINAL_FORCE_APPLICATION_HEIGHT := 0.05
const LATERAL_FORCE_APPLICATION_HEIGHT := 0.1

const AERODYNAMIC_LINEAR_DRAG := 0.35
const AERODYNAMIC_QUADRATIC_DRAG := 0.24
const GROUNDED_PITCH_ROLL_DAMPING := 10.0
const GROUNDED_YAW_DAMPING := 8.0
const AIRBORNE_PITCH_ROLL_DAMPING := 3.0
const AIRBORNE_YAW_DAMPING := 1.2

const SKID_MARK_WIDTH := 0.055
const SKID_MARK_SURFACE_OFFSET := 0.004
const SKID_MARK_MIN_POINT_DISTANCE := 0.025
const SKID_MARK_MAX_SEGMENT_LENGTH := 0.45
const SKID_MARK_MIN_SPEED := 2.0
const SKID_MARK_MIN_LATERAL_SPEED := 0.8
const SKID_MARK_MIN_SLIP_ANGLE := 0.14
const SKID_MARK_MIN_HANDBRAKE := 0.45
const MAX_SKID_MARK_SEGMENTS := 1000

const LIGHT_ATTACK_CHARGE_SPEED := 9.0
const LIGHT_ATTACK_CHARGE_DURATION := 0.2
const LIGHT_ATTACK_FORCE := 1800.0
const LIGHT_ATTACK_COOLDOWN_DURATION := 0.5
const LIGHT_ATTACK_HIT_GRACE_DURATION := 0.8
const LIGHT_ATTACK_SELF_RECOIL_SPEED := 3.0
const LIGHT_ATTACK_DAMAGE := 10
const LIGHT_ATTACK_TARGET_IMPULSE := 120.0
const LIGHT_ATTACK_DEBUG_LOGS := true

const DRIVE_SHARE := {
	"wheel-left-front": 0.3,
	"wheel-right-front": 0.3,
	"wheel-left-rear": 0.2,
	"wheel-right-rear": 0.2,
}
const SERVICE_BRAKE_SHARE := {
	"wheel-left-front": 0.35,
	"wheel-right-front": 0.35,
	"wheel-left-rear": 0.15,
	"wheel-right-rear": 0.15,
}
const CAR_TYPES := ["speedster", "retro"]
const WHEEL_GROUPS := [
	"wheel-left-front",
	"wheel-right-front",
	"wheel-left-rear",
	"wheel-right-rear",
]
const FRONT_WHEELS := ["wheel-left-front", "wheel-right-front"]
const REAR_WHEELS := ["wheel-left-rear", "wheel-right-rear"]

@onready var camera: Camera3D = $Camera
@onready var _light_attack_hitbox: Area3D = $LightAttackHitbox
@onready var _light_attack_shape_cast: ShapeCast3D = $LightAttackShapeCast
@onready var _light_attack_charge_streaks_left: GPUParticles3D = $LightAttackEffects/ChargeStreaksLeft
@onready var _light_attack_charge_streaks_right: GPUParticles3D = $LightAttackEffects/ChargeStreaksRight
@onready var _light_attack_charge_dust_left: GPUParticles3D = $LightAttackEffects/ChargeDustLeft
@onready var _light_attack_charge_dust_right: GPUParticles3D = $LightAttackEffects/ChargeDustRight
@onready var _light_attack_impact_sparks: GPUParticles3D = $LightAttackEffects/ImpactSparks

@export var healthbar: TextureProgressBar
@export var light_attack_cooldown_bar: TextureProgressBar
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

var _wheel_nodes: Dictionary = {}
var _wheel_base_rotation: Dictionary = {}
var _wheel_base_position: Dictionary = {}
var _wheel_visual_height_offset: Dictionary = {}
var _wheel_spin: Dictionary = {}
var _wheel_suspension_length: Dictionary = {}
var _wheel_forward_speed: Dictionary = {}
var _wheel_lateral_speed: Dictionary = {}
var _wheel_slip_angle: Dictionary = {}
var _wheel_compression: Dictionary = {}
var _wheel_contact_point: Dictionary = {}
var _wheel_contact_normal: Dictionary = {}
var _visual_steering := 0.0
var _steering_angle := 0.0
var _smoothed_throttle := 0.0
var _drive_input := 0.0
var _service_brake_input := 0.0
var _coast_brake_input := 0.0
var _handbrake_amount := 0.0
var _grounded_wheel_count := 0
var _powerup_scene_instance: Node
var _camera_local_transform := Transform3D.IDENTITY
var _camera_yaw_basis := Basis.IDENTITY
var _skid_mark_mesh: ImmediateMesh
var _skid_mark_material: StandardMaterial3D
var _skid_mark_segments: Array[Dictionary] = []
var _last_skid_contact: Dictionary = {}
var _light_attack_state := LightAttackState.READY
var _light_attack_time_remaining := 0.0
var _light_attack_cooldown_remaining := 0.0
var _light_attack_hit_grace_remaining := 0.0
var _light_attack_forward := Vector3.ZERO
var _light_attack_start_planar_speed := 0.0
var _light_attack_debug_file: FileAccess
var _light_attack_debug_path := ""

@onready var _wheel_rays: Dictionary = {
	"wheel-left-front": $FrontLeft as RayCast3D,
	"wheel-right-front": $FrontRight as RayCast3D,
	"wheel-left-rear": $RearLeft as RayCast3D,
	"wheel-right-rear": $RearRight as RayCast3D,
}

var _powerup: String = ""
@export var powerup: String = "":
	set(value):
		if _powerup == value:
			return
		_powerup = value
		_sync_powerup_scene()
	get:
		return _powerup


func _ready() -> void:
	_setup_light_attack_debug_log()
	car_type = CAR_TYPES.pick_random()
	_cache_wheel_visual_offsets()
	_setup_skid_marks()
	_camera_local_transform = camera.transform
	camera.top_level = true
	_update_camera_transform()
	camera.current = true
	_sync_powerup_scene()
	_sync_healthbar()
	_sync_light_attack_cooldown_bar()


func _process(_delta: float) -> void:
	_update_camera_transform()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("light_attack"):
		_log_light_attack_event("attack_requested")
		_start_light_attack()
	_light_attack_cooldown_remaining = maxf(
		_light_attack_cooldown_remaining - delta,
		0.0
	)
	_update_light_attack_hit_grace(delta)
	_read_driver_input(delta)
	_apply_wheel_forces(delta)
	_update_skid_marks()
	_apply_anti_roll_forces()
	_apply_body_drag_and_stability()

	_visual_steering = move_toward(
		_visual_steering,
		_steering_angle,
		WHEEL_STEER_INTERPOLATION_SPEED * delta
	)
	_update_wheel_visuals(delta)
	_update_light_attack(delta)
	_sync_light_attack_cooldown_bar()

	if Input.is_action_just_pressed("activate"):
		_activate_powerup()


func _start_light_attack() -> void:
	if _light_attack_state != LightAttackState.READY:
		_log_light_attack_event("attack_rejected", {"reason": "state_not_ready"})
		return
	if _light_attack_cooldown_remaining > 0.0:
		_log_light_attack_event("attack_rejected", {"reason": "cooldown_active"})
		return
	if not _is_any_wheel_grounded():
		_log_light_attack_event("attack_rejected", {"reason": "not_grounded"})
		return
	_light_attack_forward = global_transform.basis.z.slide(Vector3.UP).normalized()
	if _light_attack_forward.length_squared() <= 0.0001:
		_log_light_attack_event("attack_rejected", {"reason": "invalid_forward"})
		return
	if _light_attack_hit_grace_remaining > 0.0:
		_log_light_attack_event("hit_grace_replaced_by_new_attack")
	_light_attack_hit_grace_remaining = 0.0
	_light_attack_start_planar_speed = linear_velocity.slide(Vector3.UP).length()
	_light_attack_state = LightAttackState.CHARGING
	_light_attack_time_remaining = LIGHT_ATTACK_CHARGE_DURATION
	_light_attack_shape_cast.enabled = true
	_set_light_attack_charge_particles(true)
	_log_light_attack_event("attack_started")

	for body: Node3D in _light_attack_hitbox.get_overlapping_bodies():
		if body != self:
			_handle_light_attack_collision(body, "start_overlap_poll")
			return


func _update_light_attack(delta: float) -> void:
	if _light_attack_state == LightAttackState.READY:
		return

	_light_attack_time_remaining -= delta
	match _light_attack_state:
		LightAttackState.CHARGING:
			if _light_attack_time_remaining <= 0.0:
				_finish_light_attack_charge(null, "timeout")
				return
			_log_light_attack_event("attack_active_tick")
			_update_light_attack_dust_emitters()
			_apply_light_attack_force(delta)


func _finish_light_attack_charge(
	target: Node3D = null,
	detection_source: String = "unknown"
) -> void:
	if _light_attack_state != LightAttackState.CHARGING:
		_log_light_attack_event("finish_ignored", {
			"detection_source": detection_source,
			"target": _light_attack_debug_node_name(target),
		})
		return
	_log_light_attack_event("attack_finishing", {
		"detection_source": detection_source,
		"target": _light_attack_debug_node_name(target),
	})
	_set_light_attack_charge_particles(false)
	_remove_light_attack_speed_boost()
	if target != null:
		_apply_light_attack_hit(target)
		_apply_light_attack_self_recoil()
		_emit_light_attack_impact_particles(target)
	else:
		_light_attack_hit_grace_remaining = LIGHT_ATTACK_HIT_GRACE_DURATION
		_log_light_attack_event("hit_grace_started")
	_finish_light_attack()


func _finish_light_attack() -> void:
	_light_attack_state = LightAttackState.READY
	_light_attack_time_remaining = 0.0
	_light_attack_cooldown_remaining = LIGHT_ATTACK_COOLDOWN_DURATION
	_light_attack_shape_cast.enabled = false
	_log_light_attack_event("attack_finished")


func _update_light_attack_hit_grace(delta: float) -> void:
	if _light_attack_hit_grace_remaining <= 0.0:
		return
	_light_attack_hit_grace_remaining = maxf(
		_light_attack_hit_grace_remaining - delta,
		0.0
	)
	_log_light_attack_event("hit_grace_active_tick")
	if _light_attack_hit_grace_remaining <= 0.0:
		_log_light_attack_event("hit_grace_expired")


func _handle_light_attack_collision(target: Node3D, detection_source: String) -> void:
	if _light_attack_state == LightAttackState.CHARGING:
		_finish_light_attack_charge(target, detection_source)
		return
	if _light_attack_hit_grace_remaining <= 0.0:
		_log_light_attack_event("collision_ignored", {
			"detection_source": detection_source,
			"reason": "no_active_attack_or_grace",
			"target": _light_attack_debug_node_name(target),
		})
		return

	_light_attack_forward = global_transform.basis.z.slide(Vector3.UP).normalized()
	_log_light_attack_event("hit_grace_collision", {
		"detection_source": detection_source,
		"target": _light_attack_debug_node_name(target),
	})
	_light_attack_hit_grace_remaining = 0.0
	_apply_light_attack_hit(target)
	_apply_light_attack_self_recoil()
	_emit_light_attack_impact_particles(target)
	_log_light_attack_event("hit_grace_consumed")


func _apply_light_attack_force(delta: float) -> void:
	_light_attack_forward = global_transform.basis.z.slide(Vector3.UP).normalized()
	if _light_attack_forward.length_squared() <= 0.0001:
		_log_light_attack_event("attack_force_skipped", {"reason": "invalid_forward"})
		return
	var forward_speed := linear_velocity.dot(_light_attack_forward)
	var speed_gap := maxf(LIGHT_ATTACK_CHARGE_SPEED - forward_speed, 0.0)
	if speed_gap <= 0.0:
		_log_light_attack_event("attack_force_skipped", {
			"reason": "speed_cap_reached",
			"forward_speed": forward_speed,
		})
		return
	var force_to_speed_cap := speed_gap * mass / maxf(delta, 0.0001)
	var attack_force := _light_attack_forward * minf(LIGHT_ATTACK_FORCE, force_to_speed_cap)
	_log_light_attack_event("attack_force_applied", {
		"forward_speed": forward_speed,
		"speed_gap": speed_gap,
		"force": attack_force,
	})
	apply_central_force(attack_force)


func _remove_light_attack_speed_boost() -> void:
	var vertical_velocity := Vector3.UP * linear_velocity.dot(Vector3.UP)
	var planar_velocity := linear_velocity.slide(Vector3.UP)
	var planar_speed := planar_velocity.length()
	if planar_speed <= _light_attack_start_planar_speed:
		_log_light_attack_event("dash_speed_cap_not_needed", {
			"start_planar_speed": _light_attack_start_planar_speed,
			"current_planar_speed": planar_speed,
		})
		return

	var capped_planar_velocity := (
		planar_velocity.normalized() * _light_attack_start_planar_speed
	)
	_log_light_attack_event("dash_speed_boost_removed", {
		"start_planar_speed": _light_attack_start_planar_speed,
		"current_planar_speed": planar_speed,
		"velocity_before": linear_velocity,
		"velocity_after": capped_planar_velocity + vertical_velocity,
	})
	linear_velocity = capped_planar_velocity + vertical_velocity


func _apply_light_attack_self_recoil() -> void:
	var forward_speed := linear_velocity.dot(_light_attack_forward)
	var recoil_velocity_change := maxf(
		forward_speed + LIGHT_ATTACK_SELF_RECOIL_SPEED,
		0.0
	)
	var recoil_impulse := -_light_attack_forward * recoil_velocity_change * mass
	_log_light_attack_event("self_recoil_applied", {
		"forward_speed_before": forward_speed,
		"velocity_before": linear_velocity,
		"impulse": recoil_impulse,
	})
	apply_central_impulse(recoil_impulse)


func _get_swept_light_attack_targets() -> Array[String]:
	var targets: Array[String] = []
	if not _light_attack_shape_cast.enabled:
		return targets
	_light_attack_shape_cast.force_shapecast_update()
	for collision_index in _light_attack_shape_cast.get_collision_count():
		var collider := _light_attack_shape_cast.get_collider(collision_index) as Node3D
		if collider != null and collider != self:
			targets.append(_light_attack_debug_node_name(collider))
	return targets


func _setup_light_attack_debug_log() -> void:
	if not LIGHT_ATTACK_DEBUG_LOGS:
		return
	_light_attack_debug_path = "user://light_attack_debug_%d_%d.log" % [
		OS.get_process_id(),
		get_instance_id(),
	]
	_light_attack_debug_file = FileAccess.open(
		_light_attack_debug_path,
		FileAccess.WRITE
	)
	if _light_attack_debug_file == null:
		push_warning("Unable to open light attack debug log: %s" % _light_attack_debug_path)
		return
	_log_light_attack_event("debug_log_opened", {
		"path": ProjectSettings.globalize_path(_light_attack_debug_path),
	})


func _log_light_attack_event(event: String, details: Dictionary = {}) -> void:
	if not LIGHT_ATTACK_DEBUG_LOGS:
		return
	var body_forward := global_transform.basis.z.slide(Vector3.UP).normalized()
	var area_targets: Array[String] = []
	for body: Node3D in _light_attack_hitbox.get_overlapping_bodies():
		if body != self:
			area_targets.append(_light_attack_debug_node_name(body))
	var data := {
		"event": event,
		"state": _light_attack_state_name(),
		"attack_time_remaining": _light_attack_time_remaining,
		"cooldown_remaining": _light_attack_cooldown_remaining,
		"hit_grace_remaining": _light_attack_hit_grace_remaining,
		"start_planar_speed": _light_attack_start_planar_speed,
		"grounded_wheels": _grounded_wheel_count,
		"position": global_position,
		"velocity": linear_velocity,
		"angular_velocity": angular_velocity,
		"body_forward": body_forward,
		"attack_forward": _light_attack_forward,
		"forward_speed": linear_velocity.dot(body_forward),
		"throttle_input": Input.get_axis("backward", "forward"),
		"turn_input": Input.get_axis("turn_right", "turn_left"),
		"area_targets": area_targets,
		"swept_targets_diagnostic_only": _get_swept_light_attack_targets(),
	}
	for key: Variant in details:
		data[key] = details[key]
	var line := "[LightAttack] frame=%d ticks_ms=%d %s" % [
		Engine.get_physics_frames(),
		Time.get_ticks_msec(),
		str(data),
	]
	print(line)
	if _light_attack_debug_file != null:
		_light_attack_debug_file.store_line(line)
		_light_attack_debug_file.flush()


func _light_attack_state_name() -> String:
	match _light_attack_state:
		LightAttackState.READY:
			return "READY"
		LightAttackState.CHARGING:
			return "CHARGING"
	return "UNKNOWN_%s" % _light_attack_state


func _light_attack_debug_node_name(node: Node) -> String:
	if node == null:
		return "<null>"
	var description := "%s:%s#%d" % [
		str(node.get_path()),
		node.get_class(),
		node.get_instance_id(),
	]
	if node is Node3D:
		description += "@%s" % (node as Node3D).global_position
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		description += "[layer=%d mask=%d]" % [
			collision_object.collision_layer,
			collision_object.collision_mask,
		]
	return description


func _set_light_attack_charge_particles(is_emitting: bool) -> void:
	_log_light_attack_event("charge_particles_changed", {"emitting": is_emitting})
	for particles: GPUParticles3D in [
		_light_attack_charge_streaks_left,
		_light_attack_charge_streaks_right,
	]:
		particles.emitting = is_emitting
		if is_emitting:
			particles.restart()
	if is_emitting:
		_update_light_attack_dust_emitters()
	else:
		_light_attack_charge_dust_left.emitting = false
		_light_attack_charge_dust_right.emitting = false


func _update_light_attack_dust_emitters() -> void:
	var wheel_emitters := {
		"wheel-left-rear": _light_attack_charge_dust_left,
		"wheel-right-rear": _light_attack_charge_dust_right,
	}
	for wheel_group: String in wheel_emitters:
		var particles: GPUParticles3D = wheel_emitters[wheel_group]
		var point_value: Variant = _wheel_contact_point.get(wheel_group, null)
		var normal_value: Variant = _wheel_contact_normal.get(wheel_group, null)
		if point_value == null or normal_value == null:
			particles.emitting = false
			continue

		var contact_point: Vector3 = point_value
		var contact_normal: Vector3 = normal_value
		var surface_forward := global_transform.basis.z.slide(contact_normal).normalized()
		if surface_forward.length_squared() <= 0.0001:
			surface_forward = _light_attack_forward.slide(contact_normal).normalized()
		var surface_right := contact_normal.cross(surface_forward).normalized()
		particles.global_transform = Transform3D(
			Basis(surface_right, contact_normal, surface_forward),
			contact_point + contact_normal * 0.035
		)
		if not particles.emitting:
			particles.emitting = true
			particles.restart()


func _emit_light_attack_impact_particles(target: Node3D) -> void:
	var attacker_bounds := _get_collision_bounds(self)
	var target_bounds := _get_collision_bounds(target)
	var attacker_center: Vector3 = attacker_bounds["center"]
	var target_center: Vector3 = target_bounds["center"]
	var center_direction := (target_center - attacker_center).slide(Vector3.UP)
	if center_direction.length_squared() <= 0.0001:
		center_direction = _light_attack_forward
	center_direction = center_direction.normalized()

	var attacker_surface := (
		attacker_center
		+ center_direction * _distance_to_bounds_surface(
			attacker_bounds,
			center_direction
		)
	)
	var target_surface := (
		target_center
		- center_direction * _distance_to_bounds_surface(
			target_bounds,
			-center_direction
		)
	)
	var impact_point := (attacker_surface + target_surface) * 0.5
	var impact_normal := -center_direction

	var impact_right := Vector3.UP.cross(impact_normal)
	if impact_right.length_squared() <= 0.0001:
		impact_right = global_transform.basis.x.slide(impact_normal)
	impact_right = impact_right.normalized()
	var impact_up := impact_normal.cross(impact_right).normalized()
	_light_attack_impact_sparks.global_transform = Transform3D(
		Basis(impact_right, impact_up, impact_normal).orthonormalized(),
		impact_point + impact_normal * 0.012
	)
	_light_attack_impact_sparks.emitting = true
	_light_attack_impact_sparks.restart()
	_log_light_attack_event("impact_sparks_emitted", {
		"target": _light_attack_debug_node_name(target),
		"impact_point": impact_point,
		"impact_normal": impact_normal,
	})


func _get_collision_bounds(body: Node3D) -> Dictionary:
	for child: Node in body.get_children():
		if not child is CollisionShape3D:
			continue
		var collision_shape := child as CollisionShape3D
		if collision_shape.disabled or collision_shape.shape == null:
			continue
		var local_bounds := _get_shape_local_bounds(collision_shape.shape)
		if local_bounds.size.length_squared() <= 0.0001:
			continue
		return {
			"center": collision_shape.global_transform * local_bounds.get_center(),
			"transform": collision_shape.global_transform,
			"local_bounds": local_bounds,
		}

	var fallback_size := Vector3(0.7, 0.5, 0.7)
	return {
		"center": body.global_position,
		"transform": body.global_transform,
		"local_bounds": AABB(-fallback_size * 0.5, fallback_size),
	}


func _get_shape_local_bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var box := shape as BoxShape3D
		return AABB(-box.size * 0.5, box.size)
	if shape is ConvexPolygonShape3D:
		var convex := shape as ConvexPolygonShape3D
		if convex.points.is_empty():
			return AABB()
		var minimum := convex.points[0]
		var maximum := convex.points[0]
		for point: Vector3 in convex.points:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		return AABB(minimum, maximum - minimum)
	if shape is SphereShape3D:
		var sphere := shape as SphereShape3D
		var diameter := Vector3.ONE * sphere.radius * 2.0
		return AABB(-diameter * 0.5, diameter)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		var capsule_size := Vector3(
			capsule.radius * 2.0,
			capsule.height,
			capsule.radius * 2.0
		)
		return AABB(-capsule_size * 0.5, capsule_size)
	return AABB()


func _distance_to_bounds_surface(bounds: Dictionary, world_direction: Vector3) -> float:
	var shape_transform: Transform3D = bounds["transform"]
	var local_bounds: AABB = bounds["local_bounds"]
	var local_direction := shape_transform.basis.inverse() * world_direction
	var half_size := local_bounds.size * 0.5
	var distance := INF
	for axis in 3:
		var axis_direction := absf(local_direction[axis])
		if axis_direction > 0.0001:
			distance = minf(distance, half_size[axis] / axis_direction)
	if is_inf(distance):
		return 0.0
	return distance


func _apply_light_attack_hit(target: Node3D) -> void:
	var damage_target: Node = target
	while damage_target != null and not damage_target.has_method("take_damage"):
		damage_target = damage_target.get_parent()
	if damage_target != null:
		damage_target.call("take_damage", LIGHT_ATTACK_DAMAGE, self)
	var target_impulse := Vector3.ZERO
	if target is RigidBody3D:
		var target_body := target as RigidBody3D
		target_impulse = _light_attack_forward * LIGHT_ATTACK_TARGET_IMPULSE
		target_body.apply_central_impulse(target_impulse)
	_log_light_attack_event("attack_hit_applied", {
		"target": _light_attack_debug_node_name(target),
		"damage_target": _light_attack_debug_node_name(damage_target),
		"damage": LIGHT_ATTACK_DAMAGE,
		"target_impulse": target_impulse,
	})
	light_attack_hit.emit(target, LIGHT_ATTACK_DAMAGE)


func _on_light_attack_hitbox_body_entered(body: Node3D) -> void:
	_log_light_attack_event("area_body_entered", {
		"target": _light_attack_debug_node_name(body),
	})
	if body != self:
		_handle_light_attack_collision(body, "area_body_entered")


func _on_light_attack_body_contact(body: Node) -> void:
	_log_light_attack_event("rigid_body_contact", {
		"target": _light_attack_debug_node_name(body),
	})
	if body == self:
		return
	_handle_light_attack_collision(body as Node3D, "rigid_body_contact")


func _read_driver_input(delta: float) -> void:
	var turn_input := Input.get_axis("turn_right", "turn_left")
	var raw_throttle := Input.get_axis("backward", "forward")
	var handbrake_pressed := Input.is_action_pressed("handbrake")
	var forward_speed := linear_velocity.dot(global_transform.basis.z.normalized())
	var planar_speed := linear_velocity.slide(Vector3.UP).length()
	var speed_ratio := clampf(planar_speed / MAX_FORWARD_SPEED, 0.0, 1.0)
	var steering_limit := lerpf(
		LOW_SPEED_STEERING_ANGLE,
		HIGH_SPEED_STEERING_ANGLE,
		speed_ratio
	)
	if handbrake_pressed:
		steering_limit = minf(
			steering_limit * HANDBRAKE_STEERING_MULTIPLIER,
			LOW_SPEED_STEERING_ANGLE
		)
	_steering_angle = move_toward(
		_steering_angle,
		turn_input * steering_limit,
		STEERING_RESPONSE * delta
	)

	if absf(raw_throttle) <= THROTTLE_DEADZONE:
		_smoothed_throttle = move_toward(_smoothed_throttle, 0.0, THROTTLE_RESPONSE * delta)
	else:
		_smoothed_throttle = move_toward(
			_smoothed_throttle,
			raw_throttle,
			THROTTLE_RESPONSE * delta
		)

	_drive_input = 0.0
	_service_brake_input = 0.0
	_coast_brake_input = 0.0
	var has_throttle := absf(raw_throttle) > THROTTLE_DEADZONE
	var is_changing_direction := (
		has_throttle
		and absf(forward_speed) > BRAKE_DIRECTION_CHANGE_SPEED
		and signf(raw_throttle) != signf(forward_speed)
	)
	if is_changing_direction:
		_service_brake_input = absf(raw_throttle)
	elif has_throttle:
		_drive_input = _smoothed_throttle
	else:
		_coast_brake_input = 1.0

	var handbrake_target := 1.0 if handbrake_pressed else 0.0
	var handbrake_speed := (
		HANDBRAKE_ENGAGE_SPEED
		if handbrake_target > _handbrake_amount
		else HANDBRAKE_RELEASE_SPEED
	)
	_handbrake_amount = move_toward(
		_handbrake_amount,
		handbrake_target,
		handbrake_speed * delta
	)


func _apply_wheel_forces(delta: float) -> void:
	_grounded_wheel_count = 0
	_wheel_compression.clear()
	_wheel_contact_point.clear()
	_wheel_contact_normal.clear()
	_wheel_lateral_speed.clear()
	_wheel_slip_angle.clear()
	var body_up := global_transform.basis.y.normalized()
	var body_forward := global_transform.basis.z.normalized()
	var body_forward_speed := linear_velocity.dot(body_forward)
	var total_drive_force := _calculate_drive_force()

	for wheel_group: String in WHEEL_GROUPS:
		var ray: RayCast3D = _wheel_rays.get(wheel_group, null)
		if ray == null:
			continue

		ray.force_raycast_update()
		if not ray.is_colliding():
			_wheel_suspension_length[wheel_group] = SUSPENSION_REST_LENGTH + SUSPENSION_TRAVEL
			_wheel_forward_speed[wheel_group] = body_forward_speed
			continue

		_grounded_wheel_count += 1
		var contact_point := ray.get_collision_point()
		var contact_normal := ray.get_collision_normal().normalized()
		var ray_distance := ray.global_position.distance_to(contact_point)
		var suspension_length := clampf(
			ray_distance - WHEEL_RADIUS,
			SUSPENSION_REST_LENGTH - SUSPENSION_TRAVEL,
			SUSPENSION_REST_LENGTH + SUSPENSION_TRAVEL
		)
		var compression := maxf(SUSPENSION_REST_LENGTH - suspension_length, 0.0)
		var contact_velocity := _velocity_at_world_point(contact_point)
		var suspension_velocity := contact_velocity.dot(body_up)
		var suspension_force := clampf(
			compression * SUSPENSION_STIFFNESS - suspension_velocity * SUSPENSION_DAMPING,
			0.0,
			SUSPENSION_MAX_FORCE
		)
		apply_force(
			contact_normal * suspension_force,
			contact_point - global_position
		)

		_wheel_suspension_length[wheel_group] = suspension_length
		_wheel_compression[wheel_group] = compression
		_wheel_contact_point[wheel_group] = contact_point
		_wheel_contact_normal[wheel_group] = contact_normal

		var wheel_forward := body_forward.slide(contact_normal).normalized()
		if wheel_group in FRONT_WHEELS:
			wheel_forward = wheel_forward.rotated(contact_normal, _steering_angle).normalized()
		var wheel_side := contact_normal.cross(wheel_forward).normalized()
		contact_velocity = _velocity_at_world_point(contact_point)
		var longitudinal_speed := contact_velocity.dot(wheel_forward)
		var lateral_speed := contact_velocity.dot(wheel_side)
		_wheel_forward_speed[wheel_group] = longitudinal_speed
		_wheel_lateral_speed[wheel_group] = lateral_speed

		var drive_force := total_drive_force * float(DRIVE_SHARE[wheel_group])
		var brake_force := _wheel_brake_force(wheel_group)
		var max_force_to_stop := absf(longitudinal_speed) * mass * 0.25 / maxf(delta, 0.0001)
		brake_force = minf(brake_force, max_force_to_stop)
		var desired_longitudinal_force := drive_force
		if absf(longitudinal_speed) > STOP_SPEED:
			desired_longitudinal_force -= signf(longitudinal_speed) * brake_force

		var slip_angle := atan2(absf(lateral_speed), maxf(absf(longitudinal_speed), 0.5))
		_wheel_slip_angle[wheel_group] = slip_angle
		var slide_amount := smoothstep(
			TIRE_GRIP_PEAK_SLIP_ANGLE,
			TIRE_GRIP_FULL_SLIDE_ANGLE,
			slip_angle
		)
		var grip := FRONT_TIRE_GRIP if wheel_group in FRONT_WHEELS else REAR_TIRE_GRIP
		if wheel_group in REAR_WHEELS:
			grip = lerpf(grip, HANDBRAKE_REAR_GRIP, _handbrake_amount)
		var slide_grip_multiplier := (
			FRONT_TIRE_SLIDE_GRIP_MULTIPLIER
			if wheel_group in FRONT_WHEELS
			else REAR_TIRE_SLIDE_GRIP_MULTIPLIER
		)
		grip *= lerpf(1.0, slide_grip_multiplier, slide_amount)
		var tire_force_limit := suspension_force * grip
		var longitudinal_share := 1.0
		if wheel_group in REAR_WHEELS:
			longitudinal_share = lerpf(1.0, 0.78, _handbrake_amount)
		var longitudinal_force := clampf(
			desired_longitudinal_force,
			-tire_force_limit * longitudinal_share,
			tire_force_limit * longitudinal_share
		)
		var lateral_force_limit := sqrt(maxf(
			tire_force_limit * tire_force_limit
				- longitudinal_force * longitudinal_force,
			0.0
		))
		var lateral_force := clampf(
			-lateral_speed * TIRE_LATERAL_STIFFNESS,
			-lateral_force_limit,
			lateral_force_limit
		)

		var longitudinal_force_height := (
			LONGITUDINAL_FORCE_APPLICATION_HEIGHT
			if absf(_drive_input) > THROTTLE_DEADZONE
			else 0.0
		)
		apply_force(
			wheel_forward * longitudinal_force,
			contact_point
				+ contact_normal * longitudinal_force_height
				- global_position
		)
		apply_force(
			wheel_side * lateral_force,
			contact_point
				+ contact_normal * LATERAL_FORCE_APPLICATION_HEIGHT
				- global_position
		)


func _calculate_drive_force() -> float:
	if absf(_drive_input) <= THROTTLE_DEADZONE:
		return 0.0

	var direction := signf(_drive_input)
	var speed_limit := MAX_FORWARD_SPEED if direction > 0.0 else MAX_REVERSE_SPEED
	var speed_in_drive_direction := linear_velocity.slide(Vector3.UP).length()
	var taper := clampf(
		(speed_limit - speed_in_drive_direction) / ENGINE_TAPER_SPEED,
		0.0,
		1.0
	)
	var force := ENGINE_FORCE * absf(_drive_input) * taper
	if direction < 0.0:
		force *= REVERSE_ENGINE_MULTIPLIER
	return force * direction


func _wheel_brake_force(wheel_group: String) -> float:
	var brake_force := (
		SERVICE_BRAKE_FORCE
		* _service_brake_input
		* float(SERVICE_BRAKE_SHARE[wheel_group])
	)
	brake_force += COAST_BRAKE_FORCE * _coast_brake_input * 0.25
	if wheel_group in REAR_WHEELS:
		brake_force += HANDBRAKE_FORCE * _handbrake_amount * 0.5
	return brake_force


func _apply_anti_roll_forces() -> void:
	_apply_anti_roll_pair("wheel-left-front", "wheel-right-front")
	_apply_anti_roll_pair("wheel-left-rear", "wheel-right-rear")


func _apply_anti_roll_pair(left_group: String, right_group: String) -> void:
	var left_point: Variant = _wheel_contact_point.get(left_group, null)
	var right_point: Variant = _wheel_contact_point.get(right_group, null)
	if left_point == null or right_point == null:
		return
	var compression_difference := (
		float(_wheel_compression.get(left_group, 0.0))
		- float(_wheel_compression.get(right_group, 0.0))
	)
	var anti_roll_force := clampf(
		compression_difference * ANTI_ROLL_STIFFNESS,
		-ANTI_ROLL_MAX_FORCE,
		ANTI_ROLL_MAX_FORCE
	)
	var body_up := global_transform.basis.y.normalized()
	apply_force(body_up * anti_roll_force, left_point - global_position)
	apply_force(-body_up * anti_roll_force, right_point - global_position)


func _apply_body_drag_and_stability() -> void:
	var planar_velocity := linear_velocity.slide(Vector3.UP)
	var planar_speed := planar_velocity.length()
	if planar_speed > 0.001:
		var drag_strength := (
			AERODYNAMIC_LINEAR_DRAG
			+ AERODYNAMIC_QUADRATIC_DRAG * planar_speed
		)
		apply_central_force(-planar_velocity * drag_strength)

	var body_right := global_transform.basis.x.normalized()
	var body_forward := global_transform.basis.z.normalized()
	var pitch_roll_damping := (
		GROUNDED_PITCH_ROLL_DAMPING
		if _grounded_wheel_count > 0
		else AIRBORNE_PITCH_ROLL_DAMPING
	)
	var damping_torque := (
		-body_right * angular_velocity.dot(body_right) * pitch_roll_damping
		-body_forward * angular_velocity.dot(body_forward) * pitch_roll_damping
	)
	var body_up := global_transform.basis.y.normalized()
	if _grounded_wheel_count > 0:
		damping_torque -= body_up * angular_velocity.dot(body_up) * GROUNDED_YAW_DAMPING
	else:
		damping_torque -= body_up * angular_velocity.dot(body_up) * AIRBORNE_YAW_DAMPING
	apply_torque(damping_torque)


func _setup_skid_marks() -> void:
	_skid_mark_mesh = ImmediateMesh.new()
	_skid_mark_material = StandardMaterial3D.new()
	_skid_mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_skid_mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_skid_mark_material.vertex_color_use_as_albedo = true
	_skid_mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_skid_mark_material.albedo_color = Color.WHITE

	var skid_marks := MeshInstance3D.new()
	skid_marks.name = "SkidMarks"
	skid_marks.mesh = _skid_mark_mesh
	skid_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skid_marks)
	skid_marks.top_level = true
	skid_marks.global_transform = Transform3D.IDENTITY


func _update_skid_marks() -> void:
	var added_segment := false
	for wheel_group: String in REAR_WHEELS:
		var point_value: Variant = _wheel_contact_point.get(wheel_group, null)
		var normal_value: Variant = _wheel_contact_normal.get(wheel_group, null)
		if point_value == null or normal_value == null:
			_last_skid_contact.erase(wheel_group)
			continue

		var longitudinal_speed := absf(float(_wheel_forward_speed.get(wheel_group, 0.0)))
		var lateral_speed := absf(float(_wheel_lateral_speed.get(wheel_group, 0.0)))
		var contact_speed := Vector2(longitudinal_speed, lateral_speed).length()
		var slip_angle := float(_wheel_slip_angle.get(wheel_group, 0.0))
		var is_laterally_slipping := (
			lateral_speed >= SKID_MARK_MIN_LATERAL_SPEED
			and slip_angle >= SKID_MARK_MIN_SLIP_ANGLE
		)
		var is_rear_locked := (
			_handbrake_amount >= SKID_MARK_MIN_HANDBRAKE
			and longitudinal_speed >= SKID_MARK_MIN_SPEED
		)
		if contact_speed < SKID_MARK_MIN_SPEED or not (is_laterally_slipping or is_rear_locked):
			_last_skid_contact.erase(wheel_group)
			continue

		var contact_point: Vector3 = point_value
		var contact_normal: Vector3 = normal_value
		var mark_point := contact_point + contact_normal * SKID_MARK_SURFACE_OFFSET
		var lateral_intensity := clampf(
			(lateral_speed - SKID_MARK_MIN_LATERAL_SPEED) / 1.25,
			0.0,
			1.0
		)
		var lock_intensity := _handbrake_amount if is_rear_locked else 0.0
		var intensity := maxf(lateral_intensity, lock_intensity)

		var previous_value: Variant = _last_skid_contact.get(wheel_group, null)
		if previous_value != null:
			var previous_contact: Dictionary = previous_value
			var previous_point: Vector3 = previous_contact["point"]
			var segment_length := previous_point.distance_to(mark_point)
			if (
				segment_length >= SKID_MARK_MIN_POINT_DISTANCE
				and segment_length <= SKID_MARK_MAX_SEGMENT_LENGTH
			):
				var previous_normal: Vector3 = previous_contact["normal"]
				_append_skid_mark_segment(
					previous_point,
					mark_point,
					(previous_normal + contact_normal).normalized(),
					intensity
				)
				added_segment = true
		_last_skid_contact[wheel_group] = {
			"point": mark_point,
			"normal": contact_normal,
		}

	if added_segment:
		_rebuild_skid_mark_mesh()


func _append_skid_mark_segment(
	start: Vector3,
	end: Vector3,
	normal: Vector3,
	intensity: float
) -> void:
	_skid_mark_segments.append({
		"start": start,
		"end": end,
		"normal": normal,
		"intensity": intensity,
	})
	while _skid_mark_segments.size() > MAX_SKID_MARK_SEGMENTS:
		_skid_mark_segments.pop_front()


func _rebuild_skid_mark_mesh() -> void:
	_skid_mark_mesh.clear_surfaces()
	if _skid_mark_segments.is_empty():
		return

	_skid_mark_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _skid_mark_material)
	for segment: Dictionary in _skid_mark_segments:
		var start: Vector3 = segment["start"]
		var end: Vector3 = segment["end"]
		var normal: Vector3 = segment["normal"]
		var direction := (end - start).slide(normal).normalized()
		if direction.length_squared() <= 0.0001:
			continue
		var side := normal.cross(direction).normalized() * SKID_MARK_WIDTH * 0.5
		var intensity := float(segment["intensity"])
		var color := Color(0.018, 0.018, 0.018, lerpf(0.4, 0.78, intensity))
		_add_skid_mark_triangle(
			start - side,
			end - side,
			end + side,
			normal,
			color,
			Vector2(0.0, 0.0),
			Vector2(0.0, 1.0),
			Vector2(1.0, 1.0)
		)
		_add_skid_mark_triangle(
			start - side,
			end + side,
			start + side,
			normal,
			color,
			Vector2(0.0, 0.0),
			Vector2(1.0, 1.0),
			Vector2(1.0, 0.0)
		)
	_skid_mark_mesh.surface_end()


func _add_skid_mark_triangle(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3,
	color: Color,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2
) -> void:
	_add_skid_mark_vertex(a, normal, color, uv_a)
	_add_skid_mark_vertex(b, normal, color, uv_b)
	_add_skid_mark_vertex(c, normal, color, uv_c)


func _add_skid_mark_vertex(
	position: Vector3,
	normal: Vector3,
	color: Color,
	uv: Vector2
) -> void:
	_skid_mark_mesh.surface_set_normal(normal)
	_skid_mark_mesh.surface_set_color(color)
	_skid_mark_mesh.surface_set_uv(uv)
	_skid_mark_mesh.surface_add_vertex(position)


func _velocity_at_world_point(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)


func _is_any_wheel_grounded() -> bool:
	return _grounded_wheel_count > 0


func _on_interaction_available(body: Node3D) -> void:
	if _powerup == "" and body.is_in_group("pickupable"):
		body.interact({"caller": self})


func _activate_powerup() -> void:
	if _powerup_scene_instance == null:
		return
	_powerup_scene_instance.interact({"caller": self})


func _sync_powerup_scene() -> void:
	_clear_powerup_scene()
	if _powerup == "":
		_powerup_scene_instance = null
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


func _sync_light_attack_cooldown_bar() -> void:
	if light_attack_cooldown_bar == null:
		return
	var ready_amount := 1.0
	if _light_attack_state != LightAttackState.READY:
		ready_amount = 0.0
	elif _light_attack_cooldown_remaining > 0.0:
		ready_amount = 1.0 - clampf(
			_light_attack_cooldown_remaining / LIGHT_ATTACK_COOLDOWN_DURATION,
			0.0,
			1.0
		)
	light_attack_cooldown_bar.value = lerpf(
		light_attack_cooldown_bar.min_value,
		light_attack_cooldown_bar.max_value,
		ready_amount
	)


func take_damage(amount: int, _source: Node = null) -> void:
	hitpoints -= maxi(amount, 0)


func _set_car_type(value: String) -> void:
	_car_type = value
	var car_group := "%s-car" % value
	_wheel_nodes.clear()
	_wheel_base_rotation.clear()
	_wheel_base_position.clear()
	_wheel_spin.clear()
	_visual_steering = _steering_angle

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
						_wheel_base_position[wheel_group] = wheel.position
						_wheel_spin[wheel_group] = 0.0
						break
		if node is CollisionShape3D:
			var is_body_collider := node.name.begins_with("Body Collider")
			node.disabled = not is_selected or not is_body_collider


func _cache_wheel_visual_offsets() -> void:
	for wheel_group: String in WHEEL_GROUPS:
		var wheel: Node3D = _wheel_nodes.get(wheel_group, null)
		var ray: RayCast3D = _wheel_rays.get(wheel_group, null)
		if wheel == null or ray == null:
			continue
		_wheel_visual_height_offset[wheel_group] = (
			wheel.position.y
			- (ray.position.y - SUSPENSION_REST_LENGTH)
		)


func _update_wheel_visuals(delta: float) -> void:
	for wheel_group: String in WHEEL_GROUPS:
		var wheel: Node3D = _wheel_nodes.get(wheel_group, null)
		if wheel == null:
			continue

		var forward_speed := float(_wheel_forward_speed.get(wheel_group, 0.0))
		var spin: float = _wheel_spin.get(wheel_group, 0.0)
		spin = wrapf(spin - forward_speed / WHEEL_RADIUS * delta, -PI, PI)
		_wheel_spin[wheel_group] = spin

		var base_rotation: Vector3 = _wheel_base_rotation.get(wheel_group, wheel.rotation)
		var steer_offset := _visual_steering if wheel_group in FRONT_WHEELS else 0.0
		wheel.rotation = Vector3(
			base_rotation.x + spin,
			base_rotation.y + steer_offset,
			base_rotation.z
		)

		var ray: RayCast3D = _wheel_rays.get(wheel_group, null)
		var base_position: Vector3 = _wheel_base_position.get(wheel_group, wheel.position)
		var suspension_length := float(_wheel_suspension_length.get(
			wheel_group,
			SUSPENSION_REST_LENGTH
		))
		var height_offset := float(_wheel_visual_height_offset.get(wheel_group, 0.0))
		if ray != null:
			base_position.y = ray.position.y - suspension_length + height_offset
		wheel.position = base_position


func _update_camera_transform() -> void:
	var flat_forward := global_transform.basis.z
	flat_forward.y = 0.0
	if flat_forward.length_squared() > 0.0001:
		flat_forward = flat_forward.normalized()
		var flat_right := Vector3.UP.cross(flat_forward).normalized()
		_camera_yaw_basis = Basis(flat_right, Vector3.UP, flat_forward)

	var camera_basis := _camera_yaw_basis * _camera_local_transform.basis
	var camera_position := global_position + _camera_yaw_basis * _camera_local_transform.origin
	camera.global_transform = Transform3D(camera_basis, camera_position)
