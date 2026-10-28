extends Node2D
## Escena de combate: conecta al jugador con el HUD, el generador
## de enemigos, la pantalla de Game Over y el menu de pausa. Tambien
## crea la camara que usa Combat para el temblor de pantalla, gestiona
## los escenarios (biomas), la musica y el botin.
##
## El juego va por salas: al despejar una aparecen un cofre y un portal;
## al cruzar el portal se genera una sala nueva con otra distribucion.

const PauseMenu := preload("res://Scenes/pause_menu.gd")
const HealOrb := preload("res://Entities/Pickups/heal_orb.gd")
const DeathEffect := preload("res://Entities/Effects/death_effect.gd")
const Portal := preload("res://Scenes/rooms/portal.gd")
const Chest := preload("res://Entities/Pickups/chest.gd")
const ItemPickup := preload("res://Entities/Pickups/item_pickup.gd")

## Escenarios por los que pasa la arena segun la oleada (WaveConfig.biome).
const BIOMES := [
	{
		"name": "Mazmorra",
		"floor": preload("res://sprites/background/floor_bricks.png"),
		"tint": Color(1.0, 1.0, 1.0),
		"particles": Color(0.85, 0.85, 0.8, 0.35),
		"gravity": -6.0,
		"props": "dungeon",
		"flame": Color(1.0, 0.6, 0.25),
		"stone": Color(0.46, 0.45, 0.5),
		"accent": Color(0.66, 0.64, 0.7),
	},
	{
		"name": "Invernadero maldito",
		"floor": preload("res://sprites/background/floor_bricks.png"),
		"tint": Color(0.78, 0.95, 0.75),
		"particles": Color(0.6, 1.0, 0.35, 0.6),
		"gravity": -12.0,
		"props": "garden",
		"flame": Color(1.0, 0.85, 0.4),
		"stone": Color(0.36, 0.46, 0.34),
		"accent": Color(0.45, 0.68, 0.35),
	},
	{
		"name": "Castillo carmesi",
		"floor": preload("res://sprites/background/floor_bricks_castle.png"),
		"tint": Color(1.0, 0.86, 0.84),
		"particles": Color(1.0, 0.5, 0.2, 0.8),
		"gravity": -40.0,
		"props": "castle",
		"flame": Color(1.0, 0.5, 0.2),
		"stone": Color(0.5, 0.2, 0.2),
		"accent": Color(0.85, 0.65, 0.35),
	},
	{
		"name": "Abismo",
		"floor": preload("res://sprites/background/floor_bricks_castle.png"),
		"tint": Color(0.72, 0.64, 1.0),
		"particles": Color(0.8, 0.4, 1.0, 0.7),
		"gravity": -25.0,
		"props": "abyss",
		"flame": Color(0.75, 0.4, 1.0),
		"stone": Color(0.3, 0.24, 0.42),
		"accent": Color(0.7, 0.45, 1.0),
	},
]

## Probabilidad de que un enemigo normal suelte un orbe de vida.
@export var heal_drop_chance: float = 0.12
## Orbes que suelta un jefe al morir.
@export var boss_heal_orbs: int = 6

@onready var hud = $HUD
@onready var game_over_screen = $GameOverScreen
@onready var spawner = $EnemySpawner
@onready var floor_sprite: Sprite2D = $FloorBricks

var player: MainCharacter = null

var _biome: int = -1
var _floor_size: Vector2
var _tint: CanvasModulate
var _particles: CPUParticles2D
var _camera: Camera2D

var _room: Node2D
var _room_count: int = 0
var _transitioning: bool = false
var _fade: ColorRect
var _player_scale := Vector2.ONE
var _nav_region: NavigationRegion2D


