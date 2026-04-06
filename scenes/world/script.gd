extends Node3D

var player_scene = preload("res://scenes/player/scene.tscn")

@export var player_container: Node3D
@export var player_spawner: MultiplayerSpawner

@onready var playerSpawner = Spawner.new(player_container, player_scene, player_spawner)


func _ready() -> void:
	playerSpawner.run()
