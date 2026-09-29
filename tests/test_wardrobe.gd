extends SceneTree
## Minh Han starts with only the heart pyjamas; the dock and keys 1-9 offer exactly what she owns.

const Catalog := preload("res://scripts/data/catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	var profile: Node = root.get_node("Profile")
	profile.use_scratch_profile()
	check(profile.owned["outfit"] == ["pajamas"] and profile.equipped["outfit"] == "pajamas", "A new profile owns only the heart pyjamas.")
	check(Catalog.ids("outfit").size() == 39, "Minh Han has thirty-nine outfits in total.")
	check(Catalog.ids("outfit").filter(func(id: String) -> bool: return Catalog.is_special("outfit", id)).size() == 5, "Five full-set gowns.")
	for kind: String in ["hat", "wings", "aura", "pet"]:
		check(profile.equipped[kind] == "none", "New players wear no %s." % kind)
		check(Catalog.ids(kind).any(func(id: String) -> bool: return Catalog.is_special(kind, id)), "Every gear kind has special pieces: " + kind)
	profile.set_look("skin", "tan")
	profile.set_look("hair_color", "pink")
	profile.load_profile()
	check(profile.look() == {"hair": "long", "hair_color": "pink", "skin": "tan"}, "Hair colour and skin tone are saved.")
	check(Catalog.ids("hair").size() >= 8 and Catalog.ids("beam").size() >= 7, "Hairstyles and beams are customisable.")
	for id: String in Catalog.ids("outfit"):
		check(id == "pajamas" or not Catalog.price("outfit", id).is_empty(), "Every outfit can be bought: " + id)
	profile.grant("outfit", "aodai")
	profile.grant("outfit", "princess")
	var world: Node = load("res://scenes/game_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: Node = get_first_node_in_group("player")
	var hud: Node = world.get_node("HUD")
	check(hud.buttons.size() == 3, "The dock shows only owned outfits.")
	check(hud.buttons["pajamas"].button_pressed, "The dock shows the worn outfit at startup.")
	player.change_outfit("gala")
	check(player.rig.outfit == "pajamas", "Unowned outfits cannot be worn.")
	var ids: Array = profile.owned["outfit"]
	for i in range(ids.size()):
		var key := InputEventKey.new()
		key.keycode = KEY_1 + i
		key.pressed = true
		player._unhandled_input(key)
		check(player.rig.outfit == ids[i], "Key %d must select %s" % [i + 1, ids[i]])
		check(hud.buttons[ids[i]].button_pressed, "Dock must follow keyboard change to " + ids[i])
	check(profile.equipped["outfit"] == ids.back(), "Changing clothes in play is saved.")
	root.get_node("GameManager").game_active = false
	for audio: Node in root.get_node("AudioManager").get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
	await create_timer(0.15).timeout
	world.queue_free()
	await process_frame
	print("WARDROBE_RESULT " + JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