func _ready() -> void:
	Combat.reset_run()
	_setup_camera()
	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.game_over_screen = game_over_screen
	add_child(pause_menu)
	_setup_atmosphere()
	_set_biome(0, false)
	Sfx.play_music("main")

	Combat.enemy_killed.connect(_on_enemy_killed)
	spawner.wave_changed.connect(_on_wave_changed)
	spawner.boss_spawned.connect(_on_boss_spawned)
	spawner.boss_defeated.connect(_on_boss_defeated)
	spawner.room_cleared.connect(_on_room_cleared)
	# Enemigos, pilares y cajas se ordenan entre si por profundidad.
	spawner.y_sort_enabled = true
	_setup_fade()
	_nav_region = NavigationRegion2D.new()
	add_child(_nav_region)

	spawner.wave_changed.connect(hud.update_wave)
	spawner.kills_changed.connect(hud.update_kills)

	player = _find_player()
	if player == null:
		push_warning("Arena: no se encontro al MainCharacter en el grupo 'Player'.")
		return

	player.health_changed.connect(hud.update_health)
	player.died.connect(_on_player_died)
	player.death_started.connect(_on_player_death_started)
	_player_scale = player.scale
	hud.setup_inventory(player)
	_build_room()

	# Estado inicial del HUD (la senal inicial del jugador ya se
	# emitio antes de conectar, por eso lo inicializamos a mano).
	hud.setup(player.max_health)


## Camara fija con la misma vista que la ventana; solo existe para temblar.
func _setup_camera() -> void:
	var camera := Camera2D.new()
	camera.name = "ShakeCamera"
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()
	Combat.register_camera(camera)
	_camera = camera


# --- Escenarios ---------------------------------------------------------

func _setup_atmosphere() -> void:
	_floor_size = floor_sprite.texture.get_size() * floor_sprite.scale

	_tint = CanvasModulate.new()
	add_child(_tint)

	# Particulas de ambiente (polvo, esporas, brasas...) sobre toda la arena.
	_particles = CPUParticles2D.new()
	_particles.z_index = 20
	_particles.amount = 45
	_particles.lifetime = 7.0
	_particles.preprocess = 7.0
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(620, 360)
	_particles.position = Vector2(576, 324)
	_particles.direction = Vector2(0, -1)
	_particles.spread = 180.0
	_particles.initial_velocity_min = 4.0
	_particles.initial_velocity_max = 16.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 3.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	_particles.color_ramp = fade
	add_child(_particles)


func _set_biome(index: int, animated: bool = true) -> void:
	index = clampi(index, 0, BIOMES.size() - 1)
	if index == _biome:
		return
	_biome = index
	var biome: Dictionary = BIOMES[index]
	if not animated:
		_apply_biome(biome)
		return
	# Fundido a negro, cambio de escenario y vuelta.
	var tween := create_tween()
	tween.tween_property(_tint, "color", Color(0.05, 0.05, 0.08), 0.5)
	tween.tween_callback(_apply_biome.bind(biome, false))
	tween.tween_property(_tint, "color", biome["tint"], 0.8)


func _apply_biome(biome: Dictionary, set_tint: bool = true) -> void:
	var tex: Texture2D = biome["floor"]
	floor_sprite.texture = tex
	floor_sprite.scale = _floor_size / tex.get_size()
	if set_tint:
		_tint.color = biome["tint"]
	_particles.color = biome["particles"]
	_particles.gravity = Vector2(0, biome["gravity"])


func _on_wave_changed(index: int, _display_name: String, _endless_level: int) -> void:
	var wave = spawner.current_wave()
	if wave != null:
		# Durante la transicion la pantalla ya esta en negro: cambio directo.
		_set_biome(wave.biome, not _transitioning)
	if index > 0:
		Sfx.play("wave", 0.0)


# --- Jefes, botin y musica ----------------------------------------------

func _on_boss_spawned(boss: Node) -> void:
	hud.show_boss(boss)
	Sfx.play_music("boss")


func _on_boss_defeated() -> void:
	hud.hide_boss()
	Sfx.play_music("main")


func _on_enemy_killed(pos: Vector2, is_boss: bool) -> void:
	var count := boss_heal_orbs if is_boss else (1 if randf() < heal_drop_chance else 0)
	for i in count:
		var orb := HealOrb.new()
		orb.position = pos
		call_deferred("add_child", orb)
	# Los jefes siempre sueltan un arma nueva.
	if is_boss:
		var weapon := ItemPickup.new()
		weapon.kind = "weapon"
		weapon.item_id = Items.random_weapon(player.weapon_id if player != null else "")
		weapon.position = RoomBuilder.free_point(pos.clamp(RoomBuilder.PLAY_AREA.position, RoomBuilder.PLAY_AREA.end), spawner.blocked_rects)
		call_deferred("add_child", weapon)


# --- Salas y portal -----------------------------------------------------

func _setup_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


