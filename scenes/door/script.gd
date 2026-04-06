extends InteractableBase

var _target_rotation_y := 0.0
@export var target_rotation_y: float:
	set(value):
		if is_equal_approx(_target_rotation_y, value):
			return
		_target_rotation_y = value
		if not is_node_ready():
			return
		_animate_to_rotation(_target_rotation_y)
	get:
		return _target_rotation_y

var _rotation_tween: Tween

const CLOSED_Y_ROTATION := 0.0
const OPEN_Y_ROTATION := 90.0
const ROTATION_DURATION := 0.2


func _enter_tree() -> void:
	set_multiplayer_authority(1)


func _ready() -> void:
	rotation_degrees.y = target_rotation_y


func do_interact(_payload: Dictionary) -> void:
	if not is_multiplayer_authority():
		return

	if not cooldown.fire():
		return

	target_rotation_y = OPEN_Y_ROTATION if is_equal_approx(target_rotation_y, CLOSED_Y_ROTATION) else CLOSED_Y_ROTATION


func _animate_to_rotation(target_rotation: float) -> void:
	if _rotation_tween:
		_rotation_tween.kill()

	_rotation_tween = create_tween()
	_rotation_tween.tween_property(self, "rotation_degrees:y", target_rotation, ROTATION_DURATION)