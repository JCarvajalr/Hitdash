extends Node2D
## Genera los enemigos de cada sala en posiciones aleatorias (fuera de los
## obstaculos y lejos del jugador), con una marca de aviso antes de que
## aparezcan.
##
## Cada oleada es una sala con un cupo de enemigos (`kills_to_advance`).
## Cuando salen y mueren todos se emite `room_cleared`; la arena abre
## entonces el portal y, al cruzarlo, llama a next_room().
##
## La dificultad avanza por oleadas: se empieza solo con orcos y, segun
## sube el numero de bajas, entran los slimes de lava (cuerpo a cuerpo que
## se enfurecen al ser golpeados), los vampiros (enemigos a distancia) y
## los enemigos salen mas reforzados. Entre medias hay oleadas de jefe:
## mientras el jefe vive no salen enemigos normales y al derrotarlo se
## pasa a la siguiente oleada. Pasada la ultima oleada el juego sigue en
## modo infinito, subiendo un escalon cada `kills_to_advance` y con un
## jefe reforzado cada `endless_boss_every` escalones.

signal wave_changed(index: int, display_name: String, endless_level: int)
signal kills_changed(kills: int)
signal boss_spawned(boss: Node)
signal boss_defeated
signal room_cleared

@export_group("Escenas de enemigos")
@export var orc_scene: PackedScene = preload("res://Entities/Enemies/orcs/orc_1.tscn")
@export var vampire_1_scene: PackedScene = preload("res://Entities/Enemies/vampire_1.tscn")
@export var vampire_2_scene: PackedScene = preload("res://Entities/Enemies/vampire_2.tscn")
@export var vampire_3_scene: PackedScene = preload("res://Entities/Enemies/vampire_3.tscn")
## Slime de lava: cuerpo a cuerpo que se enfurece (mas rapido y agresivo) al recibir dano.
@export var slime_3_scene: PackedScene = preload("res://Entities/Enemies/slimes/slime_3.tscn")
## Torreta que escupe semillas; no se mueve.
@export var plant_scene: PackedScene = preload("res://Entities/Enemies/plants/plant_spitter.tscn")

@export_group("Jefes")
@export var plant_queen_scene: PackedScene = preload("res://Entities/Bosses/plant_queen.tscn")
@export var vampire_count_scene: PackedScene = preload("res://Entities/Bosses/vampire_count.tscn")
## Segundos entre el aviso de la oleada de jefe y su aparicion.
@export var boss_entry_delay: float = 2.2
## En modo infinito aparece un jefe cada tantos escalones.
@export var endless_boss_every: int = 3

@export_group("Generacion")
## Rectangulo (en coordenadas globales) donde pueden aparecer.
@export var spawn_area: Rect2 = Rect2(64, 64, 1024, 520)
## Distancia minima al jugador para no aparecer encima de el.
@export var min_distance_to_player: float = 220.0
## Escala aplicada a cada enemigo generado.
@export var enemy_scale: Vector2 = Vector2(2.8, 2.8)
## Total de enemigos a generar en toda la partida. -1 = infinito.
@export var total_to_spawn: int = -1

@export_group("Oleadas")
## Si se deja vacio se usan las oleadas por defecto definidas en el codigo.
@export var waves: Array[WaveConfig] = []
## Cuanto se refuerzan los enemigos por cada escalon del modo infinito.
@export var endless_growth: float = 1.12

@onready var _timer: Timer = $SpawnTimer

var _player: Node2D = null
var _spawned_total: int = 0
var _kills: int = 0
var _kills_this_wave: int = 0
var _wave_index: int = 0
var _endless_level: int = 0
var _boss_alive: bool = false

## Rectangulos ocupados por obstaculos en la sala actual (los pone la arena).
var blocked_rects: Array[Rect2] = []
## Mientras es false no sale nadie (p. ej. durante la transicion de sala).
var active: bool = true
var _spawned_this_room: int = 0
var _pending: int = 0
var _room_cleared: bool = false
var _room_boss: PackedScene = null


func _ready() -> void:
	randomize()
	_player = get_tree().get_first_node_in_group("Player")

	if waves.is_empty():
		waves = _default_waves()

	_timer.one_shot = false
	if not _timer.timeout.is_connected(_on_spawn_timer_timeout):
		_timer.timeout.connect(_on_spawn_timer_timeout)

	_start_room()
	_timer.start()
	# Se avisa del estado inicial en el proximo frame, cuando el HUD ya escucha.
	call_deferred("_announce_wave")


