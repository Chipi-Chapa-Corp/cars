extends Node3D

var _player_scene = preload("res://scenes/player/scene.tscn")
var _pickup_scene = preload("res://scenes/pickup/scene.tscn")

const WORLD_MIN = Vector3(-5, 0, -5)
const WORLD_MAX = Vector3(5, 0, 5)

@export var _player_container: Node3D
@export var _player_spawner_node: MultiplayerSpawner
@export var _pickup_spawner_node: MultiplayerSpawner
@export var _pickup_timer: Timer

@onready var _player_spawner = PlayerSpawner.new(_player_container, _player_scene, _player_spawner_node)


func _ready() -> void:
	_pickup_spawner_node.spawn_function = Callable(self , "_pickup_spawn_function")
	_player_spawner.run()
	if multiplayer.is_server():
		_pickup_timer.start()


func _on_spawn_pickup() -> void:
	var pickup_type = ["gun"].pick_random()
	var pickup_position = Vector3(randf_range(WORLD_MIN.x, WORLD_MAX.x), 0, randf_range(WORLD_MIN.z, WORLD_MAX.z))
	_pickup_spawner_node.spawn({"type": pickup_type, "position": pickup_position})


func _pickup_spawn_function(data: Dictionary):
	var pickup = _pickup_scene.instantiate()
	pickup.prepare(data)
	return pickup