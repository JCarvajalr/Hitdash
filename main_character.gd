extends CharacterBody2D

@export var speed: float = 200.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: CollisionShape2D = $AttackArea/CollisionShape2D

var last_direction := Vector2.DOWN
var last_direction_label = "down"

var can_dash: bool = true
var is_dashing: bool = false
var is_attacking: bool = false

func _ready() -> void:
	attack_hitbox.disabled = true

func _physics_process(delta):
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
	animated_sprite_2d.play("attack_" + last_direction_label)
	await (animated_sprite_2d.animation_finished)
	attack_hitbox.disabled = true
	is_attacking = false

func start_dash():
	is_dashing = true
	can_dash = false

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
		animated_sprite_2d.play("idle_" + last_direction_label)
	else:
		animated_sprite_2d.play("run_" + last_direction_label)


func _on_attack_area_body_entered(body: Node2D) -> void:
	print(body.name)
	pass # Replace with function body.
