class_name WaveConfig
extends Resource
## Configuracion de una oleada: que enemigos salen, cada cuanto y
## cuanto se refuerzan respecto a sus valores base.

## Nombre que se muestra en el HUD al entrar en la oleada.
@export var display_name: String = "Oleada"
## Bajas necesarias dentro de esta oleada para pasar a la siguiente.
@export var kills_to_advance: int = 6
## Escenas de enemigo que pueden aparecer.
@export var enemy_scenes: Array[PackedScene] = []
## Peso relativo de cada escena (mismo orden y tamano que enemy_scenes).
@export var weights: Array[float] = []
## Segundos entre generaciones.
@export var spawn_interval: float = 2.0
## Maximo de enemigos vivos a la vez.
@export var max_alive: int = 6
## Multiplicadores sobre las estadisticas base del enemigo.
@export var health_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0


static func create(
	p_name: String,
	p_kills: int,
	p_scenes: Array,
	p_weights: Array,
	p_interval: float,
	p_max_alive: int,
	p_health: float = 1.0,
	p_damage: float = 1.0,
	p_speed: float = 1.0
) -> WaveConfig:
	var wave := WaveConfig.new()
	wave.display_name = p_name
	wave.kills_to_advance = p_kills
	# assign() convierte los arrays sin tipo del literal al tipo del @export.
	wave.enemy_scenes.assign(p_scenes)
	wave.weights.assign(p_weights)
	wave.spawn_interval = p_interval
	wave.max_alive = p_max_alive
	wave.health_multiplier = p_health
	wave.damage_multiplier = p_damage
	wave.speed_multiplier = p_speed
	return wave
