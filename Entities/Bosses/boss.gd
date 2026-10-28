class_name Boss
extends CharacterBody2D
## Base comun de los jefes: vida con dos fases, dano por contacto,
## entrada dramatica, avisos visuales antes de cada ataque (telegraph)
## y utilidades para disparar patrones de proyectiles e invocar esbirros.
##
## Cada jefe hereda de aqui y solo define sus animaciones (_build_frames),
## su movimiento (_think) y su repertorio de ataques (_choose_attack).

signal died
signal health_changed(current: float, maximum: float)
signal phase_changed(phase: int)

@export_group("Identidad")
@export var boss_name: String = "Jefe"
@export var boss_title: String = ""
@export var bolt_color: Color = Color.WHITE

@export_group("Vida y dano")
@export var health: float = 0.0
@export var max_health: float = 1500.0
## Dano base de los proyectiles (el spawner lo escala con la oleada).
@export var attack_damage: float = 14.0
@export var contact_damage: float = 18.0
## Por debajo de este porcentaje de vida entra en la fase 2.
@export var phase_two_ratio: float = 0.5

@export_group("Movimiento")
@export var speed: float = 70.0
## Escala del jefe: los sprites son de 64x64, igual que el resto.
@export var boss_scale: float = 5.0
## Radio (local) del cuerpo.
@export var body_radius: float = 9.0
## Segundos de respiro entre ataques en fase 1 y fase 2.
@export var attack_interval: float = 2.2
@export var attack_interval_phase_two: float = 1.4

@export_group("Proyectiles")
@export var projectile_scene: PackedScene = preload("res://Entities/Projectiles/magic_bolt.tscn")

## Lo rellena el spawner: zona por la que puede moverse / teletransportarse.
var arena_rect: Rect2 = Rect2(64, 64, 1024, 520)
## Los golpes del jugador no lo empujan.
var knockback_immune: bool = true

var is_dead: bool = false
var phase: int = 1
var player: Node2D
var sprite: AnimatedSprite2D
var facing := Vector2.DOWN

var _busy: bool = true
var _anim_locked: bool = false
var _invulnerable: bool = false
var _next_attack: float = 1.5
var _contact_area: Area2D
var _contact_cooldown: float = 0.0
var _warning_radius: float = 0.0
var _warning_color: Color = Color.RED


func _ready() -> void:
	add_to_group("Enemy")
	add_to_group("Boss")
	collision_layer = 9 # world + enemies
	collision_mask = 2
	scale = Vector2.ONE * boss_scale
	z_index = 1

	if health <= 0.0:
		health = max_health
	max_health = max(max_health, health)
	player = get_tree().get_first_node_in_group("Player")

	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _build_frames()
	add_child(sprite)

	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	body_shape.shape = circle
	add_child(body_shape)

	_contact_area = Area2D.new()
	_contact_area.collision_layer = 0
	_contact_area.collision_mask = 512 # solo el jugador
	_contact_area.monitorable = false
	var contact_shape := CollisionShape2D.new()
	var contact_circle := CircleShape2D.new()
	contact_circle.radius = body_radius + 3.0
	contact_shape.shape = contact_circle
	_contact_area.add_child(contact_shape)
	add_child(_contact_area)

	_intro()


## Animaciones del jefe. Debe devolver idle_/run_/attack_/death_ por direccion.
func _build_frames() -> SpriteFrames:
	return SpriteFrames.new()


## Movimiento mientras no ataca. Por defecto camina hacia el jugador.
func _think(_delta: float) -> void:
	velocity = _to_player().normalized() * speed * (1.3 if phase == 2 else 1.0)


## Ejecuta un ataque (corrutina). Se llama cuando toca atacar.
func _choose_attack() -> void:
	await wait(0.5)


func _on_phase_two() -> void:
	pass


# --- Bucle principal ----------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_contact_cooldown -= delta
	if _contact_cooldown <= 0.0:
		for body in _contact_area.get_overlapping_bodies():
			if body.is_in_group("Player") and body.has_method("hurt"):
				body.hurt(contact_damage)
				_contact_cooldown = 0.8

	if not _busy:
		_think(delta)
		_next_attack -= delta
		if _next_attack <= 0.0:
			_run_attack()

	move_and_slide()
	_update_animation()


func _run_attack() -> void:
	_busy = true
	velocity = Vector2.ZERO
	await _choose_attack()
	if is_dead:
		return
	_next_attack = attack_interval_phase_two if phase == 2 else attack_interval
	_busy = false


func _update_animation() -> void:
	if _anim_locked or is_dead:
		return
	if velocity.length() > 5.0:
		facing = velocity.normalized()
		sprite.play("run_" + SpriteSheets.direction_label(facing))
	else:
		sprite.play("idle_" + SpriteSheets.direction_label(facing))


func _intro() -> void:
	modulate.a = 0.0
	var base_scale := scale
	scale = base_scale * 0.4
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_property(self, "scale", base_scale, 0.7)
	Sfx.play("boss_roar", 0.0)
	Combat.shake(16.0)
	await wait(1.4)
	if not is_dead:
		_busy = false


# --- Vida ---------------------------------------------------------------

