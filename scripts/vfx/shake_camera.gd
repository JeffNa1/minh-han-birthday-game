extends Camera2D
## Follows Minh Hân inside the zone limits, with trauma-based shake and a punch-in zoom.

var trauma: float = 0.0
var target: Node2D = null
var _t: float = 0.0
var _zoom_kick: float = 0.0

func _ready() -> void:
	add_to_group("camera")
	ignore_rotation = false
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	limit_top = 0
	limit_bottom = 540

static func shake(amount: float, zoom_kick: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var cam: Node = tree.get_first_node_in_group("camera") if tree else null
	if cam:
		cam.trauma = minf(1.0, cam.trauma + amount)
		cam._zoom_kick = maxf(cam._zoom_kick, zoom_kick)

func set_zone(width: float) -> void:
	limit_left = 0
	limit_right = int(width)
	if is_instance_valid(target):
		global_position = Vector2(target.global_position.x, 270)
	reset_smoothing()

func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(target):
		global_position = Vector2(target.global_position.x + target.velocity.x * 0.35, 270)
	trauma = maxf(0.0, trauma - delta * 1.8)
	_zoom_kick = lerpf(_zoom_kick, 0.0, 1.0 - exp(-8.0 * delta))
	var s := trauma * trauma
	offset = Vector2(sin(_t * 71.0) + sin(_t * 43.0) * 0.5, cos(_t * 67.0) + cos(_t * 29.0) * 0.5) * 9.0 * s
	rotation = sin(_t * 53.0) * 0.012 * s
	zoom = Vector2.ONE * (1.0 + _zoom_kick)
