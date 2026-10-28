extends CharacterBody2D
## Planta escupidora: torreta inmovil que lanza semillas al jugador.
## Aguanta poco, pero en grupo cubre el mapa de fuego cruzado y obliga
## a moverse. La invoca la Reina Carnivora y aparece en oleadas tardias.

signal died

const SEED_COLOR := Color(0.55, 1.0, 0.35)

@export var health: float = 0.0
@export var max_health: float = 60.0
@export var attack_damage: float = 10.0
## No se mueve, pero el spawner escala "speed": se usa como ritmo de disparo.
@export var speed: float = 1.0
@export var attack_range: float = 520.0
@export var attack_cooldown: float = 2.4
@export var projectile_speed: float = 230.0
@export var projectile_scene: PackedScene = preload("res://Entities/Projectiles/magic_bolt.tscn")
## Frame de la animacion de ataque en el que sale la semilla.
@export var spit_frame: int = 4

var player: Node2D
var is_dead: bool = false
var is_attacking: bool = false
var _cooldown: float = 0.0
var _has_spat: bool = false
var _aim := Vector2.DOWN
var _sprite: AnimatedSprite2D
var _health_bar: ProgressBar


func _ready() -> void:
	add_to_group("Enemy")
	collision_layer = 9
	collision_mask = 2
	player = get_tree().get_first_node_in_group("Player")
	if health <= 0.0:
		health = max_health
	max_health = max(max_health, health)
	_cooldown = randf_range(0.8, attack_cooldown)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SpriteSheets.build({
		"idle": [preload("res://sprites/characters/plantmob/plant1_idle.png"), 6.0, true],
		"attack": [preload("res://sprites/characters/plantmob/plant1_attack.png"), 12.0, false],
		"death": [preload("res://sprites/characters/plantmob/plant1_death.png"), 12.0, false],
	})
	_sprite.play("idle_down")
	_sprite.frame_changed.connect(_on_frame_changed)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	shape.position = Vector2(0, 4)
	add_child(shape)

	_build_health_bar()


func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	if not is_attacking:
		_sprite.play("idle_" + SpriteSheets.direction_label(to_player))
	_cooldown -= delta * speed
	if _cooldown <= 0.0 and not is_attacking and to_player.length() <= attack_range:
		_attack(to_player.normalized())


func _attack(aim: Vector2) -> void:
	is_attacking = true
	_has_spat = false
	_aim = aim
	_sprite.play("attack_" + SpriteSheets.direction_label(aim))
	await _sprite.animation_finished
	if is_dead:
		return
	if not _has_spat:
		_spit()
	is_attacking = false
	_cooldown = attack_cooldown


func _on_frame_changed() -> void:
	if is_attacking and not _has_spat and not is_dead and _sprite.frame >= spit_frame:
		_spit()


func _spit() -> void:
	_has_spat = true
	if projectile_scene == null:
		return
	# Apunta a donde esta el jugador en el momento de escupir.
	if player != null and is_instance_valid(player):
		_aim = (player.global_position - global_position).normalized()
	var bolt := projectile_scene.instantiate()
	bolt.modulate = SEED_COLOR
	get_parent().add_child(bolt)
	bolt.global_position = global_position + _aim * 14.0
	if bolt is MagicBolt:
		(bolt as MagicBolt).setup(_aim, projectile_speed, attack_damage)
	Sfx.play("bolt", 0.15, -8.0)


func hurt(damage: float) -> void:
	if is_dead:
		return
	health = max(health - damage, 0.0)
	_health_bar.value = health
	_health_bar.visible = health < max_health
	if health <= 0.0:
		_die()
		return
	_sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		_sprite.modulate = Color.WHITE


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	remove_from_group("Enemy")
	died.emit()
	collision_layer = 0
	collision_mask = 0
	_health_bar.visible = false
	_sprite.modulate = Color.WHITE
	_sprite.play("death_" + SpriteSheets.direction_label(_aim))
	await _sprite.animation_finished
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	queue_free()


func _build_health_bar() -> void:
	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_bar.custom_minimum_size = Vector2(24, 4)
	_health_bar.size = Vector2(24, 4)
	_health_bar.position = Vector2(-12, -22)
	_health_bar.z_index = 100
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.4, 0.85, 0.3)
	_health_bar.add_theme_stylebox_override("background", bg)
	_health_bar.add_theme_stylebox_override("fill", fill)
	_health_bar.visible = false
	add_child(_health_bar)
