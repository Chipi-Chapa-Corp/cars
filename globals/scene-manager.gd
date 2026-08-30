extends Node

var scenes: Dictionary = {
	State.MENU: preload("res://scenes/main-menu/scene.tscn"),
	State.WORLD: preload("res://scenes/world/scene.tscn")
}

enum State { MENU, WORLD }

signal state_changed(from: State, to: State)

var state := State.MENU


func change_state(to: State) -> void:
	if to == state:
		return
	var from := state
	state = to
	state_changed.emit(from, state)
	get_tree().call_deferred("change_scene_to_packed", scenes[state])
