extends Node2D
## Genera enemigos en posiciones aleatorias dentro de un area,
## manteniendo una distancia minima respecto al jugador.

@export var enemy_scene: PackedScene
## Segundos entre intentos de generacion.
@export var spawn_interval: float = 2.0
## Maximo de enemigos vivos al mismo tiempo.
@export var max_alive: int = 8
## Total de enemigos a generar en toda la partida. -1 = infinito.
@export var total_to_spawn: int = -1
## Rectangulo (en coordenadas globales) donde pueden aparecer.
@export var spawn_area: Rect2 = Rect2(64, 64, 1024, 520)
## Distancia minima al jugador para no aparecer encima de el.
@export var min_distance_to_player: float = 220.0
## Escala aplicada a cada enemigo generado.
@export var enemy_scale: Vector2 = Vector2(2.8, 2.8)

@onready var _timer: Timer = $SpawnTimer

var _player: Node2D = null
var _spawned_total: int = 0


func _ready() -> void:
	randomize()
	_player = get_tree().get_first_node_in_group("Player")

	if enemy_scene == null:
		push_warning("EnemySpawner: 'enemy_scene' no esta asignado.")
		return

	_timer.wait_time = spawn_interval
	_timer.one_shot = false
	if not _timer.timeout.is_connected(_on_spawn_timer_timeout):
		_timer.timeout.connect(_on_spawn_timer_timeout)
	_timer.start()


func _on_spawn_timer_timeout() -> void:
	if total_to_spawn >= 0 and _spawned_total >= total_to_spawn:
		_timer.stop()
		return
	if _alive_enemies() >= max_alive:
		return
	_spawn_one()


func _alive_enemies() -> int:
	return get_tree().get_nodes_in_group("Enemy").size()


func _spawn_one() -> void:
	var enemy: Node2D = enemy_scene.instantiate()
	enemy.scale = enemy_scale
	add_child(enemy)
	enemy.global_position = _pick_spawn_position()
	_spawned_total += 1


func _pick_spawn_position() -> Vector2:
	for i in 16:
		var candidate := Vector2(
			randf_range(spawn_area.position.x, spawn_area.end.x),
			randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if _player == null or candidate.distance_to(_player.global_position) >= min_distance_to_player:
			return candidate
	return spawn_area.get_center()
