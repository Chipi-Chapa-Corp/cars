extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/scene.tscn")

@export var _player_container: Node3D


func _ready() -> void:
	_player_container.add_child(PLAYER_SCENE.instantiate())
