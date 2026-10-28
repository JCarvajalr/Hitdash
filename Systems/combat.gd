extends Node
## Autoload "Combat": todo lo que hace que pegar se sienta bien.
##  - Hit-stop (congelar el juego unas centesimas al impactar).
##  - Temblor de camara.
##  - Combo con rangos de estilo (D -> SSS) que multiplican la puntuacion.
##  - Estadisticas de la partida y records guardados en disco.

signal combo_changed(combo: int, rank_index: int)
signal rank_changed(rank_index: int)
signal combo_dropped(final_combo: int)
signal score_changed(score: int)
signal enemy_killed(position: Vector2, is_boss: bool)

## Puntos extra por derrotar a un jefe (antes del multiplicador).
const BOSS_BONUS := 2500

const SAVE_PATH := "user://hitdash_save.cfg"

const RANKS := ["D", "C", "B", "A", "S", "SS", "SSS"]
const RANK_TITLES := ["Dormido", "Calentando", "Brutal", "Asesino", "Sanguinario", "Salvaje", "HITDASH"]
## Golpes de combo necesarios para alcanzar cada rango.
const RANK_THRESHOLDS := [0, 5, 12, 22, 35, 55, 80]
const RANK_COLORS := [
	Color(0.62, 0.62, 0.68),
	Color(0.35, 0.65, 1.0),
	Color(0.35, 0.9, 0.45),
	Color(1.0, 0.85, 0.25),
	Color(1.0, 0.55, 0.15),
	Color(1.0, 0.22, 0.25),
	Color(1.0, 0.3, 0.95),
]

## Segundos para encadenar el siguiente golpe en rango D. Se acorta al subir de rango.
@export var combo_window: float = 2.6
@export var combo_window_per_rank: float = 0.2
@export var combo_window_min: float = 1.2
## Intensidad maxima del temblor (pixeles) y lo rapido que se apaga.
@export var max_shake: float = 18.0
@export var shake_decay: float = 60.0

var combo: int = 0
var max_combo: int = 0
var score: int = 0
var kills: int = 0
var run_time: float = 0.0
var combo_time_left: float = 0.0
## Tiempo extra de combo que dan las reliquias (se reinicia cada partida).
var combo_window_bonus: float = 0.0

var best_score: int = 0
var best_combo: int = 0
var best_time: float = 0.0

var _rank: int = 0
var _camera: Camera2D = null
var _shake: float = 0.0
var _hitstop_token: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_records()


## Se llama al empezar cada partida (incluido al reiniciar la escena).
func reset_run() -> void:
	combo = 0
	max_combo = 0
	score = 0
	kills = 0
	run_time = 0.0
	combo_time_left = 0.0
	combo_window_bonus = 0.0
	_rank = 0
	_shake = 0.0
	_hitstop_token += 1
	Engine.time_scale = 1.0
	_camera = null


func register_camera(camera: Camera2D) -> void:
	_camera = camera


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# Durante el hit-stop el delta llega escalado; se usa el tiempo real.
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	run_time += real_delta

	if combo > 0:
		combo_time_left -= real_delta
		if combo_time_left <= 0.0:
			_drop_combo()

	if _camera != null and is_instance_valid(_camera):
		if _shake > 0.0:
			_shake = maxf(_shake - shake_decay * real_delta, 0.0)
			_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		else:
			_camera.offset = Vector2.ZERO


# --- Game feel ----------------------------------------------------------

## Congela (casi) el juego durante `duration` segundos reales.
func hitstop(duration: float, time_scale: float = 0.05) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = time_scale
	# ignore_time_scale = true: el temporizador corre en tiempo real.
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0


func shake(strength: float) -> void:
	_shake = minf(maxf(_shake, strength), max_shake)


# --- Combo y puntuacion -------------------------------------------------

func register_hit(damage: float, killed: bool, crit: bool) -> void:
	combo += 1
	max_combo = maxi(max_combo, combo)
	combo_time_left = current_combo_window()

	var points: float = damage
	if crit:
		points *= 1.5
	if killed:
		kills += 1
		points += 100.0
	score += roundi(points * multiplier())

	var new_rank := _rank_for(combo)
	if new_rank != _rank:
		_rank = new_rank
		rank_changed.emit(_rank)
	combo_changed.emit(combo, _rank)
	score_changed.emit(score)


## Lo llama el jugador cuando su golpe remata a un enemigo.
func notify_kill(enemy: Node2D) -> void:
	var is_boss := enemy is Boss
	if is_boss:
		score += roundi(BOSS_BONUS * multiplier())
		score_changed.emit(score)
	enemy_killed.emit(enemy.global_position, is_boss)


func player_hurt() -> void:
	if combo > 0:
		_drop_combo()


func current_combo_window() -> float:
	return maxf(combo_window - combo_window_per_rank * _rank, combo_window_min) + combo_window_bonus


func multiplier() -> float:
	return 1.0 + 0.5 * _rank


func rank_index() -> int:
	return _rank


func _rank_for(value: int) -> int:
	var result := 0
	for i in RANK_THRESHOLDS.size():
		if value >= RANK_THRESHOLDS[i]:
			result = i
	return result


func _drop_combo() -> void:
	var final_combo := combo
	combo = 0
	combo_time_left = 0.0
	_rank = 0
	combo_dropped.emit(final_combo)
	combo_changed.emit(0, 0)


# --- Records ------------------------------------------------------------

## Guarda los records si se han superado. Devuelve true si hay nueva mejor puntuacion.
func commit_records() -> bool:
	var new_best := score > best_score
	best_score = maxi(best_score, score)
	best_combo = maxi(best_combo, max_combo)
	best_time = maxf(best_time, run_time)

	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_score", best_score)
	cfg.set_value("records", "best_combo", best_combo)
	cfg.set_value("records", "best_time", best_time)
	cfg.save(SAVE_PATH)
	return new_best


func _load_records() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_score = int(cfg.get_value("records", "best_score", 0))
	best_combo = int(cfg.get_value("records", "best_combo", 0))
	best_time = float(cfg.get_value("records", "best_time", 0.0))


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
