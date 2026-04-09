extends InteractableBase

const will_dispose: bool = true

func do_interact(payload: Dictionary) -> void:
	payload.get("caller").set("powerup", "")
	queue_free()
