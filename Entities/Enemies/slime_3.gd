extends CharacterBody2D

signal died

@export var health: float
@export var max_health: float = 100.0
@export var attack_damage: float
@export var speed: float = 120.0
@export var stop_distance: float = 80.0
## Distancia a la que el slime deja de acercarse y se detiene (modo normal).
@export var comfort_distance: float = 120.0
## Segundos que el slime se mueve hacia el jugador antes de detenerse (modo normal).
@export var approach_time: float = 1.2
## Segundos que el slime se queda quieto antes de volver a moverse (modo normal).
@export var rest_time: float = 1.5

## Cooldown normal entre ataques en segundos.
@export var normal_attack_cooldown: float = 2.0

## --- Modo Furia (Enrage) ---
## Velocidad del slime cuando se enfurece tras recibir daño.
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

## Estado de movimiento del slime: alterna entre acercarse y descansar.
enum MoveState { APPROACHING, RESTING }
var _move_state: MoveState = MoveState.APPROACHING
var _state_timer: float = 0.0

func _ready() -> void:
	add_to_group("Enemy")
	player = get_tree().get_first_node_in_group("Player")
	character_sprite.frame_changed.connect(_on_frame_changed)
	attack_area.body_entered.connect(_on_attack_area_body_entered)

	if health <= 0.0:
		health = max_health
	max_health = max(max_health, health)
	_build_health_bar()

	# Empezar en un estado aleatorio para que no todos se muevan a la vez.
	_state_timer = randf_range(0.0, approach_time)

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

	var dist_to_player := global_position.distance_to(player.global_position)
	var dir_to_player = (player.global_position - global_position).normalized()

	# Actualizar la dirección visual hacia el jugador siempre.
	if dir_to_player != Vector2.ZERO:
		last_direction = dir_to_player

	# Si está lo suficientemente cerca, atacar.
	if dist_to_player <= stop_distance and !is_attacking:
		start_attack()

	var direction := Vector2.ZERO

	if !is_attacking:
		if is_enraged:
			# En modo furia: persigue directamente al jugador sin pausas ni descansos
			direction = dir_to_player
		else:
			# Movimiento tipo "lunge": se acerca por periodos y luego descansa.
			_state_timer += delta
			match _move_state:
				MoveState.APPROACHING:
					# Solo moverse si está más lejos que la distancia cómoda.
					if dist_to_player > comfort_distance:
						direction = dir_to_player
					else:
						# Ya está cerca, descansar.
						direction = Vector2.ZERO
					if _state_timer >= approach_time:
						_state_timer = 0.0
						_move_state = MoveState.RESTING
				MoveState.RESTING:
					direction = Vector2.ZERO
					if _state_timer >= rest_time:
						_state_timer = 0.0
						_move_state = MoveState.APPROACHING

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
	if !can_attack or is_dead:
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

	# Activar o reiniciar estado de furia
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
