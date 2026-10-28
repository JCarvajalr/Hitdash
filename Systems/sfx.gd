extends Node
## Autoload "Sfx": efectos de sonido con un pool de reproductores y la
## musica de fondo. Todo el audio sale de tools/gen_sfx.py.

const SOUNDS := {
	"hit": preload("res://sounds/hit.wav"),
	"crit": preload("res://sounds/crit.wav"),
	"kill": preload("res://sounds/kill.wav"),
	"dash": preload("res://sounds/dash.wav"),
	"hurt": preload("res://sounds/hurt.wav"),
	"rank_up": preload("res://sounds/rank_up.wav"),
	"pickup": preload("res://sounds/pickup.wav"),
	"bolt": preload("res://sounds/bolt.wav"),
	"wave": preload("res://sounds/wave.wav"),
	"slam": preload("res://sounds/slam.wav"),
	"summon": preload("res://sounds/summon.wav"),
	"teleport": preload("res://sounds/teleport.wav"),
	"boss_roar": preload("res://sounds/boss_roar.wav"),
	"boss_death": preload("res://sounds/boss_death.wav"),
	"player_death": preload("res://sounds/player_death.wav"),
	"equip": preload("res://sounds/equip.wav"),
	"chest": preload("res://sounds/chest.wav"),
	"zap": preload("res://sounds/zap.wav"),
	"block": preload("res://sounds/block.wav"),
	"portal_open": preload("res://sounds/portal_open.wav"),
}

const MUSIC := {
	"main": preload("res://sounds/music_loop.wav"),
	"boss": preload("res://sounds/music_boss.wav"),
}

@export var pool_size: int = 16
@export var sfx_volume_db: float = -4.0
@export var music_volume_db: float = -12.0

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _music_name: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in pool_size:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	# Los .wav no traen bucle: se vuelve a lanzar al terminar.
	_music.finished.connect(func(): _music.play())


## Reproduce un efecto con una ligera variacion de tono para que no canse.
func play(sound: String, pitch_variation: float = 0.08, volume_db: float = 0.0) -> void:
	if not SOUNDS.has(sound):
		push_warning("Sfx: sonido desconocido '%s'" % sound)
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = SOUNDS[sound]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.volume_db = sfx_volume_db + volume_db
	player.play()


## Cambia la musica con un fundido corto. No hace nada si ya suena esa pista.
func play_music(track: String) -> void:
	if track == _music_name or not MUSIC.has(track):
		return
	_music_name = track
	var tween := create_tween()
	if _music.playing:
		tween.tween_property(_music, "volume_db", -40.0, 0.4)
	tween.tween_callback(func():
		_music.stream = MUSIC[track]
		_music.play()
	)
	tween.tween_property(_music, "volume_db", music_volume_db, 0.6)


func stop_music() -> void:
	_music_name = ""
	_music.stop()


func _exit_tree() -> void:
	# Cortar el audio al cerrar para que no queden reproducciones vivas.
	_music.stop()
	_music.stream = null
	for player in _players:
		player.stop()