func _default_waves() -> Array[WaveConfig]:
	var list: Array[WaveConfig] = []
	list.append(WaveConfig.create(
		"Sala 1 - Orcos", 6,
		[orc_scene], [1.0],
		2.0, 6
	))
	list.append(WaveConfig.create(
		"Sala 2 - Llegan los vampiros", 8,
		[orc_scene, vampire_1_scene], [1.0, 1.2],
		2.1, 5,
		1.05
	))
	list.append(WaveConfig.create(
		"Sala 3 - Lava viviente", 9,
		[orc_scene, slime_3_scene], [1.5, 2.0],
		1.8, 8,
		1.2, 1.1
	))
	list.append(_boss_wave("Sala 4 - JEFE: Reina Carnivora", plant_queen_scene, 1))
	list.append(_with_biome(WaveConfig.create(
		"Sala 5 - Jardin maldito", 10,
		[orc_scene, plant_scene, slime_3_scene], [2.0, 1.5, 1.5],
		1.6, 9,
		1.3, 1.15, 1.05
	), 1))
	list.append(_with_biome(WaveConfig.create(
		"Sala 6 - Aquelarre", 10,
		[orc_scene, vampire_1_scene, vampire_2_scene, slime_3_scene], [2.0, 2.0, 1.0, 1.5],
		1.6, 9,
		1.4, 1.2, 1.05
	), 2))
	list.append(_with_biome(WaveConfig.create(
		"Sala 7 - Nobleza vampirica", 12,
		[orc_scene, vampire_1_scene, vampire_2_scene, vampire_3_scene, slime_3_scene], [1.0, 1.0, 2.0, 1.0, 1.5],
		1.5, 10,
		1.6, 1.3, 1.1
	), 2))
	list.append(_boss_wave("Sala 8 - JEFE: Conde Vampiro", vampire_count_scene, 2))
	list.append(_with_biome(WaveConfig.create(
		"Sala 9 - Pesadilla", 14,
		[orc_scene, vampire_2_scene, vampire_3_scene, slime_3_scene, plant_scene], [1.0, 2.0, 2.0, 2.0, 1.0],
		1.25, 12,
		2.0, 1.5, 1.15
	), 3))
	return list


func _with_biome(wave: WaveConfig, biome: int) -> WaveConfig:
	wave.biome = biome
	return wave


func _boss_wave(title: String, boss: PackedScene, biome: int) -> WaveConfig:
	var wave := WaveConfig.create(title, 1, [], [], 2.0, 0)
	wave.boss_scene = boss
	wave.biome = biome
	return wave


func current_wave() -> WaveConfig:
	if waves.is_empty():
		return null
	return waves[clampi(_wave_index, 0, waves.size() - 1)]


func wave_label() -> String:
	var wave := current_wave()
	if wave == null:
		return ""
	if _endless_level > 0:
		return "%s +%d" % [wave.display_name, _endless_level]
	return wave.display_name


# --- Generacion ---------------------------------------------------------

func _on_spawn_timer_timeout() -> void:
	if not active or _boss_alive or _room_boss != null or _room_cleared:
		return
	var wave := current_wave()
	if wave == null:
		return
	if _spawned_this_room + _pending >= wave.kills_to_advance:
		# Ya salio todo el cupo: solo queda esperar a que mueran.
		_check_room_clear()
		return
	if total_to_spawn >= 0 and _spawned_total >= total_to_spawn:
		return
	if _alive_enemies() + _pending >= wave.max_alive:
		return
	_spawn_one(wave)


func _alive_enemies() -> int:
	return get_tree().get_nodes_in_group("Enemy").size()


func _spawn_one(wave: WaveConfig) -> void:
	var scene := _pick_scene(wave)
	if scene == null:
		return

	# Marca de aviso en el suelo antes de que aparezca el enemigo.
	_pending += 1
	var pos := _pick_spawn_position()
	var marker := SpawnMarker.new()
	marker.position = pos
	add_child(marker)
	await get_tree().create_timer(SpawnMarker.DURATION, false).timeout
	if not is_inside_tree():
		return
	_pending -= 1
	if not active:
		return

	var enemy: Node2D = scene.instantiate()
	enemy.scale = enemy_scale
	_apply_wave_stats(enemy, wave)
	if enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died)

	add_child(enemy)
	enemy.global_position = pos
	_spawned_total += 1
	_spawned_this_room += 1


## Circulo rojo que se cierra en el suelo donde va a salir un enemigo.
class SpawnMarker extends Node2D:
	const DURATION := 0.7
	var _t: float = 0.0

	func _ready() -> void:
		z_index = 2
		var tween := create_tween()
		tween.tween_property(self, "_t", 1.0, DURATION)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		var r := lerpf(46.0, 14.0, _t)
		draw_circle(Vector2.ZERO, 22.0, Color(0.9, 0.1, 0.15, 0.25 * _t))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 0.25, 0.25, 0.4 + 0.6 * _t), 3.0)


func _pick_scene(wave: WaveConfig) -> PackedScene:
	if wave.enemy_scenes.is_empty():
		return null
	if wave.weights.size() != wave.enemy_scenes.size():
		return wave.enemy_scenes[randi() % wave.enemy_scenes.size()]

	var total := 0.0
	for w in wave.weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return wave.enemy_scenes[0]

	var roll := randf() * total
	var acc := 0.0
	for i in wave.enemy_scenes.size():
		acc += maxf(wave.weights[i], 0.0)
		if roll <= acc:
			return wave.enemy_scenes[i]
	return wave.enemy_scenes[wave.enemy_scenes.size() - 1]


