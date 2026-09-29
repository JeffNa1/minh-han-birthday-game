extends SceneTree
## Renders the menu, closet/shop and gift boxes on the GPU for visual review (scratch profile).

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

func _run() -> void:
	var profile: Node = root.get_node("Profile")
	profile.use_scratch_profile()
	profile.coins = 1350
	profile.gems = 48
	profile.grant("outfit", "gown_sakura")
	profile.grant("pet", "bunny")
	profile.grant("wings", "angel")
	profile.equip("outfit", "gown_sakura")
	profile.equip("pet", "bunny")
	profile.add_xp(150)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await wait(1.4)
	await shot("v3_menu.png")
	change_scene_to_file("res://scenes/closet.tscn")
	await wait(0.8)
	current_scene._select("princess")
	current_scene.get_node("Panel/Box/Scroll").scroll_vertical = 1400
	await wait(0.6)
	await shot("v3_closet_outfits.png")
	current_scene._show_kind("look")
	current_scene._pick_look("hair_color", "caramel")
	current_scene._pick_look("skin", "honey")
	await wait(0.5)
	await shot("v3_closet_look.png")
	current_scene._show_kind("wings")
	current_scene._select("galaxy")
	await wait(0.6)
	await shot("v3_closet_wings.png")
	current_scene._show_kind("pet")
	current_scene._select("dragon")
	await wait(0.6)
	await shot("v3_closet_pets.png")
	current_scene._show_kind("beam")
	current_scene._select("rainbow")
	await wait(0.8)
	await shot("v3_closet_beams.png")
	profile.equip("outfit", "pajamas")
	profile.equip("wings", "angel")
	root.get_node("GameManager").new_game()
	root.get_node("GameManager").level = 6
	change_scene_to_file("res://scenes/game_world.tscn")
	await wait(3.0)
	await shot("v3_play_level7.png")
	var w := current_scene
	w._enter_zone("hallway", 900.0, 400.0)
	await wait(1.5)
	await shot("v3_play_hallway.png")
	root.get_node("GameManager").game_active = false
	root.get_node("GameManager").level = 1
	root.get_node("GameManager").last_reward = 70
	profile.bag = ["gems"]
	change_scene_to_file("res://scenes/gift.tscn")
	await wait(0.8)
	await shot("v3_gift_pick.png")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	current_scene._on_box_input(click, 1)
	await wait(3.2)
	await shot("v3_gift_open.png")
	quit()
