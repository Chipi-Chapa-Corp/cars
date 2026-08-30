class_name InteractableBase extends Node3D

var cooldown: Cooldown


func _init(cooldown_duration: float = 0.0):
	cooldown = Cooldown.new(cooldown_duration)


func do_interact(_payload: Dictionary) -> void:
	pass


func interact(payload: Dictionary = {}) -> void:
	if not cooldown.fire():
		return
	do_interact(payload)
