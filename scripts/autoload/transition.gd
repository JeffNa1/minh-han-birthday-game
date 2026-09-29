extends CanvasLayer
## Heart-shaped iris wipe between scenes.

const SHADER := """
shader_type canvas_item;
uniform float radius = 1.5;
uniform vec2 aspect = vec2(1.7778, 1.0);
uniform vec4 tint : source_color = vec4(0.98, 0.55, 0.68, 1.0);
float heart(vec2 p) {
	p.y = -p.y + 0.25;
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) return sqrt(dot(p - vec2(0.25, 0.75), p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
	float a = dot(p - vec2(0.0, 1.0), p - vec2(0.0, 1.0));
	vec2 q = p - 0.5 * max(p.x + p.y, 0.0);
	float b = dot(q, q);
	return sqrt(min(a, b)) * sign(p.x - p.y);
}
void fragment() {
	vec2 p = (UV - 0.5) * aspect * 2.0;
	float d = heart(p / max(radius, 0.0001));
	float edge = smoothstep(0.0, 0.02 / max(radius, 0.05), d);
	COLOR = vec4(tint.rgb, tint.a * edge);
}
"""

var _rect: ColorRect
var _busy: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	mat.shader = shader
	_rect.material = mat
	add_child(_rect)
	_set_radius(3.0)

func _set_radius(r: float) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("radius", r)
	_rect.visible = r < 2.9

## Iris closes, `between` runs while the screen is covered, iris reopens.
func swap(between: Callable) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var close := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	close.tween_method(_set_radius, 3.0, 0.0, 0.3)
	await close.finished
	between.call()
	await get_tree().process_frame
	var open := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open.tween_method(_set_radius, 0.0, 3.0, 0.4)
	await open.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var close := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	close.tween_method(_set_radius, 3.0, 0.0, 0.45)
	await close.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var open := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open.tween_method(_set_radius, 0.0, 3.0, 0.55)
	await open.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
