extends SceneTree
## Scripted play-through rendered on the GPU: menu, level intro, the three floors, rivals,
## the manager, a clash and the ending.

const OUT := "user://captures"

func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")

func shot(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + file_name)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func pointer(at: Vector2, pressed: int = -1) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	if pressed >= 0:
		var click := InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed == 1
		root.push_input(click, true)

func screen_of(n: Node2D) -> Vector2:
	return n.get_global_transform_with_canvas().origin

func boys_in(world: Node, id: String) -> Array:
	return world.zones[id].entities.get_children().filter(func(n: Node) -> bool: return n.is_in_group("boys"))

func _run() -> void:
	var gm: Node = root.get_node("GameManager")
	root.get_node("Profile").use_scratch_profile()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await wait(1.5)
	await shot("v2_menu.png")
	gm.new_game()
	gm.level = 2
	change_scene_to_file("res://scenes/game_world.tscn")
	await wait(0.6)
	await shot("v2_intro.png")
	await wait(2.0)
	var world := current_scene
	var player: Node2D = world.player
	# Walk right across the courtyard.
	pointer(Vector2(900, 420))
	await wait(2.2)
	await shot("v2_courtyard_walk.png")
	pointer(Vector2(480, 420))
	# Beam the nearest free boy.
	var boys := boys_in(world, "courtyard").filter(func(b: Node) -> bool: return b.lover == null)
	boys.sort_custom(func(a: Node2D, b: Node2D) -> bool: return absf(a.global_position.x - player.global_position.x) < absf(b.global_position.x - player.global_position.x))
	var target: Node2D = boys[0]
	target.global_position = player.global_position + Vector2(180, 10)
	target._pause = 20.0
	await wait(0.2)
	pointer(screen_of(target) + Vector2(0, -10), 1)
	await wait(1.0)
	await shot("v2_beam.png")
	await wait(1.8)
	pointer(screen_of(target), 0)
	for b: Node in boys.slice(1, 3):
		b.become_charmed()
		await wait(0.25)
	# Let a rival go for one of the free boys nearby.
	var rival: Node2D = world.zones["courtyard"].entities.get_children().filter(func(n: Node) -> bool: return n.is_in_group("rivals"))[0]
	var free: Array = boys_in(world, "courtyard").filter(func(b: Node) -> bool: return b.lover == null)
	if not free.is_empty():
		rival.global_position = player.global_position + Vector2(-260, 30)
		free[0].global_position = player.global_position + Vector2(-120, 40)
		free[0]._pause = 20.0
		rival.target = free[0]
		rival.state = rival.State.CHARMING
		rival._charm = 0.0
		rival._need = 1.2
	await wait(0.8)
	await shot("v2_rival_beam.png")
	await wait(1.5)
	await shot("v2_trail.png")
	# Up the stairs to the hallway, then the rooftop.
	world._enter_zone("hallway", 1500.0, 400.0)
	pointer(Vector2(420, 440))
	var manager: Array = world.zones["hallway"].entities.get_children().filter(func(n: Node) -> bool: return n.is_in_group("managers"))
	if not manager.is_empty():
		manager[0].global_position = player.global_position + Vector2(-260, -20)
		manager[0]._dir = 1.0
	await wait(1.5)
	await shot("v2_hallway.png")
	world._enter_zone("rooftop", 900.0, 400.0)
	pointer(Vector2(560, 430))
	await wait(1.5)
	await shot("v2_rooftop.png")
	var rivals: Array = world.zones["rooftop"].entities.get_children().filter(func(n: Node) -> bool: return n.is_in_group("rivals"))
	var mine: Array = gm.charmed_boys_chain
	if not rivals.is_empty() and not mine.is_empty():
		gm.start_clash(rivals[0], mine[0])
		await wait(0.6)
		await shot("v2_clash.png")
		world.get_node("ClashCanvas/ClashContest")._finish_clash(true)
	await wait(0.5)
	gm.change_hearts(20)
	await wait(1.2)
	await shot("v2_level_clear.png")
	await wait(3.5)
	await shot("v2_ending.png")
	quit()
