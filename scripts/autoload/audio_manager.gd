extends Node

var bgm_player: AudioStreamPlayer
var beam_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load BGM
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	add_child(bgm_player)
	
	var bgm_stream: AudioStream = load("res://assets/audio/bgm.wav")
	if bgm_stream:
		bgm_player.stream = bgm_stream
		bgm_player.volume_db = -6.0

	# Load continuous beam player
	beam_player = AudioStreamPlayer.new()
	beam_player.bus = "Master"
	add_child(beam_player)
	var beam_stream: AudioStream = load("res://assets/audio/beam.wav")
	if beam_stream:
		beam_player.stream = beam_stream
		beam_player.volume_db = -4.0

	# Preload SFX
	sounds["pop"] = load("res://assets/audio/pop.wav")
	sounds["clash"] = load("res://assets/audio/clash.wav")
	sounds["click"] = load("res://assets/audio/click.wav")
	sounds["beauty"] = load("res://assets/audio/beauty.wav")
	sounds["stun"] = load("res://assets/audio/stun.wav")
	
	# SFX pool
	for i in range(8):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

func play_bgm() -> void:
	if bgm_player and not bgm_player.playing:
		bgm_player.play()

func stop_bgm() -> void:
	if bgm_player:
		bgm_player.stop()

func set_beam_loop(active: bool) -> void:
	if not beam_player or not beam_player.stream:
		return
	if active and not beam_player.playing:
		beam_player.play()
	elif not active and beam_player.playing:
		beam_player.stop()

func play_sfx(name: String) -> void:
	if not sounds.has(name) or sounds[name] == null:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sounds[name]
			p.volume_db = -2.0
			p.play()
			return
	# fallback to first player if all busy
	if sfx_players.size() > 0:
		sfx_players[0].stream = sounds[name]
		sfx_players[0].play()
