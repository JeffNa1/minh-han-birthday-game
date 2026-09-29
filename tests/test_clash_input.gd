extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Profile").use_scratch_profile()
	var clash: Control = load("res://scenes/ui/clash_contest.tscn").instantiate()
	root.add_child(clash)
	await process_frame
	clash.set_process(false)
	clash._on_clash_requested(null, null)
	clash._process(0.0)
	if absf(clash.pointer_x) > 0.01:
		failures.append("The zero-value pointer must sit at the center of the drawn bar.")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = clash.get_global_rect().get_center()
	root.push_input(event)
	if clash.current_val != 14.0:
		failures.append("The visible clash overlay must not swallow the player's click.")
	event.pressed = false
	root.push_input(event)
	clash.is_active = false
	for audio: Node in root.get_node("AudioManager").get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
	await create_timer(0.2).timeout
	clash.queue_free()
	await process_frame
	print("CLASH_INPUT_RESULT " + JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
