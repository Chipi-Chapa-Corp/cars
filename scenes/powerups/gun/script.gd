extends InteractableBase

const will_dispose: bool = true

func do_interact(_payload: Dictionary) -> void:
	queue_free()