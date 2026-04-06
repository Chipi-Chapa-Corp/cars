extends Node

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)

var peer: ENetMultiplayerPeer
var _backend: Node
var _is_dev_mode := false


func _ready():
	_setup_backend()

	var mp = get_tree().get_multiplayer()
	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(id: int):
	player_joined.emit(id)


func _on_peer_disconnected(id: int):
	player_left.emit(id)


func is_host() -> bool:
	return get_tree().get_multiplayer().is_server()


func create_lobby() -> void:
	_backend.call("create_lobby")


func join_lobby(lobby_id: int) -> void:
	_backend.call("join_lobby", lobby_id)


func leave_lobby() -> void:
	_backend.call("leave_lobby")


func refresh_lobby_list() -> void:
	_backend.call("refresh_lobby_list")


func is_ready() -> bool:
	return _backend.call("is_ready")


func _setup_backend() -> void:
	_is_dev_mode = OS.get_cmdline_args().has("--dev")
	_backend = LocalBackend.new() if _is_dev_mode else SteamBackend.new()

	_backend.lobby_created.connect(_on_backend_lobby_created)
	_backend.lobby_joined.connect(_on_backend_lobby_joined)
	_backend.lobby_match_list_updated.connect(_on_backend_lobby_match_list_updated)

	add_child(_backend)


func _on_backend_lobby_created(error) -> void:
	lobby_created.emit(error)


func _on_backend_lobby_joined(error) -> void:
	lobby_joined.emit(error)


func _on_backend_lobby_match_list_updated(lobbies: Array) -> void:
	lobby_match_list_updated.emit(lobbies)
