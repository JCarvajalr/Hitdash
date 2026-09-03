class_name MainCharacter
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died

@export var speed: float = 200.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var attack_damage: float = 35
@export var max_health: float = 100.0
## Segundos de invulnerabilidad tras recibir un golpe.
@export var invulnerable_time: float = 0.6

@onready var character_sprite: AnimatedSprite2D = $CharacterSprite
@onready var attack_hitbox: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var dash_effect: AnimatedSprite2D = $DashEffect

var last_direction := Vector2.DOWN
var last_direction_label = "down"

var can_dash: bool = true
var is_dashing: bool = false
var is_attacking: bool = false

var health: float
var is_dead: bool = false
var is_invulnerable: bool = false

func _ready() -> void:
	attack_hitbox.disabled = true
	health = max_health
	health_changed.emit(health, max_health)

func _physics_process(delta):
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	update_dir()
	update_animation(direction)
	# Guardar la última dirección en la que se movió
	if direction != Vector2.ZERO:
		last_direction = direction
	
	# Movimiento normal
	if not is_dashing:
		velocity = direction * speed

	# Intentar hacer dash
	if Input.is_action_just_pressed("dash") and can_dash:
		start_dash()
	if Input.is_action_just_pressed("attack") and !is_attacking:
		start_attack()

	move_and_slide()

func start_attack():
	is_attacking = true
	attack_hitbox.disabled = false
	character_sprite.play("attack_" + last_direction_label)
	await (character_sprite.animation_finished)
	attack_hitbox.disabled = true
	is_attacking = false

func start_dash():
	is_dashing = true
	can_dash = false
	dash_effect.play("smoke")
	# Dash hacia la última dirección
	velocity = last_direction * dash_speed

	# Duración del dash
	await get_tree().create_timer(dash_duration).timeout

	is_dashing = false

	# Cooldown
	await get_tree().create_timer(dash_cooldown).timeout

	can_dash = true
	
func update_dir():
	var dir = []
	if (last_direction.x != 0):
		if (last_direction.x > 0):
			dir.append("right")
			attack_hitbox.position = Vector2(9, 0)
		else:
			dir.append("left")
			attack_hitbox.position = Vector2(-8, 0)
	elif (last_direction.y != 0):
		if (last_direction.y > 0):
			dir.append("down")
			attack_hitbox.position = Vector2(1, 9)
		else:
			dir.append("up")
			attack_hitbox.position = Vector2(-1, -5)
			
	last_direction_label = dir[0]

func update_animation(direction):
	if (is_attacking): return
	if (direction == Vector2.ZERO):
		character_sprite.play("idle_" + last_direction_label)
	else:
		character_sprite.play("run_" + last_direction_label)


func _on_attack_area_body_entered(body) -> void:
	if body.has_method("hurt"):
		body.hurt(attack_damage)

func hurt(damage: float) -> void:
	if is_dead or is_invulnerable:
		return
	health = max(health - damage, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		die()
		return
	_flash_damage()
	#is_invulnerable = true
	#await get_tree().create_timer(invulnerable_time).timeout
	#is_invulnerable = false

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(character_sprite, "modulate", Color(1, 0.35, 0.35), 0.2)
	tween.tween_property(character_sprite, "modulate", Color.WHITE, 0.22)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	is_attacking = false
	is_dashing = false
	attack_hitbox.set_deferred("disabled", true)
	character_sprite.modulate = Color.WHITE
	character_sprite.play("death_" + last_direction_label)
	await character_sprite.animation_finished
	died.emit()
	
