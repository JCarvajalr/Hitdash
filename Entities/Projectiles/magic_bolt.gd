class_name MagicBolt
extends Area2D
## Proyectil magico que lanzan los vampiros. Viaja en linea recta,
## dana al jugador al impactar y se destruye al chocar o al agotar su vida.

@export var speed: float = 300.0
@export var damage: float = 16.0
## Segundos que vive el proyectil antes de desaparecer solo.
@export var lifetime: float = 4.0

@onready var sprite: Sprite2D = $Sprite2D

var direction := Vector2.RIGHT
var _spent: bool = false
var _age: float = 0.0


func setup(new_direction: Vector2, new_speed: float, new_damage: float) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

	# Pequeno latido para que se note que es magia y no una bala.
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.18)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.18)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta


func _on_body_entered(body) -> void:
	if _spent:
		return
	if body.is_in_group("Player") and body.has_method("hurt"):
		body.hurt(damage)
		_impact()


func _impact() -> void:
	_spent = true
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	await tween.finished
	queue_free()
