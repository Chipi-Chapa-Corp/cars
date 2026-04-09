extends RefCounted
class_name PlayerSpawner

var target_container: Node3D
var target_scene: PackedScene
var spawner: MultiplayerSpawner
var multiplayer: MultiplayerAPI

var spawned := []


func _init(
	spawn_container: Node3D, spawn_scene: PackedScene, spawn_spawner: MultiplayerSpawner
) -> void:
	target_container = spawn_container
	target_scene = spawn_scene
	spawner = spawn_spawner
	multiplayer = spawner.get_tree().get_multiplayer()


func run():
	spawner.spawn_function = Callable(self , "_spawn_function")

	if multiplayer.is_server():
		_spawn_for_peer(1)
		for peer_id in multiplayer.get_peers():
			_spawn_for_peer(peer_id)

		NetworkManager.player_joined.connect(_on_player_joined)
		NetworkManager.player_left.connect(_on_player_left)


func _on_player_joined(peer_id: int):
	if !multiplayer.is_server():
		return
	_spawn_for_peer(peer_id)


func _on_player_left(peer_id: int):
	if !multiplayer.is_server():
		return
	var player_node := target_container.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
	spawned.erase(peer_id)


func _spawn_for_peer(peer_id: int):
	if spawned.has(peer_id):
		return
	spawned.append(peer_id)
	spawner.spawn({"peer_id": peer_id})


func _spawn_function(data: Dictionary):
	var entity = target_scene.instantiate()
	entity.prepare(data)
	return entity
