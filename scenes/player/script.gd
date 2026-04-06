extends CharacterBody3D

@export var name_label: Label3D
@export var camera: Camera3D

const SPEED := 2.0
const JUMP_VELOCITY := 2.5

var player_id: int = -1
var _is_local := false


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

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if dir != Vector3.ZERO:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()


func _on_interaction_available(body: Node3D) -> void:
	if not _is_local:
		return

	if body.is_in_group("interactable"):
		body.interact({})
