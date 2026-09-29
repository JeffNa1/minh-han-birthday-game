extends Node
## Saved progress: coins, diamonds, owned and equipped items, the furthest level reached,
## player XP and level, and the gift marble bag. Stored as JSON in user://.
##
## Gift odds use a marble bag: 20 marbles hold 1 outfit, 2 accessory (hair, beam, hat, wings,
## aura or pet), 4 diamond and 13 coin marbles. A draw removes a marble, so an outfit is 5% per
## gift but guaranteed within 20. Within a marble, cheaper items are likelier than showpieces.

signal changed
signal leveled_up(level: int, coins: int, gems: int)

const Catalog := preload("res://scripts/data/catalog.gd")
const Wardrobe := preload("res://scripts/art/wardrobe.gd")
const BAG := {"outfit": 1, "accessory": 2, "gems": 4, "coins": 13}
const ACCESSORY_KINDS := ["hair", "beam", "hat", "wings", "aura", "pet"]

var path: String = "user://profile.json"
var coins: int = 0
var gems: int = 0
var owned: Dictionary = {}
var equipped: Dictionary = {}
var best_level: int = 0
var bag: Array = []
var player_level: int = 1
var xp: int = 0
## Free cosmetic choices (ids in Wardrobe.HAIR_COLORS and Wardrobe.SKINS).
var look_choice: Dictionary = {"hair_color": "black", "skin": "fair"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()

func _fresh() -> void:
	coins = 0
	gems = 0
	best_level = 0
	bag = []
	player_level = 1
	xp = 0
	owned = {}
	equipped = {}
	look_choice = {"hair_color": "black", "skin": "fair"}
	for kind: String in Catalog.KINDS:
		owned[kind] = [Catalog.DEFAULTS[kind]]
		equipped[kind] = Catalog.DEFAULTS[kind]

func load_profile() -> void:
	_fresh()
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	coins = int(data.get("coins", 0))
	gems = int(data.get("gems", 0))
	best_level = int(data.get("best_level", 0))
	player_level = maxi(1, int(data.get("player_level", 1)))
	xp = int(data.get("xp", 0))
	bag = data.get("bag", []).filter(func(m: String) -> bool: return BAG.has(m))
	var saved_look: Dictionary = data.get("look", {})
	if Wardrobe.HAIR_COLORS.has(saved_look.get("hair_color", "")):
		look_choice["hair_color"] = saved_look["hair_color"]
	if Wardrobe.SKINS.has(saved_look.get("skin", "")):
		look_choice["skin"] = saved_look["skin"]
	for kind: String in Catalog.KINDS:
		var have: Array = data.get("owned", {}).get(kind, [])
		for id: String in have:
			if id in Catalog.ids(kind) and id not in owned[kind]:
				owned[kind].append(id)
		var worn: String = data.get("equipped", {}).get(kind, "")
		if worn in owned[kind]:
			equipped[kind] = worn

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"coins": coins, "gems": gems, "best_level": best_level, "bag": bag, "owned": owned, "equipped": equipped, "look": look_choice, "player_level": player_level, "xp": xp}))
	changed.emit()

## Tests play on a throwaway profile so they never touch the real save.
func use_scratch_profile() -> void:
	path = "user://profile_test.json"
	_fresh()
	save()

func owns(kind: String, id: String) -> bool:
	return id in owned[kind]

func grant(kind: String, id: String) -> void:
	if not owns(kind, id):
		owned[kind].append(id)
		save()

func equip(kind: String, id: String) -> void:
	if owns(kind, id) and equipped[kind] != id:
		equipped[kind] = id
		save()

func set_look(key: String, id: String) -> void:
	look_choice[key] = id
	save()

## Everything a rig needs to dress Minh Hân: hairstyle, hair colour and skin tone.
func look() -> Dictionary:
	return {"hair": equipped["hair"], "hair_color": look_choice["hair_color"], "skin": look_choice["skin"]}

## Puts Minh Hân's saved outfit, look and gear on a rig.
func dress(rig: Node2D) -> void:
	rig.set_outfit(equipped["outfit"])
	rig.apply_look(look())
	for slot: String in ["hat", "wings", "aura"]:
		rig.set_gear(slot, equipped[slot])

func xp_needed(level: int = player_level) -> int:
	return 80 + (level - 1) * 40

## Adds experience and pays out every level gained: diamonds and coins grow with the level.
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		player_level += 1
		var reward_coins := 100 + player_level * 25
		var reward_gems := 5 + player_level
		coins += reward_coins
		gems += reward_gems
		leveled_up.emit(player_level, reward_coins, reward_gems)
	save()

func can_afford(cost: Dictionary) -> bool:
	return coins >= int(cost.get("coin", 0)) and gems >= int(cost.get("gem", 0))

func buy(kind: String, id: String) -> bool:
	var cost: Dictionary = Catalog.price(kind, id)
	if owns(kind, id) or cost.is_empty() or not can_afford(cost):
		return false
	coins -= int(cost.get("coin", 0))
	gems -= int(cost.get("gem", 0))
	owned[kind].append(id)
	save()
	return true

func add_coins(n: int) -> void:
	coins += n
	save()

func add_gems(n: int) -> void:
	gems += n
	save()

func reach_level(level: int) -> void:
	if level > best_level:
		best_level = level
		save()

func _draw_marble() -> String:
	if bag.is_empty():
		for kind: String in BAG:
			for i in range(BAG[kind]):
				bag.append(kind)
		bag.shuffle()
	return bag.pop_back()

## Decides the gift before any box is picked (the marble is spent right away); claim() hands it over.
func roll_gift() -> Dictionary:
	var marble := _draw_marble()
	var prize: Dictionary
	match marble:
		"coins":
			prize = {"kind": "coins", "amount": [60, 80, 100, 150, 250].pick_random()}
		"gems":
			prize = {"kind": "gems", "amount": [3, 5, 8, 12].pick_random()}
		"outfit":
			prize = _pick_item(["outfit"])
		_:
			prize = _pick_item(ACCESSORY_KINDS)
	save()
	return prize

## A random item Minh Hân lacks; weights favour cheap items so showpieces stay rare.
func _pick_item(kinds: Array) -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for kind: String in kinds:
		for id: String in Catalog.ids(kind):
			if owns(kind, id) or Catalog.price(kind, id).is_empty():
				continue
			var weight := 0.25 if Catalog.is_special(kind, id) else 1.0
			pool.append([kind, id, weight])
			total += weight
	if pool.is_empty():
		return {"kind": "gems", "amount": 15}
	var roll := randf() * total
	for entry: Array in pool:
		roll -= entry[2]
		if roll <= 0.0:
			return {"kind": entry[0], "id": entry[1]}
	return {"kind": pool.back()[0], "id": pool.back()[1]}

func claim(prize: Dictionary) -> void:
	match prize["kind"]:
		"coins": coins += prize["amount"]
		"gems": gems += prize["amount"]
		_:
			if not owns(prize["kind"], prize["id"]):
				owned[prize["kind"]].append(prize["id"])
	save()
