class_name WeaponFx
extends RefCounted
## Efectos de las armas: estela del tajo, rayo en cadena, quemadura y la
## onda de la Hoja Arcana. Todo se dibuja por codigo.


## Estela en arco del tajo, con el color del arma.
class Slash extends Node2D:
	var color: Color = Color.WHITE
	var radius: float = 40.0
	var _t: float = 0.0

	func _ready() -> void:
		z_index = 15
		var tween := create_tween()
		tween.tween_property(self, "_t", 1.0, 0.18)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var sweep := lerpf(-1.1, 1.1, minf(_t * 1.6, 1.0))
		var c := color
		c.a = 1.0 - _t
		draw_arc(Vector2.ZERO, radius, -1.1, sweep, 20, c, 7.0 * (1.0 - _t) + 1.0)
		c.a *= 0.4
		draw_arc(Vector2.ZERO, radius * 0.75, -1.0, sweep, 16, c, 4.0)


## Rayo quebrado entre dos puntos que se desvanece.
class Lightning extends Node2D:
	var from: Vector2
	var to: Vector2
	var color: Color = Color(0.6, 0.85, 1.0)
	var _points := PackedVector2Array()
	var _alpha: float = 1.0

	func _ready() -> void:
		z_index = 16
		var segments := 7
		for i in segments + 1:
			var p := from.lerp(to, float(i) / segments)
			if i != 0 and i != segments:
				p += (to - from).orthogonal().normalized() * randf_range(-12.0, 12.0)
			_points.append(p)
		var tween := create_tween()
		tween.tween_property(self, "_alpha", 0.0, 0.25)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var glow := color
		glow.a = _alpha * 0.35
		draw_polyline(_points, glow, 8.0)
		draw_polyline(_points, Color(1, 1, 1, _alpha), 2.5)


## Quemadura: se cuelga del enemigo y le hace dano cada medio segundo.
class Burn extends Node:
	var source: Node  # el jugador, que reparte el dano
	var tick_damage: float = 6.0
	var duration: float = 3.0
	var _tick: float = 0.0

	func refresh(new_duration: float) -> void:
		duration = maxf(duration, new_duration)

	func _process(delta: float) -> void:
		var target := get_parent()
		if target == null or target.get("is_dead") or not is_instance_valid(source):
			queue_free()
			return
		duration -= delta
		_tick += delta
		if _tick >= 0.5:
			_tick = 0.0
			source.deal_damage(target, tick_damage, {"quiet": true, "effects": false, "color": Color(1.0, 0.55, 0.15)})
			if target is CanvasItem and not target.get("is_dead"):
				var flame := create_tween()
				flame.tween_property(target, "modulate", Color(1.6, 0.8, 0.4), 0.08)
				flame.tween_property(target, "modulate", Color.WHITE, 0.15)
		if duration <= 0.0:
			queue_free()


## Onda de energia que sale del tajo y atraviesa enemigos.
class ArcaneWave extends Area2D:
	var source: Node
	var direction := Vector2.RIGHT
	var damage: float = 20.0
	var color: Color = Color(0.8, 0.45, 1.0)
	var speed: float = 520.0
	var lifetime: float = 0.55
	var _hit: Array = []
	var _age: float = 0.0

	func _ready() -> void:
		z_index = 15
		collision_layer = 0
		collision_mask = 8 # enemigos
		monitorable = false
		rotation = direction.angle()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(22, 70)
		shape.shape = rect
		add_child(shape)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		_age += delta
		global_position += direction * speed * delta
		queue_redraw()
		if _age >= lifetime:
			queue_free()

	func _on_body_entered(body: Node) -> void:
		if body in _hit or not is_instance_valid(source):
			return
		_hit.append(body)
		source.deal_damage(body, damage, {"quiet": true, "effects": false, "color": color.lightened(0.3)})

	func _draw() -> void:
		var a := 1.0 - _age / lifetime
		var c := color
		c.a = a * 0.4
		draw_arc(Vector2(-10, 0), 36.0, -1.2, 1.2, 16, c, 14.0)
		c.a = a
		draw_arc(Vector2(-10, 0), 36.0, -1.1, 1.1, 16, c, 5.0)
		draw_arc(Vector2(-10, 0), 36.0, -0.9, 0.9, 12, Color(1, 1, 1, a), 2.0)