func hurt(damage: float) -> void:
	if is_dead or _invulnerable:
		return
	health = max(health - damage, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()
		return

	sprite.modulate = Color(3.0, 3.0, 3.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_tint(), 0.12)

	if phase == 1 and health <= max_health * phase_two_ratio:
		phase = 2
		phase_changed.emit(phase)
		Sfx.play("boss_roar", 0.0, 2.0)
		Combat.shake(14.0)
		_on_phase_two()


## Tinte normal del sprite: en fase 2 el jefe se ve enfurecido.
func _base_tint() -> Color:
	return Color(1.0, 0.7, 0.7) if phase == 2 else Color.WHITE


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_busy = true
	_warning_radius = 0.0
	queue_redraw()
	remove_from_group("Enemy")
	died.emit()
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_contact_area.set_deferred("monitoring", false)

	Sfx.play("boss_death", 0.0)
	Combat.hitstop(0.45, 0.08)
	Combat.shake(18.0)

	sprite.modulate = Color.WHITE
	_anim_locked = true
	sprite.play("death_" + SpriteSheets.direction_label(facing))
	# Destellos mientras cae.
	var flash := create_tween().set_loops(6)
	flash.tween_property(sprite, "modulate", Color(4, 4, 4), 0.08)
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	await sprite.animation_finished
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.8)
	await fade.finished
	queue_free()


# --- Utilidades para los ataques ----------------------------------------

## Espera respetando la pausa del juego.
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _to_player() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	return player.global_position - global_position


func face_player() -> Vector2:
	var dir := _to_player().normalized()
	if dir != Vector2.ZERO:
		facing = dir
	return facing


## Reproduce una animacion una sola vez mirando hacia `facing`.
func play_once(anim: String, speed_scale: float = 1.0) -> void:
	_anim_locked = true
	sprite.play(anim + "_" + SpriteSheets.direction_label(facing), speed_scale)
	await sprite.animation_finished
	_anim_locked = false


## Aviso visual antes de un ataque: circulo en el suelo y destello.
func telegraph(duration: float, radius: float, color: Color) -> void:
	_warning_color = color
	var tween := create_tween()
	tween.tween_method(_set_warning_radius, 0.0, radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var blink := create_tween().set_loops(int(duration / 0.16))
	blink.tween_property(sprite, "modulate", color.lightened(0.4), 0.08)
	blink.tween_property(sprite, "modulate", _base_tint(), 0.08)
	await wait(duration)
	_set_warning_radius(0.0)
	sprite.modulate = _base_tint()


func _set_warning_radius(value: float) -> void:
	_warning_radius = value
	queue_redraw()


func _draw() -> void:
	if _warning_radius <= 0.0:
		return
	var fill := _warning_color
	fill.a = 0.18
	draw_circle(Vector2(0, 4), _warning_radius, fill)
	draw_arc(Vector2(0, 4), _warning_radius, 0.0, TAU, 48, _warning_color, 0.6)


func fire_bolt(direction: Vector2, bolt_speed: float, damage_mult: float = 1.0) -> void:
	if projectile_scene == null or is_dead:
		return
	var bolt := projectile_scene.instantiate()
	bolt.modulate = bolt_color
	get_parent().add_child(bolt)
	bolt.global_position = global_position + direction * body_radius * boss_scale * 0.8
	if bolt is MagicBolt:
		(bolt as MagicBolt).setup(direction, bolt_speed, attack_damage * damage_mult)


## Anillo de `count` proyectiles repartidos en 360 grados.
func fire_ring(count: int, bolt_speed: float, angle_offset: float = 0.0) -> void:
	for i in count:
		fire_bolt(Vector2.RIGHT.rotated(angle_offset + TAU * i / count), bolt_speed)
	Sfx.play("bolt", 0.05)


## Abanico de `count` proyectiles centrado en `direction`.
func fire_fan(direction: Vector2, count: int, spread_degrees: float, bolt_speed: float) -> void:
	var spread := deg_to_rad(spread_degrees)
	for i in count:
		var t := 0.5 if count == 1 else float(i) / (count - 1)
		fire_bolt(direction.rotated(lerpf(-spread / 2.0, spread / 2.0, t)), bolt_speed)
	Sfx.play("bolt", 0.05)


## Invoca esbirros alrededor de un punto, sin pasarse de `max_alive`.
func summon(scene: PackedScene, count: int, around: Vector2, radius: float, max_alive: int = 6) -> void:
	if scene == null:
		return
	var alive := 0
	for node in get_tree().get_nodes_in_group("Minion"):
		if is_instance_valid(node) and not node.get("is_dead"):
			alive += 1
	count = mini(count, max_alive - alive)
	if count <= 0:
		return
	Sfx.play("summon")
	for i in count:
		var minion: Node2D = scene.instantiate()
		minion.scale = Vector2(2.8, 2.8)
		minion.add_to_group("Minion")
		get_parent().add_child(minion)
		var pos := around + Vector2.RIGHT.rotated(TAU * i / count + randf() * 0.5) * radius
		minion.global_position = clamp_to_arena(pos)
		minion.modulate.a = 0.0
		minion.create_tween().tween_property(minion, "modulate:a", 1.0, 0.4)


func clamp_to_arena(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, arena_rect.position.x, arena_rect.end.x),
		clampf(pos.y, arena_rect.position.y, arena_rect.end.y)
	)


func random_arena_point(min_distance_to_player: float) -> Vector2:
	for i in 20:
		var p := Vector2(
			randf_range(arena_rect.position.x, arena_rect.end.x),
			randf_range(arena_rect.position.y, arena_rect.end.y)
		)
		if player == null or p.distance_to(player.global_position) >= min_distance_to_player:
			return p
	return arena_rect.get_center()
