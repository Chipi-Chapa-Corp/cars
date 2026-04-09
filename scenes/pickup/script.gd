extends InteractableBase

@export var _type: String = "gun"
@export var _animation_player: AnimationPlayer
@export var _visual_slot: Node3D
@export var _mesh_by_type: Dictionary[String, Mesh] = {}

var _visual_instance: MeshInstance3D

func _init():
	super (1000)

func prepare(data: Dictionary) -> void:
	_type = data.get("type")
	position = data.get("position")

func _ready() -> void:
	_sync_visual()
	_animation_player.play("spin")

func _sync_visual() -> void:
	var mesh := _mesh_by_type.get(_type) as Mesh

	_visual_instance = MeshInstance3D.new()
	_visual_instance.mesh = mesh
	_visual_slot.add_child(_visual_instance)

func do_interact(payload: Dictionary) -> void:
	var caller: Node3D = payload.get("caller")
	caller.set("powerup", _type)
	queue_free()