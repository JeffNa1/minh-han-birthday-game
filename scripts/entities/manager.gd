extends CharacterBody2D
## The strict festival manager. She patrols and glances around; flirting inside her line of sight is
## caught on the spot, and from level 2 simply being spotted makes her suspicious and give chase.
## Getting caught stuns Minh Hân, costs two hearts and scares off one of her boys.

const Fx := preload("res://scripts/vfx/fx.gd")
const Zones := preload("res://scripts/world/zones.gd")

enum State { PATROL, SUSPICIOUS, CHASE }

@onready var rig: Node2D = $Rig
@onready var cone: Node2D = $Cone

var bounds := Vector2(40, 920)
var sight: float = 240.0
var walk_speed: float = 55.0
var chases: bool = false
var state: State = State.PATROL
var _dir: float = 1.0
var _pause: float = 0.0
var _cooldown: float = 0.0
var _timer: float = 0.0
var _goal_y: float = 400.0
var _t: float = 0.0

func _ready() -> void:
	var cfg: Dictionary = GameManager.config()
	sight = cfg["manager_sight"]
	walk_speed = cfg["manager_speed"]
	chases = cfg["manager_chase"]
	_dir = 1.0 if randf() > 0.5 else -1.0
	rig.set_facing(_dir)
	rig.turn = _dir
	_goal_y = global_position.y
	cone.draw.connect(_draw_cone)

func _player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or p.get_parent() != get_parent() or p.state == p.State.STUNNED:
		return null
	return p

func _physics_process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	cone.queue_redraw()
	if not GameManager.game_active:
		rig.set_motion("idle")
		return
	var player := _player()
	match state:
		State.PATROL:
			_patrol(delta)
			if player and _cooldown <= 0.0:
				if player.state == player.State.BEAMING and _sees(player.global_position, sight):
					_catch(player)
				elif chases and _sees(player.global_position, sight * 0.8):
					state = State.SUSPICIOUS
					_timer = 0.56
					velocity = Vector2.ZERO
					Fx.text(global_position + Vector2(0, -92), "?", Color("ff9d2e"), 34)
		State.SUSPICIOUS:
			rig.set_motion("idle")
			_timer -= delta
			if player == null:
				state = State.PATROL
			elif _timer <= 0.0:
				state = State.CHASE
				_timer = (3.4 + GameManager.level * 0.2) * 0.8
				rig.pop(0.25)
				Fx.text(global_position + Vector2(0, -92), "!", Color("ff4f5f"), 40)
		State.CHASE:
			_timer -= delta
			if player == null or _timer <= 0.0:
				state = State.PATROL
				_pause = 1.2
				return
			var to := player.global_position - global_position
			velocity = to.normalized() * walk_speed * 2.3
			move_and_slide()
			global_position.x = clampf(global_position.x, bounds.x, bounds.y)
			rig.set_facing(to.x)
			rig.set_motion("walk", walk_speed * 2.3)
			if to.length() < 38.0 or (player.state == player.State.BEAMING and _sees(player.global_position, sight)):
				_catch(player)
				return
	if player and _cooldown <= 0.0 and player.global_position.distance_to(global_position) < 34.0:
		_catch(player)

func _patrol(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		rig.set_motion("idle")
		# Looking around makes her glance behind herself too.
		rig.look_goal = sin(_t * 1.6) * 1.2 - 0.4
		if _pause <= 0.0 and randf() < 0.55:
			_dir = -_dir
		return
	velocity = Vector2(_dir * walk_speed, (_goal_y - global_position.y) * 0.8)
	move_and_slide()
	rig.set_facing(_dir)
	rig.set_motion("walk", walk_speed)
	rig.look_goal = 0.0
	if global_position.x < bounds.x + 60.0 or global_position.x > bounds.y - 60.0:
		_dir = signf(bounds.x + bounds.y - 2.0 * global_position.x)
		_pause = randf_range(0.6, 1.4)
	elif randf() < delta * (0.25 + GameManager.level * 0.05):
		# Sudden about-turns get more frequent on later levels.
		_dir = -_dir if randf() < 0.5 else _dir
		_pause = randf_range(0.8, 1.8)
		_goal_y = randf_range(Zones.GROUND_TOP, Zones.GROUND_BOTTOM)

func _sees(p: Vector2, reach: float) -> bool:
	var ahead: float = (p.x - global_position.x) * rig.facing
	return ahead > 0.0 and ahead < reach and absf(p.y - global_position.y) < 75.0

func _catch(player: Node2D) -> void:
	state = State.PATROL
	_cooldown = 5.0
	_pause = 1.6
	velocity = Vector2.ZERO
	rig.set_facing(player.global_position.x - global_position.x)
	rig.pop(0.3)
	Fx.text(global_position + Vector2(0, -92), "!!", Color("ff4f5f"), 40)
	player.caught_by_manager()

func _draw_cone() -> void:
	var f: float = rig.facing
	var feet := Vector2(0, 55)
	var col := Color(1.0, 0.85, 0.35, 0.38)
	if state == State.SUSPICIOUS:
		col = Color(1.0, 0.6, 0.2, 0.45)
	elif state == State.CHASE or _cooldown > 3.5:
		col = Color(1.0, 0.3, 0.35, 0.45)
	var reach := sight * (1.0 + sin(_t * 4.0) * 0.03)
	var pts := PackedVector2Array([feet + Vector2(f * 10, -4)])
	for i in range(9):
		pts.append(feet + Vector2(f * reach, lerpf(-34.0, 34.0, float(i) / 8.0)))
	pts.append(feet + Vector2(f * 10, 4))
	var cols := PackedColorArray()
	for i in range(pts.size()):
		cols.append(col if i == 0 or i == pts.size() - 1 else Color(col, 0.0))
	cone.draw_polygon(pts, cols)
	# A dashed far edge marks exactly where her sight ends.
	for i in range(6):
		var y0 := lerpf(-30.0, 30.0, i / 6.0)
		cone.draw_line(feet + Vector2(f * reach, y0), feet + Vector2(f * reach, y0 + 5.0), Color(col, 0.7), 2.0, true)
