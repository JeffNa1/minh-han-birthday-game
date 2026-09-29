extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Profile").use_scratch_profile()
	change_scene_to_file("res://scenes/game_world.tscn")
	await process_frame
	await process_frame
	var manager: Node = root.get_node("GameManager")
	manager.end_game()
	await create_timer(1.2).timeout
	if current_scene.title_label == null or current_scene.restart_btn == null:
		failures.append("Ending labels and buttons must resolve inside Panel.")
	else:
		current_scene.restart_btn.pressed.emit()
		await create_timer(4.0).timeout
		if not manager.game_active or current_scene.scene_file_path != "res://scenes/game_world.tscn":
			failures.append("Replay must start a new round.")
	manager.game_active = false
	for audio: Node in root.get_node("AudioManager").get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
	await create_timer(0.2).timeout
	print("ROUND_FLOW_RESULT " + JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
