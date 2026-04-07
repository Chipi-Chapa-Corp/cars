extends RigidBase

@export var type: String = "bullet"

func _init():
	super (1000)

func do_interact(payload: Dictionary) -> void:
	var caller: Node3D = payload.get("caller")
	caller.set("powerup", type)
	queue_free()