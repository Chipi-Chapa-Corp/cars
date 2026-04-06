extends RigidBase

@export var type: String = "bullet"

func _init():
	super (1000)

func do_interact(payload: Dictionary) -> void:
	var caller := payload.get("caller") as CharacterBody3D
	if caller == null:
		return

	if caller.powerup != "":
		return

	caller.powerup = type
	queue_free()