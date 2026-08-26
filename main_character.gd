extends CharacterBody2D

@export var speed: float = 200.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var last_direction := Vector2.DOWN

var can_dash: bool = true
var is_dashing: bool = false


func _physics_process(delta):
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

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

	move_and_slide()

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
	
func update_animation(direction):
	var dir = []
	if (last_direction.x != 0):
		if (last_direction.x > 0):
			dir.append("right")
		else:
			dir.append("left")
	elif (last_direction.y != 0):
		if (last_direction.y > 0):
			dir.append("down")
		else:
			dir.append("up")
	if (direction == Vector2.ZERO):
		animated_sprite_2d.play("idle_" + dir[0])
	else:
		animated_sprite_2d.play("run_" + dir[0])
