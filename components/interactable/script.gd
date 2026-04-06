class_name InteractableBase extends Node3D

var cooldown: Cooldown


func _init(cooldown_duration: float = 0.0):
	cooldown = Cooldown.new(cooldown_duration)


func do_interact(_payload: Dictionary) -> void:
	pass


func interact(payload: Dictionary = {}) -> void:
	rpc_id(1, "_interact_request", payload)


@rpc("any_peer", "call_local", "reliable")
func _interact_request(payload: Dictionary = {}) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	var caller := _resolve_sender_node(sender_id)
	var authoritative_payload := _build_authoritative_payload(payload, sender_id, caller)
	rpc("_execute_interaction", authoritative_payload)


@rpc("authority", "call_local", "reliable")
func _execute_interaction(payload: Dictionary) -> void:
	do_interact(payload)


func _build_authoritative_payload(payload: Dictionary, sender_id: int, caller: Node3D) -> Dictionary:
	var out := payload.duplicate(true)
	out["peer_id"] = sender_id
	out["caller"] = caller
	return out


func _resolve_sender_node(sender_id: int) -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	var index = players.find_custom(func(node): return node.player_id == sender_id)
	return null if index == -1 else players[index]
