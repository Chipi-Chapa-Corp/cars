extends RigidBase

@export var type: String = "bullet"

func _init():
	super (1000)

func do_interact(payload: Dictionary) -> void:
	var caller_value: Variant = payload.get("caller")
	if caller_value == null or not (caller_value is Node3D):
		return
	var caller: Node3D = caller_value

	var active_powerup: Variant = caller.get("powerup")
	if active_powerup != null and String(active_powerup) != "":
		return

	caller.set("powerup", type)
	queue_free()