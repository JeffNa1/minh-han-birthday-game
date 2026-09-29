extends SceneTree
## Renders every Minh Hân outfit, hairstyle, gear piece, pet and rival through the real renderer.

const OUT := "user://captures"
const Wardrobe := preload("res://scripts/art/wardrobe.gd")
const Catalog := preload("res://scripts/data/catalog.gd")
const Pet := preload("res://scripts/entities/pet.gd")

func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")

func shot(file_name: String) -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + file_name)

func stage() -> Node2D:
	var s := Node2D.new()
	root.add_child(s)
	var bg := ColorRect.new()
	bg.color = Color("f7e6ea")
	bg.size = Vector2(960, 540)
	s.add_child(bg)
	return s

func rig(parent: Node, character: String, outfit: String, at: Vector2, scale: float) -> Node2D:
	var r: Node2D = load("res://scripts/entities/character_rig.gd").new()
	r.character = character
	r.outfit = outfit
	r.position = at
	r.scale = Vector2.ONE * scale
	parent.add_child(r)
	return r

func label(parent: Node, text: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = at + Vector2(-80, 8)
	l.size = Vector2(160, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 11)
	parent.add_child(l)

func grid(items: Array, file_name: String, make: Callable) -> void:
	var s := stage()
	for i in range(items.size()):
		var at := Vector2(80 + (i % 6) * 160, 240 + (i / 6) * 260)
		make.call(s, items[i], at)
	await shot(file_name)
	s.queue_free()

func _run() -> void:
	var girls: Array = Wardrobe.ids_for("minh_han")
	var pages := int(ceil(girls.size() / 12.0))
	for page in range(pages):
		await grid(girls.slice(page * 12, page * 12 + 12), "outfits_%d.png" % page, func(s: Node, id: String, at: Vector2) -> void:
			rig(s, "minh_han", id, at, 1.05)
			label(s, Wardrobe.OUTFITS[id]["name"], at))
	var rivals := ["rival", "rival_b", "rival_c", "emo", "bikini", "catgirl", "elegant", "librarian", "yandere", "singer", "actress", "manager"]
	await grid(rivals, "rivals.png", func(s: Node, id: String, at: Vector2) -> void:
		rig(s, id, id, at, 1.05)
		label(s, Wardrobe.LOOKS[id].get("title", id), at))
	for kind: String in ["hat", "wings", "aura"]:
		var ids: Array = Catalog.ids(kind).filter(func(id: String) -> bool: return id != "none")
		await grid(ids, "gear_%s.png" % kind, func(s: Node, id: String, at: Vector2) -> void:
			var r := rig(s, "minh_han", "pajamas", at, 1.0)
			r.set_gear(kind, id)
			label(s, Catalog.item_name(kind, id), at))
	var pets: Array = Catalog.ids("pet").filter(func(id: String) -> bool: return id != "none")
	await grid(pets, "pets.png", func(s: Node, id: String, at: Vector2) -> void:
		var p: Node2D = Pet.new()
		p.kind = id
		p.position = at
		p.scale = Vector2.ONE * 2.2
		s.add_child(p)
		label(s, Catalog.item_name("pet", id), at))
	quit()
