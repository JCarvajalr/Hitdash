extends Node
## Autoload "Sfx": efectos de sonido con un pool de reproductores,
## musica de fondo y gestion de volumen (Master, SFX, Musica) con guardado en disco.

const SETTINGS_PATH := "user://hitdash_settings.cfg"

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

## Niveles de volumen lineales (0.0 a 1.0)
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var music_volume: float = 0.8

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _music_name: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()

	for i in pool_size:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

	_music = AudioStreamPlayer.new()
	_music.volume_db = _calc_music_db()
	add_child(_music)
	# Los .wav no traen bucle: se vuelve a lanzar al terminar.
	_music.finished.connect(func(): _music.play())


func _calc_music_db() -> float:
	var combined := master_volume * music_volume
	if combined <= 0.001:
		return -80.0
	return music_volume_db + linear_to_db(combined)


func _calc_sfx_db() -> float:
	var combined := master_volume * sfx_volume
	if combined <= 0.001:
		return -80.0
	return sfx_volume_db + linear_to_db(combined)


## Actualiza el volumen general y lo guarda en disco
func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


## Actualiza el volumen de SFX y lo guarda en disco
func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


## Actualiza el volumen de música y lo guarda en disco
func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	if _music != null:
		_music.volume_db = _calc_music_db()


## Reproduce un efecto con una ligera variacion de tono para que no canse.
func play(sound: String, pitch_variation: float = 0.08, volume_db: float = 0.0) -> void:
	if not SOUNDS.has(sound):
		push_warning("Sfx: sonido desconocido '%s'" % sound)
		return
	var eff_sfx_db := _calc_sfx_db()
	if eff_sfx_db <= -70.0:
		return # Silenciado

	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = SOUNDS[sound]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.volume_db = eff_sfx_db + volume_db
	player.play()


## Cambia la musica con un fundido corto. No hace nada si ya suena esa pista.
func play_music(track: String) -> void:
	if track == _music_name or not MUSIC.has(track):
		return
	_music_name = track
	var target_db := _calc_music_db()
	var tween := create_tween()
	if _music.playing:
		tween.tween_property(_music, "volume_db", -40.0, 0.4)
	tween.tween_callback(func():
		_music.stream = MUSIC[track]
		_music.play()
	)
	tween.tween_property(_music, "volume_db", target_db, 0.6)


func stop_music() -> void:
	_music_name = ""
	_music.stop()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = float(cfg.get_value("audio", "master_volume", 1.0))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", 0.8))
	music_volume = float(cfg.get_value("audio", "music_volume", 0.8))


func _exit_tree() -> void:
	# Cortar el audio al cerrar para que no queden reproducciones vivas.
	_music.stop()
	_music.stream = null
	for player in _players:
		player.stop()
