extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/scene.tscn")
const PICKUP_SCENE := preload("res://scenes/pickup/scene.tscn")

const WORLD_MIN = Vector3(-5, 0, -5)
const WORLD_MAX = Vector3(5, 0, 5)

@export var _player_container: Node3D
@export var _pickup_container: Node3D
@export var _pickup_timer: Timer


func _ready() -> void:
	_player_container.add_child(PLAYER_SCENE.instantiate())
	_pickup_timer.start()


func _on_spawn_pickup() -> void:
	var pickup = PICKUP_SCENE.instantiate()
	pickup.prepare(
		{
			"type": ["gun"].pick_random(),
			"position": Vector3(
				randf_range(WORLD_MIN.x, WORLD_MAX.x),
				0,
				randf_range(WORLD_MIN.z, WORLD_MAX.z)
			)
		}
	)
	_pickup_container.add_child(pickup)
