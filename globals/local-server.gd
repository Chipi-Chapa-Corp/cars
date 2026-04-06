extends Node
class_name LocalBackend

var _ready_ok: bool = false
var current_lobby_id: int = 0

const PACKET_READ_LIMIT: int = 32
const MAX_MEMBERS: int = 10
const SERVER_PORT: int = 2456
const DEFAULT_HOST: String = "127.0.0.1"
const JOIN_RESPONSE_SUCCESS: int = 1
const DEVELOPMENT_LOBBY_ID: int = 1
const DEVELOPMENT_LOBBY_NAME: String = "Development Lobby"

signal lobby_created(error)
signal lobby_joined(error)
signal lobby_match_list_updated(lobbies: Array)

var _peer: ENetMultiplayerPeer
var _known_lobbies: Dictionary = {}
var _pending_join_lobby_id: int = 0


func is_ready() -> bool:
	return _ready_ok


func join_lobby(_lobby_id: int) -> void:
	leave_lobby()

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(DEFAULT_HOST, SERVER_PORT)
	if err != OK:
		_on_lobby_joined(DEVELOPMENT_LOBBY_ID, 0, false, err)
		return

	_pending_join_lobby_id = DEVELOPMENT_LOBBY_ID
	get_tree().get_multiplayer().multiplayer_peer = _peer


func leave_lobby() -> void:
	if _peer:
		_peer.close()
		_peer = null

	get_tree().get_multiplayer().multiplayer_peer = null
	current_lobby_id = 0


func create_lobby() -> void:
	leave_lobby()

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(SERVER_PORT, MAX_MEMBERS)
	if err != OK:
		_on_lobby_created(err, 0)
		return

	get_tree().get_multiplayer().multiplayer_peer = _peer

	_known_lobbies[DEVELOPMENT_LOBBY_ID] = {
		"id": DEVELOPMENT_LOBBY_ID,
		"name": DEVELOPMENT_LOBBY_NAME,
		"state": "waiting",
		"num_members": 1,
		"host": DEFAULT_HOST,
		"port": SERVER_PORT
	}
	_on_lobby_created(JOIN_RESPONSE_SUCCESS, DEVELOPMENT_LOBBY_ID)


func refresh_lobby_list() -> void:
	var state := "unknown"
	var num_members := 0
	var mp := get_tree().get_multiplayer()

	if mp.multiplayer_peer:
		if mp.is_server():
			state = "waiting"
			num_members = 1 + mp.get_peers().size()
		else:
			state = "in_game"
			num_members = 1

	_known_lobbies[DEVELOPMENT_LOBBY_ID] = {
		"id": DEVELOPMENT_LOBBY_ID,
		"name": DEVELOPMENT_LOBBY_NAME,
		"state": state,
		"num_members": num_members,
		"host": DEFAULT_HOST,
		"port": SERVER_PORT
	}

	_on_lobby_match_list([DEVELOPMENT_LOBBY_ID])


func _ready() -> void:
	_listen()
	_check_command_line()
	_ready_ok = true


func _process(_delta: float) -> void:
	pass


func _listen():
	var mp := get_tree().get_multiplayer()
	if not mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.connect(_on_connected_to_server)
	if not mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.connect(_on_connection_failed)
	if not mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.connect(_on_server_disconnected)


func _check_command_line() -> void:
	var args := OS.get_cmdline_args()
	if args.size() > 1:
		if args[0] == "+connect_lobby":
			if int(args[1]) > 0:
				print_debug("Command line lobby ID: %s" % args[1])
				join_lobby(int(args[1]))


func _on_lobby_created(lobby_connect: int, lobby_id: int) -> void:
	if lobby_connect != JOIN_RESPONSE_SUCCESS:
		lobby_created.emit("Failed to create lobby: " + error_string(lobby_connect))
		return

	current_lobby_id = lobby_id
	var lobby = _known_lobbies.get(lobby_id, {})
	lobby["state"] = "waiting"
	_known_lobbies[lobby_id] = lobby

	lobby_created.emit(null)


func _on_lobby_match_list(lobby_ids: Array) -> void:
	var list = lobby_ids.map(
		func(lobby_id: int):
			var lobby = _known_lobbies.get(lobby_id, {})
			var lobby_name := str(lobby.get("name", "LAN Lobby"))
			var lobby_state := str(lobby.get("state", "unknown"))
			var lobby_num_members := int(lobby.get("num_members", 0))
			return {
				"id": lobby_id,
				"name": lobby_name,
				"state": lobby_state,
				"num_members": lobby_num_members
			}
	)
	lobby_match_list_updated.emit(list)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == JOIN_RESPONSE_SUCCESS:
		current_lobby_id = lobby_id
		lobby_joined.emit(null)
	else:
		push_error("Failed to join lobby: %s" % error_string(response))
		var fail_reason := "Failed to connect to host."
		if response == ERR_CANT_CONNECT:
			fail_reason = "Could not reach the host."
		elif response == ERR_TIMEOUT:
			fail_reason = "Timed out while connecting."

		refresh_lobby_list()
		lobby_joined.emit(fail_reason)


func _on_connected_to_server() -> void:
	var lobby_id := _pending_join_lobby_id
	if lobby_id == 0:
		lobby_id = DEVELOPMENT_LOBBY_ID
	_pending_join_lobby_id = 0
	_on_lobby_joined(lobby_id, 0, false, JOIN_RESPONSE_SUCCESS)


func _on_connection_failed() -> void:
	var lobby_id := _pending_join_lobby_id
	if lobby_id == 0:
		lobby_id = DEVELOPMENT_LOBBY_ID
	_pending_join_lobby_id = 0
	_on_lobby_joined(lobby_id, 0, false, ERR_CANT_CONNECT)


func _on_server_disconnected() -> void:
	current_lobby_id = 0
