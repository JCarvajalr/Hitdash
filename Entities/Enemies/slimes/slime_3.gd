extends CharacterBody2D

signal died

@export var health: float
@export var max_health: float = 100.0
@export var attack_damage: float

## --- Comportamiento Pasivo / Paseo ---
## Velocidad del slime cuando pasea tranquilamente.
@export var speed: float = 70.0
## Distancia para atacar al jugador si se encuentra muy cerca.
@export var stop_distance: float = 65.0
## Tiempo mínimo que el slime camina en una dirección al pasear.
@export var wander_time_min: float = 1.0
## Tiempo máximo que el slime camina en una dirección al pasear.
@export var wander_time_max: float = 2.5
## Tiempo mínimo que el slime permanece quieto descansando.
@export var idle_time_min: float = 1.5
## Tiempo máximo que el slime permanece quieto descansando.
@export var idle_time_max: float = 3.5

## Cooldown normal entre ataques en segundos.
@export var normal_attack_cooldown: float = 2.0

## --- Modo Furia (Enrage) ---
## Velocidad del slime cuando se enfurece tras recibir daño y persigue al jugador.
@export var enraged_speed: float = 220.0
## Duración en segundos del estado de furia tras ser golpeado.
@export var enrage_duration: float = 6.0
## Cooldown reducido entre ataques durante el modo furia.
@export var enraged_attack_cooldown: float = 0.6
## Multiplicador de velocidad de animación del ataque en modo furia.
@export var enraged_attack_anim_speed: float = 1.75
## Tinte visual del sprite mientras está enfurecido.
@export var enraged_color: Color = Color(1.0, 0.45, 0.45)

@onready var character_sprite: AnimatedSprite2D = $CharacterSprite
@onready var restart_attack_timer: Timer = $RestartAttackTimer
@onready var attack_hitbox: CollisionShape2D = $AttackArea/AttackHitbox
@onready var attack_area: Area2D = $AttackArea
var player
var is_attacking: bool = false
var can_attack: bool = true
var is_dead: bool = false
var last_direction := Vector2.DOWN
var last_direction_label = "down"

var is_enraged: bool = false
var _enrage_timer: float = 0.0

var _health_bar: ProgressBar

## Estados del comportamiento pasivo: pasear o quedarse quieto
enum PassiveState { WANDERING, IDLE }
var _passive_state: PassiveState = PassiveState.IDLE
var _state_timer: float = 0.0
var _current_state_duration: float = 1.0
var _wander_direction := Vector2.ZERO

func _ready() -> void:
	add_to_group("Enemy")
	player = get_tree().get_first_node_in_group("Player")
	character_sprite.frame_changed.connect(_on_frame_changed)
	attack_area.body_entered.connect(_on_attack_area_body_entered)

	if health <= 0.0:
		health = max_health
	max_health = max(max_health, health)
	_build_health_bar()

	# Iniciar paseando en una dirección aleatoria con tiempo desfasado
	_set_passive_state(PassiveState.WANDERING)
	_state_timer = randf_range(0.0, _current_state_duration * 0.8)

