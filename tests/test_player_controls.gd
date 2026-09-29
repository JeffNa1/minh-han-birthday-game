extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("CONTROL_TEST: " + message)

func move_pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func click_pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func wait_ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	root.get_node("Profile").use_scratch_profile()
	root.size = Vector2i(960, 540)
	var manager: Node = root.get_node("GameManager")
	manager.game_active = true
	manager.time_left = 60.0
	var player: Node2D = load("res://scenes/entities/player.tscn").instantiate()
	player.position = Vector2(200, 430)
	root.add_child(player)
	await process_frame
	move_pointer(Vector2(700, 430))
	await wait_ticks(12)
	check(player.position.x > 205.0, "Mouse motion must move Minh Han right.")
	check(player.get_node("Rig").motion == "walk", "Player movement must drive the articulated walk cycle.")
	move_pointer(player.position)
	await wait_ticks(30)
	check(player.get_node("Rig").motion == "idle", "Stopping at the pointer must return to articulated idle.")
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	root.push_input(key, true)
	await process_frame
	check(player.get_node("Rig").outfit == "pajamas", "Key 2 must switch the real in-game outfit.")
	var boy: Node2D = load("res://scenes/entities/boy.tscn").instantiate()
	boy.position = Vector2(650, 430)
	root.add_child(boy)
	boy.set_physics_process(false)
	await process_frame
	move_pointer(boy.position)
	click_pointer(boy.position, true)
	await wait_ticks(4)
	var beam: Node2D = player.get_node("LoveBeam")
	check(beam.is_active, "Holding the mouse on an NPC must activate the beam.")
	if beam.is_active:
		var eye: Marker2D = player.get_node("Rig").eye
		check(beam.start_point.distance_to(eye.global_position) < 2.0, "Rendered beam must start at the moving eye, not an offset world point.")
		check(player.get_node("Rig").motion == "beam", "Beaming must pose the articulated body.")
	click_pointer(boy.position, false)
	await wait_ticks(2)
	check(not beam.is_active, "Releasing the mouse must stop the beam.")
	manager.game_active = false
	for audio: Node in root.get_node("AudioManager").get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
	await create_timer(0.15).timeout
	player.queue_free()
	boy.queue_free()
	await process_frame
	print("CONTROL_TEST_RESULT " + JSON.stringify({"failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