## Aplica los multiplicadores de la oleada sobre las estadisticas base del
## enemigo. Debe llamarse ANTES de add_child(), porque _ready() del enemigo
## usa max_health para construir su barra de vida.
func _apply_wave_stats(enemy: Node, wave: WaveConfig) -> void:
	var boost: float = pow(endless_growth, _endless_level)

	_scale_stat(enemy, "max_health", wave.health_multiplier * boost)
	_scale_stat(enemy, "attack_damage", wave.damage_multiplier * boost)
	_scale_stat(enemy, "speed", wave.speed_multiplier)

	# El enemigo nace con la vida llena ya reforzada.
	if "max_health" in enemy and "health" in enemy:
		enemy.set("health", enemy.get("max_health"))


func _scale_stat(enemy: Node, property: String, factor: float) -> void:
	if not (property in enemy):
		return
	enemy.set(property, float(enemy.get(property)) * factor)


func _pick_spawn_position() -> Vector2:
	for i in 16:
		var candidate := Vector2(
			randf_range(spawn_area.position.x, spawn_area.end.x),
			randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if RoomBuilder.is_blocked(candidate, blocked_rects, 30.0):
			continue
		if _player == null or not is_instance_valid(_player):
			return candidate
		if candidate.distance_to(_player.global_position) >= min_distance_to_player:
			return candidate
	return RoomBuilder.free_point(spawn_area.get_center(), blocked_rects)


# --- Jefes -------------------------------------------------------------

func is_boss_alive() -> bool:
	return _boss_alive


func _spawn_boss(scene: PackedScene, wave: WaveConfig) -> void:
	if scene == null:
		return
	_boss_alive = true
	await get_tree().create_timer(boss_entry_delay, false).timeout
	if not is_inside_tree():
		return
	var boss: Node2D = scene.instantiate()
	_apply_wave_stats(boss, wave)
	if "arena_rect" in boss:
		boss.set("arena_rect", spawn_area)
	boss.connect("died", _on_boss_died)
	add_child(boss)
	boss.global_position = _pick_boss_position()
	boss_spawned.emit(boss)


## Lo mas lejos posible del jugador, dentro de la zona de juego.
func _pick_boss_position() -> Vector2:
	var center := spawn_area.get_center()
	if _player == null or not is_instance_valid(_player):
		return center
	var away := center - _player.global_position
	if away.length() < 1.0:
		away = Vector2.UP
	var pos := center + away.normalized() * 200.0
	return Vector2(
		clampf(pos.x, spawn_area.position.x + 60, spawn_area.end.x - 60),
		clampf(pos.y, spawn_area.position.y + 60, spawn_area.end.y - 60)
	)


func _on_boss_died() -> void:
	_boss_alive = false
	_room_boss = null
	_kills += 1
	kills_changed.emit(_kills)
	boss_defeated.emit()
	# Sus esbirros caen con el.
	for minion in get_tree().get_nodes_in_group("Minion"):
		if is_instance_valid(minion) and minion.has_method("hurt") and not minion.get("is_dead"):
			minion.hurt(999999.0)
	await get_tree().create_timer(1.5, false).timeout
	if is_inside_tree() and not _room_cleared:
		_room_cleared = true
		room_cleared.emit()


func room_has_boss() -> bool:
	return _room_boss != null


# --- Progresion de salas ------------------------------------------------

func _on_enemy_died() -> void:
	_kills += 1
	_kills_this_wave += 1
	kills_changed.emit(_kills)
	# Diferido: el enemigo todavia esta saliendo del arbol.
	call_deferred("_check_room_clear")


func _check_room_clear() -> void:
	if _room_cleared or _room_boss != null or _boss_alive:
		return
	var wave := current_wave()
	if wave == null:
		return
	if _spawned_this_room >= wave.kills_to_advance and _pending == 0 and _alive_enemies() == 0:
		_room_cleared = true
		room_cleared.emit()


## Pasa a la siguiente sala (lo llama la arena al cruzar el portal).
func next_room() -> void:
	if _wave_index < waves.size() - 1:
		_wave_index += 1
	else:
		# Ya no quedan salas nuevas: modo infinito, todo mas duro.
		_endless_level += 1
	_start_room()
	_announce_wave()


func _start_room() -> void:
	_kills_this_wave = 0
	_spawned_this_room = 0
	_room_cleared = false
	var wave := current_wave()
	if wave == null:
		return
	_timer.wait_time = wave.spawn_interval

	_room_boss = wave.boss_scene
	# Modo infinito: cada pocos escalones vuelve un jefe, cada vez mas duro.
	if _room_boss == null and _endless_level > 0 and _endless_level % endless_boss_every == 0:
		var bosses: Array[PackedScene] = [plant_queen_scene, vampire_count_scene]
		_room_boss = bosses[(_endless_level / endless_boss_every - 1) % bosses.size()]
	if _room_boss != null:
		_spawn_boss(_room_boss, wave)


func _announce_wave() -> void:
	wave_changed.emit(_wave_index, wave_label(), _endless_level)
	kills_changed.emit(_kills)
