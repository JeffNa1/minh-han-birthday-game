extends Node
## Round rules: a love meter of ten hearts that drains over time, a countdown per level,
## three levels, score and the chain of boys following Minh Hân.

const Zones := preload("res://scripts/world/zones.gd")
const MAX_HEARTS := 10
const START_HEARTS := 3

signal score_changed(new_score: int)
signal time_changed(time_left: float)
signal hearts_changed(hearts: int, delta: int)
signal boy_charmed(boy_node: Node2D, points: int)
signal level_started(index: int)
signal level_finished(won: bool, reason: String)
signal clash_requested(rival: Node2D, boy: Node2D)
signal clash_resolved(player_won: bool, boy: Node2D)

var level: int = 0
var hearts: int = START_HEARTS
var score: int = 0
var total_charmed: int = 0
var charmed_count: int = 0
var time_left: float = 100.0
var game_active: bool = false
var won_game: bool = false
var furthest_level: int = 0
var combo: int = 0
var charmed_boys_chain: Array[Node2D] = []
var _drain: float = 0.0
var _last_charm: float = -99.0
var _clock: float = 0.0

var last_reward: int = 0
var _config: Dictionary = {}
var _config_level: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func config() -> Dictionary:
	if _config_level != level:
		_config = Zones.level(level)
		_config_level = level
	return _config

func is_final_level() -> bool:
	return level >= Zones.LEVEL_COUNT - 1

## Starts a run from the furthest level Minh Hân has unlocked.
func new_game() -> void:
	level = mini(Profile.best_level, Zones.LEVEL_COUNT - 1)
	score = 0
	total_charmed = 0
	won_game = false
	furthest_level = 0

## Resets the meter and clock for the current level; the world calls start_play() after its intro.
func begin_level() -> void:
	hearts = START_HEARTS
	charmed_count = 0
	combo = 0
	time_left = config()["time"]
	_drain = config()["drain"]
	charmed_boys_chain.clear()
	game_active = false
	furthest_level = maxi(furthest_level, level)
	score_changed.emit(score)
	time_changed.emit(time_left)
	hearts_changed.emit(hearts, 0)
	level_started.emit(level)
	AudioManager.play_bgm()

func start_play() -> void:
	game_active = true

func _process(delta: float) -> void:
	_clock += delta
	if not game_active:
		return
	time_left = maxf(0.0, time_left - delta)
	time_changed.emit(time_left)
	if time_left <= 0.0:
		finish_level(false, "time")
		return
	_drain -= delta
	if _drain <= 0.0:
		_drain = config()["drain"]
		change_hearts(-1)

func drain_progress() -> float:
	return 1.0 - _drain / config()["drain"]

func change_hearts(delta: int) -> void:
	if not game_active:
		return
	hearts = clampi(hearts + delta, 0, MAX_HEARTS)
	hearts_changed.emit(hearts, delta)
	if hearts >= MAX_HEARTS:
		finish_level(true, "")
	elif hearts <= 0:
		finish_level(false, "hearts")

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func register_charmed_boy(boy: Node2D, points: int) -> void:
	combo = combo + 1 if _clock - _last_charm < 5.0 else 1
	_last_charm = _clock
	charmed_count += 1
	total_charmed += 1
	if boy not in charmed_boys_chain:
		charmed_boys_chain.append(boy)
	add_score(points * combo)
	Profile.add_xp(12 + boy.tier * 4)
	AudioManager.play_sfx("pop")
	boy_charmed.emit(boy, points * combo)
	_drain = config()["drain"]
	change_hearts(2 if boy.tier == 3 else 1)

## A follower slipped away (stolen by a rival or scared off by the manager).
func lose_follower(boy: Node2D) -> void:
	charmed_boys_chain.erase(boy)
	change_hearts(-1)

func finish_level(won: bool, reason: String) -> void:
	if not game_active:
		return
	game_active = false
	Engine.time_scale = 1.0
	level_finished.emit(won, reason)

## Freeze-frame on big moments; the timer ignores the slowed time scale.
func hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func start_clash(rival: Node2D, boy: Node2D) -> void:
	clash_requested.emit(rival, boy)

func resolve_clash(player_won: bool, boy: Node2D) -> void:
	clash_resolved.emit(player_won, boy)

func end_game() -> void:
	game_active = false
	Engine.time_scale = 1.0
	Transition.go("res://scenes/game_over.tscn")

func get_ending() -> String:
	if won_game:
		return "true_harem"
	return "normal" if furthest_level > 2 else "bad"
