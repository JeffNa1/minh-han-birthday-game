extends Node2D
## One side-scrolling area: parallax sky, scenery, atmosphere, exit signs and the y-sorted cast.
## Inactive zones are hidden and frozen so only the area Minh Hân stands in runs.

const Zones := preload("res://scripts/world/zones.gd")
const Far := preload("res://scripts/art/zone_far.gd")
const Backdrop := preload("res://scripts/art/zone_backdrop.gd")
const Ambient := preload("res://scripts/art/ambient.gd")
const Sign := preload("res://scripts/world/stair_sign.gd")

var id: String
var data: Dictionary
var width: float
var entities: Node2D
var signs: Array = []

func setup(zone_id: String) -> void:
	id = zone_id
	name = zone_id.capitalize()
	data = Zones.ZONES[zone_id]
	width = data["width"]
	var parallax := Parallax2D.new()
	parallax.scroll_scale = Vector2(0.3, 1.0)
	parallax.z_index = -30
	add_child(parallax)
	var far: Node2D = Far.new()
	far.style = zone_id
	parallax.add_child(far)
	var backdrop: Node2D = Backdrop.new()
	backdrop.style = zone_id
	backdrop.width = width
	add_child(backdrop)
	var ambient: Node2D = Ambient.new()
	ambient.style = zone_id
	add_child(ambient)
	for exit: Dictionary in data["exits"]:
		var sign: Node2D = Sign.new()
		sign.heading = exit["dir"]
		sign.side = 1.0 if exit["x"] > width / 2.0 else -1.0
		sign.label = exit["label"]
		sign.position = Vector2(exit["x"] - sign.side * 30.0, 0)
		sign.z_index = -10
		add_child(sign)
		signs.append(sign)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	set_active(false)

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func clear_cast(keep: Array) -> void:
	for n: Node in entities.get_children():
		if n not in keep:
			n.queue_free()
