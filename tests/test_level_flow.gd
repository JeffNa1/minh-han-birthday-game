extends SceneTree
## Level rules end to end: cast per level, staircases carry Minh Hân and her floating boys,
## rivals steal followers, the manager catches flirting, and a full meter advances the level.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("LEVEL_TEST: " + message)

func count(zone: Node, group: String) -> int:
	return zone.entities.get_children().filter(func(n: Node) -> bool: return n.is_in_group(group)).size()

func _run() -> void:
	root.get_node("Profile").use_scratch_profile()
	var gm: Node = root.get_node("GameManager")
	gm.new_game()
	change_scene_to_file("res://scenes/game_world.tscn")
	await create_timer(2.8).timeout
	var world: Node = current_scene
	var player: Node2D = world.player
	check(gm.game_active, "Play must start after the level intro.")
	check(world.zones.size() == 3, "The map needs courtyard, hallway and rooftop.")
	check(world.zone.id == "courtyard" and player.get_parent() == world.zone.entities, "Minh Han starts in the courtyard.")
	check(count(world.zones["courtyard"], "rivals") == 1 and count(world.zones["hallway"], "managers") == 1, "Level 1 places one rival and one manager.")
	check(count(world.zones["courtyard"], "boys") + count(world.zones["hallway"], "boys") + count(world.zones["rooftop"], "boys") >= 9, "Level 1 spreads nine boys over the zones.")
	# Charm a boy: +1 heart and he floats behind her.
	var boy: Node2D = world.zones["courtyard"].entities.get_children().filter(func(n: Node) -> bool: return n.is_in_group("boys"))[0]
	boy.tier = 1
	boy.become_charmed()
	await create_timer(0.3).timeout
	check(gm.hearts == 4 and boy.is_player_boy(), "Charming must add a heart and make him Minh Han's.")
	check(boy.z_index < 0, "Minh Han's boys float behind the cast.")
	# Walk into the staircase.
	player.global_position = Vector2(2175, 400)
	await create_timer(1.4).timeout
	check(world.zone.id == "hallway", "The courtyard staircase must lead to the hallway.")
	check(player.get_parent() == world.zones["hallway"].entities, "Minh Han must move into the hallway.")
	check(boy.get_parent() == world.zones["hallway"].entities, "Her floating boys follow her upstairs.")
	check(not world.zones["courtyard"].visible, "Only the current zone is shown.")
	# A rival steals him.
	var rival: Node2D = world.zones["courtyard"].entities.get_children().filter(func(n: Node) -> bool: return n.is_in_group("rivals"))[0]
	boy.set_lover(rival)
	check(gm.hearts == 3 and boy not in gm.charmed_boys_chain and boy in rival.followers, "A stolen follower costs a heart and joins the rival.")
	# The manager catches her flirting in plain sight.
	var manager: Node2D = world.zones["hallway"].entities.get_children().filter(func(n: Node) -> bool: return n.is_in_group("managers"))[0]
	manager.global_position = player.global_position - Vector2(120, 0)
	manager.rig.set_facing(1.0)
	manager._dir = 1.0
	manager._pause = 0.0
	manager._cooldown = 0.0
	manager.state = manager.State.PATROL
	player.state = player.State.BEAMING
	manager._physics_process(0.016)
	check(player.state == player.State.STUNNED and gm.hearts == 1, "Being caught flirting stuns Minh Han and costs two hearts.")
	# Fill the meter: the level is won, coins are paid and the gift boxes follow.
	var coins_before: int = root.get_node("Profile").coins
	gm.change_hearts(20)
	check(not gm.game_active, "A full love meter ends the level.")
	await create_timer(4.0).timeout
	check(gm.level == 1 and root.get_node("Profile").best_level == 1, "Winning unlocks level 2.")
	check(root.get_node("Profile").coins > coins_before, "Winning pays coins.")
	check(current_scene.scene_file_path == "res://scenes/gift.tscn", "A won level leads to the gift boxes.")
	current_scene._on_continue()
	await create_timer(3.8).timeout
	world = current_scene
	check(gm.level == 1 and world.scene_file_path == "res://scenes/game_world.tscn", "Level 2 starts after the gifts.")
	check(gm.hearts == 3 and gm.game_active, "Level 2 starts fresh with three hearts.")
	gm.game_active = false
	for audio: Node in root.get_node("AudioManager").get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
	await create_timer(0.2).timeout
	print("LEVEL_FLOW_RESULT " + JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
