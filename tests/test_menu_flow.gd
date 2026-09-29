extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Profile").use_scratch_profile()
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	if not "MINH HÂN" in menu.get_node("TitleBox/Title").text:
		failures.append("Menu must identify Minh Han and label the playable draft honestly.")
	if menu.get_node_or_null("PlayerRig") == null:
		failures.append("Menu must use the playable character, not the obsolete static placeholder.")
	menu.get_node("MenuBox/GuideBtn").pressed.emit()
	if not menu.get_node("GuidePanel").visible:
		failures.append("Guide must open.")
	menu.get_node("GuidePanel/Box/CloseGuideBtn").pressed.emit()
	if menu.get_node("GuidePanel").visible:
		failures.append("Guide must close.")
	menu.get_node("MenuBox/StartBtn").pressed.emit()
	await create_timer(1.2).timeout
	if current_scene == null or current_scene.scene_file_path != "res://scenes/game_world.tscn":
		failures.append("Start must load the real game world.")
	root.get_node("GameManager").game_active = false
	for audio: Node in root.get_node("AudioManager").get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
	await create_timer(0.15).timeout
	current_scene.queue_free()
	await process_frame
	print("MENU_FLOW_RESULT " + JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
