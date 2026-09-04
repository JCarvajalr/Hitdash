class_name Vampire
extends CharacterBody2D
## Enemigo a distancia. A diferencia del orco (que se pega al jugador y
## golpea cuerpo a cuerpo), el vampiro mantiene la distancia: se acerca
## solo hasta tenerte a tiro, retrocede si te le pegas demasiado, y lanza
## proyectiles magicos desde lejos.

signal died

@export_group("Vida y dano")
@export var health: float = 0.0
@export var max_health: float = 160.0
@export var attack_damage: float = 16.0

@export_group("Movimiento")
@export var speed: float = 95.0
## Distancia maxima a la que puede disparar: mas lejos, se acerca.
@export var attack_range: float = 360.0
## Si el jugador entra dentro de este radio, el vampiro retrocede (kiting).
@export var retreat_distance: float = 190.0

@export_group("Ataque a distancia")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
## Segundos de espera entre lanzamientos.
@export var attack_cooldown: float = 2.0
## Frame de la animacion "attack_" en el que sale el proyectil.
@export var cast_frame: int = 7
## Desplazamiento del proyectil respecto al centro del vampiro al nacer.
@export var muzzle_offset: float = 18.0

@onready var character_sprite: AnimatedSprite2D = $CharacterSprite
@onready var cooldown_timer: Timer = $CooldownTimer

var player: Node2D
var is_casting: bool = false
var can_attack: bool = true
var is_dead: bool = false
var last_direction := Vector2.DOWN
var last_direction_label := "down"

var _health_bar: ProgressBar
var _aim := Vector2.DOWN
var _has_fired: bool = false


func _ready() -> void:
	add_to_group("Enemy")
	player = get_tree().get_first_node_in_group("Player")
	character_sprite.frame_changed.connect(_on_frame_changed)

	if health <= 0.0:
		health = max_health
	max_health = max(max_health, health)

	cooldown_timer.wait_time = attack_cooldown
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)

	_build_health_bar()


func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	var direction := Vector2.ZERO

	if player != null and is_instance_valid(player):
		var to_player: Vector2 = player.global_position - global_position
		var distance := to_player.length()
		var aim := to_player.normalized() if distance > 0.0 else Vector2.DOWN

		if is_casting:
			# Mientras lanza el hechizo se queda quieto y mirando al jugador.
			direction = Vector2.ZERO
		elif distance > attack_range:
			direction = aim              # esta lejos: acercarse
		elif distance < retreat_distance:
			direction = -aim             # esta encima: retroceder (kiting)
		else:
			direction = Vector2.ZERO     # a tiro: quedarse y lanzar
			start_cast(aim)

	move(direction)
	move_and_slide()


func move(direction: Vector2) -> void:
	# Al retroceder sigue mirando al jugador, no hacia donde camina.
	if direction != Vector2.ZERO and not is_casting:
		last_direction = _facing_direction(direction)
	velocity = direction * speed
	update_dir()
	update_animation(direction)


func _facing_direction(direction: Vector2) -> Vector2:
	if player == null or not is_instance_valid(player):
		return direction
	var to_player: Vector2 = player.global_position - global_position
	return to_player.normalized() if to_player.length() > 0.0 else direction


func start_cast(aim: Vector2) -> void:
	if not can_attack or is_casting or is_dead:
		return
	is_casting = true
	can_attack = false
	_has_fired = false
	_aim = aim
	last_direction = aim
	update_dir()
	character_sprite.play("attack_" + last_direction_label)
	await character_sprite.animation_finished
	if is_dead:
		return
	# Red de seguridad: si el frame de lanzamiento no llego a dispararse.
	if not _has_fired:
		_fire_projectile()
	is_casting = false
	cooldown_timer.start()


func _on_frame_changed() -> void:
	if not is_casting or _has_fired or is_dead:
		return
	if character_sprite.frame >= cast_frame:
		_has_fired = true
		_fire_projectile()


func _fire_projectile() -> void:
	if projectile_scene == null or is_dead:
		return
	var bolt := projectile_scene.instantiate()
	get_parent().add_child(bolt)
	if bolt is Node2D:
		(bolt as Node2D).global_position = global_position + _aim * muzzle_offset
	if bolt is MagicBolt:
		(bolt as MagicBolt).setup(_aim, projectile_speed, attack_damage)


func _on_cooldown_timeout() -> void:
	can_attack = true


func hurt(damage) -> void:
	if is_dead:
		return
	health = max(health - damage, 0.0)
	_update_health_bar()
	if health <= 0.0:
		_die()
		return

	character_sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		character_sprite.modulate = Color.WHITE


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	is_casting = false
	# Fuera del grupo ya, para que el cadaver no cuente como enemigo vivo
	# mientras dura la animacion de muerte.
	remove_from_group("Enemy")
	died.emit()
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if _health_bar != null:
		_health_bar.visible = false
	character_sprite.modulate = Color.WHITE
	character_sprite.play("death_" + last_direction_label)
	await character_sprite.animation_finished
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished
	queue_free()


func update_dir() -> void:
	if abs(last_direction.x) >= abs(last_direction.y):
		last_direction_label = "right" if last_direction.x > 0 else "left"
	else:
		last_direction_label = "down" if last_direction.y > 0 else "up"


func update_animation(direction: Vector2) -> void:
	if is_casting or is_dead:
		return
	if direction == Vector2.ZERO:
		character_sprite.play("idle_" + last_direction_label)
	elif speed >= 140:
		character_sprite.play("run_" + last_direction_label)
	else:
		character_sprite.play("walk_" + last_direction_label)


func _build_health_bar() -> void:
	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.min_value = 0.0
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_bar.custom_minimum_size = Vector2(34, 5)
	_health_bar.size = Vector2(34, 5)
	_health_bar.position = Vector2(-17, -34)
	_health_bar.z_index = 100
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.65, 0.16, 0.75)
	_health_bar.add_theme_stylebox_override("background", bg)
	_health_bar.add_theme_stylebox_override("fill", fill)

	_health_bar.visible = false
	add_child(_health_bar)


func _update_health_bar() -> void:
	if _health_bar == null:
		return
	_health_bar.value = health
	_health_bar.visible = not is_dead and health < max_health
