extends Node2D
## Orbe de vida que sueltan los enemigos. Flota, brilla y, si el jugador
## pasa cerca, sale volando hacia el. Desaparece solo tras un rato.

@export var heal_amount: float = 12.0
@export var magnet_radius: float = 130.0
@export var pickup_radius: float = 22.0
@export var lifetime: float = 12.0
@export var color: Color = Color(0.35, 1.0, 0.5)

var _player: Node2D
var _age: float = 0.0
var _speed: float = 0.0
var _taken: bool = false


func _ready() -> void:
	z_index = 5
	add_to_group("Pickup")
	_player = get_tree().get_first_node_in_group("Player")
	# Pequeno salto al aparecer.
	var target := position + Vector2(randf_range(-30, 30), randf_range(-20, 20))
	scale = Vector2.ZERO
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.tween_property(self, "position", target, 0.3)


func _process(delta: float) -> void:
	if _taken:
		return
	_age += delta
	queue_redraw()
	if _age >= lifetime:
		_vanish()
		return
	if _player == null or not is_instance_valid(_player) or _player.get("is_dead"):
		return

	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	if distance <= pickup_radius:
		_collect()
	elif distance <= magnet_radius:
		_speed = minf(_speed + 900.0 * delta, 700.0)
		global_position += to_player.normalized() * _speed * delta


func _draw() -> void:
	var bob := sin(_age * 5.0) * 3.0
	var pulse := 0.5 + 0.5 * sin(_age * 8.0)
	# Parpadea en los ultimos segundos para avisar de que se va.
	if lifetime - _age < 3.0 and int(_age * 8.0) % 2 == 0:
		return
	var glow := color
	glow.a = 0.18 + 0.12 * pulse
	draw_circle(Vector2(0, bob), 14.0 + 3.0 * pulse, glow)
	draw_circle(Vector2(0, bob), 7.0, color)
	draw_circle(Vector2(-2, bob - 2), 2.5, Color(1, 1, 1, 0.9))


func _collect() -> void:
	_taken = true
	if _player.has_method("heal"):
		_player.heal(heal_amount)
	Sfx.play("pickup")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	queue_free()


func _vanish() -> void:
	_taken = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()