func _set_passive_state(new_state: PassiveState) -> void:
	_passive_state = new_state
	_state_timer = 0.0
	if new_state == PassiveState.WANDERING:
		_current_state_duration = randf_range(wander_time_min, wander_time_max)
		# Elegir una dirección aleatoria en 2D
		var angle := randf_range(0.0, TAU)
		_wander_direction = Vector2.RIGHT.rotated(angle).normalized()
	else:
		_current_state_duration = randf_range(idle_time_min, idle_time_max)
		_wander_direction = Vector2.ZERO
		# Cada vez que se queda quieto, ataca al aire en la dirección hacia la que mira
		if !is_dead and !is_attacking:
			can_attack = true
			start_attack()

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
	fill.bg_color = Color(0.85, 0.2, 0.2)
	_health_bar.add_theme_stylebox_override("background", bg)
	_health_bar.add_theme_stylebox_override("fill", fill)

	_health_bar.visible = false
	add_child(_health_bar)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Control del temporizador de furia
	if is_enraged:
		_enrage_timer -= delta
		if _enrage_timer <= 0.0:
			is_enraged = false
			if not is_dead:
				character_sprite.modulate = Color.WHITE
			_set_passive_state(PassiveState.IDLE)

	var dist_to_player := global_position.distance_to(player.global_position)
	var dir_to_player = (player.global_position - global_position).normalized()

	# Si el jugador se acerca mientras el slime se mueve o en cualquier momento, atacar hacia el jugador
	if dist_to_player <= stop_distance and !is_attacking and can_attack:
		last_direction = dir_to_player
		update_dir()
		start_attack()

	var direction := Vector2.ZERO

	if !is_attacking:
		if is_enraged:
			# En modo furia: persigue directamente al jugador
			direction = dir_to_player
		else:
			# Modo pasivo: alterna entre pasear en una dirección y descansar
			_state_timer += delta
			if _state_timer >= _current_state_duration:
				if _passive_state == PassiveState.WANDERING:
					_set_passive_state(PassiveState.IDLE)
				else:
					_set_passive_state(PassiveState.WANDERING)

			direction = _wander_direction if _passive_state == PassiveState.WANDERING else Vector2.ZERO

		move(direction)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func move(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		last_direction = direction
	var current_speed: float = enraged_speed if is_enraged else speed
	velocity = direction * current_speed
	update_dir()
	update_animation(direction, current_speed)

func start_attack():
	if !can_attack or is_dead or is_attacking:
		return
	velocity = Vector2.ZERO
	is_attacking = true
	can_attack = false
	var anim_speed: float = enraged_attack_anim_speed if is_enraged else 1.0
	character_sprite.play("attack_" + last_direction_label, anim_speed)
	await character_sprite.animation_finished
	is_attacking = false
	var cooldown: float = enraged_attack_cooldown if is_enraged else normal_attack_cooldown
	restart_attack_timer.start(cooldown)

func hurt(damage: float) -> void:
	if is_dead:
		return
	health = max(health - damage, 0.0)
	_update_health_bar()
	if health <= 0.0:
		_die()
		return

	# Activar o reiniciar estado de furia al recibir daño
	is_enraged = true
	_enrage_timer = enrage_duration

	# Si el timer de ataque estaba esperando un cooldown largo, acortarlo al cooldown enfurecido
	if !restart_attack_timer.is_stopped() and restart_attack_timer.time_left > enraged_attack_cooldown:
		restart_attack_timer.start(enraged_attack_cooldown)

	character_sprite.modulate = Color(1.0, 0.2, 0.2)
	await get_tree().create_timer(0.1).timeout
	if !is_dead:
		character_sprite.modulate = enraged_color if is_enraged else Color.WHITE

func _update_health_bar() -> void:
	if _health_bar == null:
		return
	_health_bar.value = health
	_health_bar.visible = not is_dead and health < max_health

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	is_enraged = false
	died.emit()
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	attack_hitbox.set_deferred("disabled", true)
	if _health_bar != null:
		_health_bar.visible = false
	character_sprite.modulate = Color.WHITE
	character_sprite.play("death_" + last_direction_label)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	await tween.finished
	queue_free()

func _on_attack_area_body_entered(body) -> void:
	if is_dead:
		return
	if body.is_in_group("Player") and body.has_method("hurt"):
		body.hurt(attack_damage)

func update_dir():
	var dir = []
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			dir.append("right")
			attack_hitbox.position = Vector2(13, 0)
		else:
			dir.append("left")
			attack_hitbox.position = Vector2(-13, 0)
	elif abs(last_direction.y) > abs(last_direction.x):
		if last_direction.y > 0:
			dir.append("down")
			attack_hitbox.position = Vector2(0, 10)
		else:
			dir.append("up")
			attack_hitbox.position = Vector2(0, -15)
	if dir.is_empty():
		return
	last_direction_label = dir[0]

func update_animation(direction: Vector2, current_speed: float = speed) -> void:
	if is_attacking:
		return
	if direction == Vector2.ZERO:
		character_sprite.play("idle_" + last_direction_label)
	elif current_speed >= 180.0:
		character_sprite.play("run_" + last_direction_label)
	else:
		character_sprite.play("walk_" + last_direction_label)

func _on_frame_changed():
	if !is_attacking:
		return
	if character_sprite.frame == 4:
		attack_hitbox.disabled = false
	if character_sprite.frame == 7:
		attack_hitbox.disabled = true

func _on_restart_attack_timer_timeout() -> void:
	can_attack = true
