extends CharacterBody2D

@export var speed: float = 200.0

@onready var character_sprite: AnimatedSprite2D = $CharacterSprite

var last_direction := Vector2.DOWN
var last_direction_label = "down"

func _physics_process(delta: float) -> void:
	pass
	#update_dir()
	#move_and_slide()

func move(direction):
	if (direction != Vector2.ZERO):
		last_direction = direction
	velocity = direction * speed
	pass
	

func update_dir():
	var dir = []
	if (last_direction.x != 0):
		if (last_direction.x > 0):
			dir.append("right")
			#attack_hitbox.position = Vector2(9, 0)
		else:
			dir.append("left")
			#attack_hitbox.position = Vector2(-8, 0)
	elif (last_direction.y != 0):
		if (last_direction.y > 0):
			dir.append("down")
			#attack_hitbox.position = Vector2(1, 9)
		else:
			dir.append("up")
			#attack_hitbox.position = Vector2(-1, -5)
			
	last_direction_label = dir[0]

func update_animation(direction):
	#if (is_attacking): return
	if (direction == Vector2.ZERO):
		character_sprite.play("idle_" + last_direction_label)
	else:
		character_sprite.play("run_" + last_direction_label)	
