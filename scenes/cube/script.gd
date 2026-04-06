extends RigidBase

func _init():
	super (1000)

func do_interact(payload: Dictionary) -> void:
	print("Interacting with cube", payload)
	if cooldown.fire():
		if multiplayer.is_server():
			position.y += 5