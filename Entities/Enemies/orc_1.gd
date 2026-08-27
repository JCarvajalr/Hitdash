extends CharacterBody2D	

@export var health: float
@export var attack_damage: float
@export var speed: float
@export var stop_distance: float
@onready var character_sprite: AnimatedSprite2D = $CharacterSprite
@onready var restart_attack_timer: Timer = $RestartAttackTimer
@onready var attack_hitbox: CollisionShape2D = $AttackArea/AttackHitbox
var player
var is_animating: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var last_direction := Vector2.DOWN
var last_direction_label = "down"

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	character_sprite.frame_changed.connect(_on_frame_changed)

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	if (player != null):
		if (global_position.distance_to(player.global_position) > stop_distance):
			direction = (player.global_position - global_position).normalized()
		else:
			direction = Vector2.ZERO
			start_attack()
		
	move(direction)
	move_and_slide()

func move(direction):
	if (direction != Vector2.ZERO):
		last_direction = direction
	velocity = direction * speed
	update_dir()
	update_animation(direction)

func start_attack():
	if (!can_attack): return
	is_attacking = true
	can_attack = false
	character_sprite.play("attack_" + last_direction_label)
	await (character_sprite.animation_finished)
	is_attacking = false
	restart_attack_timer.start()

func hurt(damage):
	health -= damage
	character_sprite.play("hurt_" + last_direction_label)
	is_animating = true
	await (character_sprite.animation_finished)
	is_animating = false
	#if (health <= 0): queue_free()

func update_dir():
	var dir = []
	if (abs(last_direction.x) > abs(last_direction.y)):
		if (last_direction.x > 0):
			dir.append("right")
			attack_hitbox.position = Vector2(20, -1)
		else:
			dir.append("left")
			attack_hitbox.position = Vector2(-20, -1)
	elif (abs(last_direction.y) > abs(last_direction.x)):
		if (last_direction.y > 0):
			dir.append("down")
			attack_hitbox.position = Vector2(9, 8)
		else:
			dir.append("up")
			attack_hitbox.position = Vector2(0, -16)
			
	last_direction_label = dir[0]

func update_animation(direction):
	if (is_animating || is_attacking): return
	if (direction == Vector2.ZERO):
		character_sprite.play("idle_" + last_direction_label)
	elif (speed >= 180):
		character_sprite.play("run_" + last_direction_label)
	else:
		character_sprite.play("walk_" + last_direction_label)

func _on_frame_changed():
	if (!is_attacking): return
	if (character_sprite.frame == 3):
		attack_hitbox.disabled = false
	if (character_sprite.frame == 6):
		attack_hitbox.disabled = true
	

func _on_restart_attack_timer_timeout() -> void:
	can_attack = true
