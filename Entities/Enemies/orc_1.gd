extends CharacterBody2D

signal died

@export var health: float
@export var max_health: float = 100.0
@export var attack_damage: float
@export var speed: float
@export var stop_distance: float
@onready var character_sprite: AnimatedSprite2D = $CharacterSprite
@onready var restart_attack_timer: Timer = $RestartAttackTimer
@onready var attack_hitbox: CollisionShape2D = $AttackArea/AttackHitbox
@onready var attack_area: Area2D = $AttackArea
var player
var is_animating: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_dead: bool = false
var last_direction := Vector2.DOWN
var last_direction_label = "down"

var _health_bar: ProgressBar

func _ready() -> void:
	add_to_group("Enemy")
	player = get_tree().get_first_node_in_group("Player")
	character_sprite.frame_changed.connect(_on_frame_changed)
	attack_area.body_entered.connect(_on_attack_area_body_entered)

	if health <= 0.0:
		health = max_health
	max_health = max(max_health, health)
	_build_health_bar()

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
	if (!can_attack || is_dead): return
	is_attacking = true
	can_attack = false
	character_sprite.play("attack_" + last_direction_label)
	await (character_sprite.animation_finished)
	is_attacking = false
	restart_attack_timer.start()

func hurt(damage):
	if is_dead:
		return
	health = max(health - damage, 0.0)
	_update_health_bar()
	if health <= 0.0:
		_die()
		return
	character_sprite.play("hurt_" + last_direction_label)
	is_animating = true
	await (character_sprite.animation_finished)
	is_animating = false

func _update_health_bar() -> void:
	if _health_bar == null:
		return
	_health_bar.value = health
	_health_bar.visible = not is_dead and health < max_health

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	attack_hitbox.set_deferred("disabled", true)
	if _health_bar != null:
		_health_bar.visible = false
	character_sprite.play("hurt_" + last_direction_label)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	await tween.finished
	queue_free()

func _on_attack_area_body_entered(body) -> void:
	if is_dead:
		return
	if body.is_in_group("Player") and body.has_method("hurt"):
		body.hurt(attack_damage)

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
