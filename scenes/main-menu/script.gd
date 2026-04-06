extends Control

@export var world_scene: PackedScene
@export var lobbies: VBoxContainer
@export var refresh_timer: Timer


func _ready() -> void:
	NetworkManager.lobby_match_list_updated.connect(_set_rooms)
	refresh_timer.timeout.connect(func(): NetworkManager.refresh_lobby_list())


func _on_host_pressed() -> void:
	NetworkManager.create_lobby()
	SceneManager.change_state(SceneManager.State.WORLD, false)


func _on_join_room_pressed(room) -> void:
	NetworkManager.join_lobby(room["id"])
	SceneManager.change_state(SceneManager.State.WORLD, false)


func _set_rooms(rooms: Array) -> void:
	var no_rooms := len(rooms) == 0
	if no_rooms:
		return

	for child in lobbies.get_children():
		lobbies.remove_child(child)

	for room in rooms:
		var button = Button.new()
		button.text = "%s (%s)" % [room.name, room.num_members]
		button.pressed.connect(func(): _on_join_room_pressed(room))
		lobbies.add_child(button)
