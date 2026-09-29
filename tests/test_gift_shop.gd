extends SceneTree
## Gift odds and the shop: the marble bag guarantees an outfit within 20 gifts, the prize is fixed
## before a box is picked, a miss is dressed up as a near miss, and buying spends the right currency.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	var profile: Node = root.get_node("Profile")
	profile.use_scratch_profile()
	# Marble bag: exactly one outfit in every 20 gifts.
	for bag_round in range(3):
		var outfits := 0
		for i in range(20):
			var prize: Dictionary = profile.roll_gift()
			profile.claim(prize)
			if prize["kind"] == "outfit":
				outfits += 1
		check(outfits == 1, "Bag %d: one outfit per 20 gifts, got %d" % [bag_round, outfits])
	check(profile.gems > 0 and profile.coins > 0, "Gifts also pay coins and diamonds.")
	# The gift scene decides before the pick and shows a near miss when the gift is not an outfit.
	profile.bag = ["coins"]
	var gift: Node = load("res://scenes/gift.tscn").instantiate()
	root.add_child(gift)
	await process_frame
	check(gift.prize["kind"] == "coins", "The prize is drawn when the boxes appear.")
	var coins_before: int = profile.coins
	check(gift.decoys.any(func(d: Dictionary) -> bool: return d["kind"] == "outfit"), "A missed outfit is shown in another box.")
	gift._on_box_input(_click(), 2)
	await create_timer(3.0).timeout
	check(gift.chosen == 2 and gift.continue_btn.visible, "Picking a box opens the gifts and offers to continue.")
	check(profile.coins == coins_before + gift.prize["amount"], "The gift is handed over once its box opens.")
	gift.queue_free()
	# Player levels pay diamonds and coins.
	profile.use_scratch_profile()
	var gained: Array = []
	profile.leveled_up.connect(func(level: int, c: int, g: int) -> void: gained.append([level, c, g]))
	profile.add_xp(profile.xp_needed() + profile.xp_needed(2) + 5)
	check(profile.player_level == 3 and profile.xp == 5, "XP carries over across level ups.")
	check(gained.size() == 2 and profile.gems == gained[0][2] + gained[1][2] and profile.coins == gained[0][1] + gained[1][1], "Each level up pays diamonds and coins.")
	# Shop.
	profile.use_scratch_profile()
	profile.coins = 1000
	profile.gems = 50
	check(profile.buy("hair", "bob") and profile.coins == 550, "Hairstyles cost coins.")
	check(profile.buy("outfit", "aodai") and profile.gems == 5, "Outfits cost diamonds.")
	check(not profile.buy("outfit", "princess"), "Cannot buy without enough diamonds.")
	profile.gems = 600
	check(profile.buy("wings", "phoenix") and profile.buy("pet", "dragon"), "Special wings and pets are sold for diamonds.")
	profile.equip("pet", "dragon")
	profile.equip("outfit", "aodai")
	profile.load_profile()
	check(profile.owns("outfit", "aodai") and profile.equipped["outfit"] == "aodai", "Purchases and equipment are saved.")
	var closet: Node = load("res://scenes/closet.tscn").instantiate()
	root.add_child(closet)
	await process_frame
	closet._show_kind("beam")
	closet._select("star")
	check(closet.action_btn.text.begins_with("Mua"), "Locked items offer a purchase.")
	closet.queue_free()
	for audio: Node in root.get_node("AudioManager").get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
	await create_timer(0.2).timeout
	print("GIFT_SHOP_RESULT " + JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e
