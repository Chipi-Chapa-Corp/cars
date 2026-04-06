extends Node

var scenes := {
	State.MENU: preload("res://scenes/main-menu/scene.tscn"),
	State.WORLD: preload("res://scenes/world/scene.tscn")
}

enum State { MENU, WORLD }

signal state_changed(from: State, to: State)

var epoch := 0
var state := State.MENU


func _ready():
	set_multiplayer_authority(1)


func change_state(to: State, broadcast: bool):
	if broadcast and multiplayer.is_server():
		epoch += 1
		broadcast_state_change.rpc(to, epoch)
	else:
		_do_change_state(to, epoch)


@rpc("authority", "call_local", "reliable")
func broadcast_state_change(to: State, send_epoch: int):
	_do_change_state(to, send_epoch)


func _do_change_state(to: State, send_epoch: int):
	if epoch > send_epoch:
		return
	epoch = send_epoch
	var from = state
	state = to
	state_changed.emit(from, state)
	get_tree().call_deferred("change_scene_to_packed", scenes[state])