## Genera la distribucion de la sala actual (vacia si toca jefe).
func _build_room() -> void:
	if _room != null:
		_room.queue_free()
	_room = Node2D.new()
	_room.name = "Room"
	_room.y_sort_enabled = true
	add_child(_room)
	var layout := "empty"
	if not spawner.room_has_boss():
		# La primera sala siempre igual, para empezar tranquilo.
		layout = "four" if _room_count == 0 else RoomBuilder.random_layout()
	spawner.blocked_rects = RoomBuilder.build(_room, layout, BIOMES[maxi(_biome, 0)])
	# Mapa de navegacion para que los enemigos rodeen pilares y cajas.
	Pathing.bake_room(_nav_region, RoomBuilder.PLAY_AREA.grow(30), spawner.blocked_rects)
	for child in _room.get_children():
		if child.get("is_prop"):
			child.tree_exiting.connect(_on_prop_broken.bind(child, _room))
	_room_count += 1


## Al romper una caja se libera su hueco en el mapa de navegacion.
func _on_prop_broken(prop: Node, room: Node) -> void:
	if room != _room or not prop.get("is_dead"):
		return
	spawner.blocked_rects.erase(prop.footprint())
	Pathing.bake_room(_nav_region, RoomBuilder.PLAY_AREA.grow(30), spawner.blocked_rects)


func _on_room_cleared() -> void:
	hud.show_message("¡SALA DESPEJADA!")
	Sfx.play("rank_up", 0.0)

	var chest := Chest.new()
	# El primer cofre siempre trae un arma, para que se note el sistema.
	if _room_count == 1:
		chest.forced_kind = "weapon"
	# A un lado del portal, para que el arma que suelta no tape su letrero.
	# Se evita tambien lo alto de las columnas, no solo su base.
	var tall: Array[Rect2] = []
	for rect in spawner.blocked_rects:
		tall.append(Rect2(rect.position.x, rect.position.y - 130, rect.size.x, rect.size.y + 130))
	chest.position = RoomBuilder.free_point(Vector2(760, 360), tall)
	add_child(chest)

	var portal := Portal.new()
	portal.color = BIOMES[maxi(_biome, 0)]["accent"]
	portal.position = RoomBuilder.free_point(Vector2(576, 360), spawner.blocked_rects)
	portal.entered.connect(_enter_portal.bind(portal))
	add_child(portal)


func _enter_portal(portal: Node2D) -> void:
	if _transitioning or player == null or player.is_dead:
		return
	_transitioning = true
	spawner.active = false
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.is_invulnerable = true

	# El portal se traga al jugador y la pantalla se va a negro.
	var suck := create_tween().set_parallel(true)
	suck.tween_property(player, "global_position", portal.global_position + Vector2(0, -20), 0.3)
	suck.tween_property(player, "scale", _player_scale * 0.15, 0.3)
	suck.tween_property(player, "rotation", TAU, 0.3)
	# Destello del color del portal y luego negro.
	var flash_color: Color = portal.get("color") if portal.get("color") != null else Color.WHITE
	_fade.color = Color(flash_color.lightened(0.6), 0.0)
	suck.tween_property(_fade, "color:a", 1.0, 0.3)
	await suck.finished
	var to_black := create_tween()
	to_black.tween_property(_fade, "color", Color(0, 0, 0, 1), 0.2)
	await to_black.finished
	await get_tree().create_timer(0.15).timeout

	# Limpiar la sala vieja.
	for node in get_tree().get_nodes_in_group("Pickup"):
		node.queue_free()
	for child in spawner.get_children():
		if child is MagicBolt:
			child.queue_free()

	spawner.next_room()
	_build_room()
	player.global_position = RoomBuilder.ENTRY_POINT
	player.scale = _player_scale
	player.rotation = 0.0
	player.last_direction = Vector2.RIGHT

	var reveal := create_tween()
	reveal.tween_property(_fade, "color:a", 0.0, 0.45)
	await reveal.finished
	player.set_physics_process(true)
	player.is_invulnerable = false
	await get_tree().create_timer(0.5).timeout
	spawner.active = true
	_transitioning = false


func _find_player() -> MainCharacter:
	for node in get_tree().get_nodes_in_group("Player"):
		if node is MainCharacter:
			return node
	return null


func _on_player_death_started() -> void:
	Sfx.stop_music()
	hud.fade_out()
	var effect := DeathEffect.new()
	add_child(effect)
	effect.play(player, _camera)


func _on_player_died() -> void:
	game_over_screen.show_screen(spawner.wave_label())
