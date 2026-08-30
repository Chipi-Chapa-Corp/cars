extends Control


func _on_play_pressed() -> void:
	SceneManager.change_state(SceneManager.State.WORLD)
