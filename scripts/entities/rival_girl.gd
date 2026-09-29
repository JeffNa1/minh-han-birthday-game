extends CharacterBody2D
## A rival girl: strolls her zone, charms free Nam Anh into her own walking entourage,
## and goes after Minh Hân's floating boys, which forces a click-fast tug of war.

const Fx := preload("res://scripts/vfx/fx.gd")
const Kit := preload("res://scripts/art/soft_draw.gd")
const Zones := preload("res://scripts/world/zones.gd")
const Wardrobe := preload("res://scripts/art/wardrobe.gd")
const TAG_FONT := preload("res://assets/fonts/ui_font.tres")

enum State { WANDER, APPROACH, CHARMING, CLASHING, STUNNED }

@onready var rig: Node2D = $Rig
@onready var beam: Node2D = $LoveBeam
@onready var stun_timer: Timer = $StunTimer

var state: State = State.WANDER
var target: Node2D = null
var followers: Array = []
var bounds := Vector2(40, 920)
var walk_speed: float = 72.0
var _goal: Vector2
var _pause: float = 0.0
var _think: float = 1.5
var _charm: float = 0.0
var _need: float = 4.0
var _t: float = 0.0
var _reach: float = 420.0
var _charm_mult: float = 1.0
var title: String = ""

func _ready() -> void:
	var cfg: Dictionary = GameManager.config()
	walk_speed *= cfg["rival_speed"]
	_reach = cfg["rival_reach"]
	_charm_mult = cfg["rival_charm"]
	beam.rival = true
	var look: Dictionary = Wardrobe.LOOKS[rig.character]
	beam.rival_color = look.get("beam", Color("a96bff"))
	title = look.get("title", "Đối thủ")
	_goal = global_position
	rig.set_facing(-1.0 if randf() > 0.5 else 1.0)
	stun_timer.timeout.connect(_on_stun_timeout)
	GameManager.clash_resolved.connect(_on_clash_resolved)

func _physics_process(delta: float) -> void:
	_t += delta
	if not GameManager.game_active or state in [State.CLASHING, State.STUNNED]:
		beam.deactivate()
		rig.set_motion("stun" if state == State.STUNNED else ("beam" if state == State.CLASHING else "idle"))
		return
	match state:
		State.WANDER:
			_wander(delta)
			_think -= delta
			if _think <= 0.0:
				_think = randf_range(0.8, 1.8)
				target = _pick_target()
				if target:
					state = State.APPROACH
		State.APPROACH:
			if not _target_ok():
				_reset()
				return
			var stand := target.global_position + Vector2(signf(global_position.x - target.global_position.x) * 140.0, 0)
			stand.x = clampf(stand.x, bounds.x, bounds.y)
			var to := stand - global_position
			if to.length() < 40.0 or global_position.distance_to(target.global_position) < 170.0:
				state = State.CHARMING
				_charm = 0.0
				_need = ((3.0 if target.is_player_boy() else 4.0) + target.tier * 0.5) * _charm_mult
			else:
				velocity = to.normalized() * walk_speed * 1.4
				move_and_slide()
				rig.set_facing(velocity.x)
				rig.set_motion("walk", walk_speed * 1.4)
		State.CHARMING:
			_charming(delta)

func _process(_delta: float) -> void:
	queue_redraw()

## Name tag above her head so each rival has a personality at a glance.
func _draw() -> void:
	var w := TAG_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16.0
	var r := Rect2(-w / 2.0, -96.0, w, 18)
	draw_colored_polygon(Kit.rrect_pts(r, 9.0), Color(beam.rival_color, 0.85))
	draw_string(TAG_FONT, Vector2(r.position.x + 8, r.position.y + 13), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _wander(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		rig.set_motion("idle")
		rig.look_goal = sin(_t * 0.8) * 0.7 - 0.2
		if _pause <= 0.0:
			_goal = Vector2(clampf(global_position.x + randf_range(-360, 360), bounds.x, bounds.y), randf_range(Zones.GROUND_TOP, Zones.GROUND_BOTTOM))
		return
	var to := _goal - global_position
	if to.length() < 6.0:
		_pause = randf_range(0.6, 2.0)
		return
	velocity = to.normalized() * walk_speed
	move_and_slide()
	rig.set_facing(velocity.x)
	rig.set_motion("walk", walk_speed)
	rig.look_goal = 0.0

func _charming(delta: float) -> void:
	if not _target_ok() or global_position.distance_to(target.global_position) > 300.0:
		_reset()
		return
	var player := get_tree().get_first_node_in_group("player")
	var fighting_player: bool = player != null and player.state != player.State.STUNNED and (target.is_player_boy() or (player.current_target == target and player.state == player.State.BEAMING))
	rig.set_facing(target.global_position.x - global_position.x)
	rig.set_motion("beam")
	beam.from_marker = rig.eye
	beam.to_marker = target.rig.eye
	beam.activate(rig.eye.global_position, target.get_eye_position())
	target.hold_still()
	_charm += delta
	if fighting_player and _charm > 0.6:
		state = State.CLASHING
		beam.deactivate()
		GameManager.start_clash(self, target)
		return
	if _charm >= _need:
		target.set_lover(self)
		_reset()

func _target_ok() -> bool:
	return is_instance_valid(target) and target.lover != self and target.get_parent() == get_parent()

func _pick_target() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var best: Node2D = null
	var best_score := INF
	for boy: Node in get_parent().get_children():
		if not boy.is_in_group("boys") or boy.lover == self:
			continue
		if boy.lover != null and not boy.is_player_boy():
			continue
		var d := global_position.distance_to(boy.global_position)
		if boy.is_player_boy():
			# Minh Hân's boys are juicier but only worth it when she is close by.
			if player == null or player.state == player.State.STUNNED or d > _reach:
				continue
			d *= 0.8
		elif d > 700.0:
			continue
		if d < best_score:
			best_score = d
			best = boy
	return best

func _reset() -> void:
	state = State.WANDER
	target = null
	beam.deactivate()
	_pause = randf_range(0.4, 1.2)

func _on_clash_resolved(player_won: bool, boy: Node2D) -> void:
	if state != State.CLASHING or boy != target:
		return
	if player_won:
		state = State.STUNNED
		target = null
		rig.pop(0.3)
		Fx.sparkles(global_position + Vector2(0, -40), 10, Color("d9c2ff"), 40.0)
		velocity = Vector2(-rig.facing * 220.0, 0)
		create_tween().tween_property(self, "position:x", position.x - rig.facing * 60.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stun_timer.start(3.5)
	else:
		if is_instance_valid(boy):
			boy.set_lover(self)
		_reset()

func _on_stun_timeout() -> void:
	if state == State.STUNNED:
		_reset()
