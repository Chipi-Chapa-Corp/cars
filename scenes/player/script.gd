extends RigidBody3D

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

@export var healthbar: TextureProgressBar
@export var powerup_slot: Node3D
@export var hud_sprite_3d: Sprite3D
@export var hud_viewport: SubViewport
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
	if hud_sprite_3d != null and hud_viewport != null:
		hud_sprite_3d.texture = hud_viewport.get_texture()
	car_type = CAR_TYPES.pick_random()
	_cache_wheel_visual_offsets()
	_setup_skid_marks()
	_camera_local_transform = camera.transform
	camera.top_level = true
	_update_camera_transform()
	camera.current = true
	_sync_powerup_scene()
	_sync_healthbar()


func _process(_delta: float) -> void:
	_update_camera_transform()


func _physics_process(delta: float) -> void:
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

	if Input.is_action_just_pressed("activate"):
		_activate_powerup()


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
