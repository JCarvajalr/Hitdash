class_name MainCharacter
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died
## Se emite al recibir el golpe mortal, antes de la animacion de muerte.
signal death_started
signal weapon_changed(weapon_id: String)
signal relics_changed(relics: Dictionary)
signal shield_changed(charges: int)
signal item_collected(kind: String, item_id: String)

@export var speed: float = 200.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var dash_invulnerable_time: float = 0.2
@export var attack_damage: float = 35
@export var max_health: float = 100.0
@export var damage_number_scene: PackedScene

@export_group("Golpes criticos")
@export var crit_chance: float = 0.15
@export var crit_multiplier: float = 2.0
## Empujon (pixeles) que reciben los enemigos al ser golpeados.
@export var knockback: float = 14.0

@export_group("Dash Strike")
## Dano que hace el dash a cada enemigo que atraviesa.
@export var dash_damage: float = 20.0
## Radio (local) de la zona que golpea durante el dash.
@export var dash_hit_radius: float = 11.0
## Si matas a un enemigo durante el dash, el dash se recarga al instante.
@export var dash_kill_refund: bool = true

@export_group("Armas")
## Porcentaje del dano que cura la Hoja Carmesi.
@export var lifesteal_ratio: float = 0.18
## Enemigos extra a los que salta el rayo del Mandoble de Tormenta.
@export var chain_targets: int = 2
@export var chain_range: float = 170.0
@export var burn_duration: float = 3.0

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

var _dash_area: Area2D
var _dash_hits: Array = []
var _dash_refunded: bool = false

## Arma equipada (ver Items.WEAPONS) y reliquias acumuladas {id: cantidad}.
var weapon_id: String = ""
var weapon: Dictionary = {}
var relics: Dictionary = {}
## Multiplicador de dano global (Piedra de Afilar).
var damage_bonus: float = 1.0
## Golpes que bloquea la Egida.
var shield_charges: int = 0
var _aura: CPUParticles2D

func _ready() -> void:
	attack_hitbox.disabled = true
	health = max_health
	health_changed.emit(health, max_health)
	character_sprite.frame_changed.connect(_on_frame_changed)
	_build_dash_area()
	# El arma equipada colorea la espada del sprite y lleva su propia aura.
	character_sprite.material = WeaponLook.make_material()
	_aura = WeaponLook.make_aura()
	add_child(_aura)
	equip_weapon("sword", false)

## Zona que golpea a los enemigos atravesados durante el dash.
func _build_dash_area() -> void:
	_dash_area = Area2D.new()
	_dash_area.collision_layer = 0
	_dash_area.collision_mask = 8 # capa "enemies"
	_dash_area.monitoring = false
	_dash_area.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = dash_hit_radius
	shape.shape = circle
	_dash_area.add_child(shape)
	add_child(_dash_area)
	_dash_area.body_entered.connect(_on_dash_area_body_entered)

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
	#attack_hitbox.disabled = false
	character_sprite.play("attack_" + last_direction_label, weapon.get("speed", 1.0))
	await (character_sprite.animation_finished)
	#attack_hitbox.disabled = true
	is_attacking = false

func start_dash():
	is_dashing = true
	can_dash = false
	is_invulnerable = true
	_dash_hits.clear()
	_dash_refunded = false
	_dash_area.set_deferred("monitoring", true)

	# Desactivar colisiones con enemigos para poder atravesarlos, pero respetando los bordes de pantalla
	var prev_mask := collision_mask
	collision_mask = 2

	# Feedback visual de invulnerabilidad/transparencia
	character_sprite.modulate.a = 0.6
	dash_effect.play("smoke")
	Sfx.play("dash", 0.12)

	# Dash hacia la última dirección
	velocity = last_direction * dash_speed

	# Duración del dash
	await get_tree().create_timer(dash_duration).timeout

	# Restaurar colisión física tras el desplazamiento
	collision_mask = prev_mask
	is_dashing = false
	_dash_area.set_deferred("monitoring", false)

	# Mantener invulnerabilidad si el tiempo configurado supera la duración del dash
	if dash_invulnerable_time > dash_duration:
		await get_tree().create_timer(dash_invulnerable_time - dash_duration).timeout

	if not is_dead:
		character_sprite.modulate = Color.WHITE
	is_invulnerable = false

	# Cooldown (se salta si el dash mato a alguien)
	if not _dash_refunded:
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
	deal_damage(body, attack_damage * weapon.get("damage", 1.0), {"effects": true})

func _on_dash_area_body_entered(body) -> void:
	if not is_dashing or body in _dash_hits:
		return
	_dash_hits.append(body)
	if deal_damage(body, dash_damage) and dash_kill_refund and not _dash_refunded:
		_dash_refunded = true
		_spawn_text("¡DASH!", Color(0.4, 0.95, 1.0))
		var tween := create_tween()
		tween.tween_property(character_sprite, "modulate", Color(0.4, 0.95, 1.0, 0.6), 0.05)
		tween.tween_property(character_sprite, "modulate", Color(1, 1, 1, 0.6), 0.15)

## Aplica dano a un enemigo con criticos, knockback, numeros flotantes,
## hit-stop y temblor. Devuelve true si el golpe lo mato.
## Opciones: "effects" (aplica el efecto del arma), "quiet" (sin hit-stop,
## temblor ni sonido; para quemaduras, rayos y ondas) y "color" del numero.
func deal_damage(body, base_damage: float, options: Dictionary = {}) -> bool:
	if not body.has_method("hurt"):
		return false
	if "is_dead" in body and body.is_dead:
		return false
	if body.get("is_prop"):
		body.hurt(base_damage * damage_bonus)
		if not options.get("quiet", false):
			Sfx.play("hit", 0.2, -4.0)
		return false
	var quiet: bool = options.get("quiet", false)

	var crit: bool = randf() < crit_chance + float(weapon.get("crit", 0.0))
	var damage := base_damage * damage_bonus * (crit_multiplier if crit else 1.0)
	var health_before: float = body.health if "health" in body else damage
	body.hurt(damage)
	var killed: bool = "is_dead" in body and body.is_dead

	_spawn_enemy_number(body, damage, crit, options.get("color", Color.WHITE))
	if options.get("effects", false):
		_apply_weapon_effect(body, damage, health_before)
	if not quiet and not killed and knockback > 0.0 and body is CharacterBody2D and not body.get("knockback_immune"):
		var push: Vector2 = (body.global_position - global_position).normalized() * knockback
		# Diferido: estamos dentro de un callback de fisica.
		body.call_deferred("move_and_collide", push)

	# Puntua solo la vida que se quito de verdad (sin contar el sobrante).
	var dealt: float = health_before - body.health if "health" in body else damage
	Combat.register_hit(dealt, killed, crit)
	if killed:
		Combat.notify_kill(body)
	if quiet:
		return killed
	if killed:
		Combat.hitstop(0.09)
		Combat.shake(9.0)
		Sfx.play("kill")
	elif crit:
		Combat.hitstop(0.06)
		Combat.shake(6.0)
		Sfx.play("crit")
	else:
		Combat.hitstop(0.035)
		Combat.shake(3.0)
		Sfx.play("hit", 0.15)
	return killed

func _apply_weapon_effect(body: Node2D, damage: float, health_before: float) -> void:
	match weapon.get("effect", "none"):
		"lifesteal":
			var dealt: float = minf(damage, health_before)
			heal(dealt * lifesteal_ratio, false)
		"chain":
			_chain_lightning(body, damage * 0.5)
		"burn":
			var burn = body.get_node_or_null("Burn")
			if burn != null:
				burn.refresh(burn_duration)
			elif not body.get("is_dead"):
				burn = WeaponFx.Burn.new()
				burn.name = "Burn"
				burn.source = self
				burn.tick_damage = attack_damage * 0.18
				burn.duration = burn_duration
				body.add_child(burn)

## El rayo salta a los enemigos mas cercanos al golpeado.
func _chain_lightning(origin: Node2D, damage: float) -> void:
	var candidates: Array = get_tree().get_nodes_in_group("Enemy").filter(func(e):
		return e != origin and is_instance_valid(e) and not e.get("is_dead") \
			and e.global_position.distance_to(origin.global_position) <= chain_range)
	candidates.sort_custom(func(a, b):
		return a.global_position.distance_to(origin.global_position) < b.global_position.distance_to(origin.global_position))
	var from := origin.global_position
	for target in candidates.slice(0, chain_targets):
		var bolt := WeaponFx.Lightning.new()
		bolt.from = from
		bolt.to = target.global_position
		bolt.color = weapon["color"]
		get_parent().add_child(bolt)
		from = target.global_position
		deal_damage(target, damage / damage_bonus, {"quiet": true, "color": Color(0.6, 0.85, 1.0)})
	if not candidates.is_empty():
		Sfx.play("zap", 0.15)

# --- Armas y objetos ----------------------------------------------------

func equip_weapon(id: String, announce: bool = true) -> void:
	weapon_id = id
	weapon = Items.weapon(id)
	# El tamano del golpe escala la zona de ataque.
	attack_hitbox.scale = Vector2.ONE * weapon["reach"]
	WeaponLook.apply(character_sprite, _aura, id)
	weapon_changed.emit(id)
	if announce:
		Sfx.play("equip", 0.0)
		_spawn_text(weapon["name"], weapon["color"])
		item_collected.emit("weapon", id)

func add_relic(id: String) -> void:
	relics[id] = relics.get(id, 0) + 1
	match id:
		"heart":
			max_health += 25.0
			health = max_health
			health_changed.emit(health, max_health)
		"boots":
			speed *= 1.15
			dash_cooldown *= 0.75
		"fang":
			crit_chance += 0.1
			crit_multiplier += 0.25
		"whetstone":
			damage_bonus += 0.2
		"aegis":
			shield_charges += 3
			shield_changed.emit(shield_charges)
			queue_redraw()
		"hourglass":
			Combat.combo_window_bonus += 0.8
	Sfx.play("pickup", 0.0)
	_spawn_text(Items.item_name("relic", id), Items.item_color("relic", id))
	relics_changed.emit(relics)
	item_collected.emit("relic", id)

## Burbuja de la Egida mientras quedan cargas.
func _draw() -> void:
	if shield_charges <= 0:
		return
	draw_circle(Vector2(0, 2), 15.0, Color(0.5, 0.8, 1.0, 0.15))
	draw_arc(Vector2(0, 2), 15.0, 0.0, TAU, 32, Color(0.6, 0.9, 1.0, 0.7), 0.8)

func _block_hit() -> void:
	shield_charges -= 1
	shield_changed.emit(shield_charges)
	queue_redraw()
	Sfx.play("block", 0.05)
	Combat.shake(5.0)
	_spawn_text("¡BLOQUEO!", Color(0.6, 0.9, 1.0))
	# Un instante de invulnerabilidad para no perder todas las cargas de golpe.
	is_invulnerable = true
	await get_tree().create_timer(0.5).timeout
	if not is_dashing:
		is_invulnerable = false

func hurt(damage: float) -> void:
	if is_dead or is_invulnerable:
		return
	if shield_charges > 0:
		_block_hit()
		return
	health = max(health - damage, 0.0)
	health_changed.emit(health, max_health)
	_spawn_damage_number(damage)
	Combat.player_hurt()
	Sfx.play("hurt")
	Combat.shake(10.0)
	Combat.hitstop(0.05, 0.2)
	if health <= 0.0:
		die()
		return
	_flash_damage()

func heal(amount: float, show_number: bool = true) -> void:
	if is_dead:
		return
	var healed: float = minf(amount, max_health - health)
	health += healed
	health_changed.emit(health, max_health)
	if show_number and healed >= 1.0:
		_spawn_text("+%d" % roundi(healed), Color(0.4, 1.0, 0.5))

func _spawn_damage_number(amount: float) -> void:
	var damage_number = damage_number_scene.instantiate()

	get_parent().add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -30)
	damage_number.show_damage(amount)

func _spawn_enemy_number(body: Node2D, amount: float, crit: bool, color: Color = Color.WHITE) -> void:
	var damage_number = damage_number_scene.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = body.global_position + Vector2(randf_range(-10, 10), -40)
	damage_number.show_damage(roundi(amount), Color(1.0, 0.82, 0.2) if crit else color, crit)

func _spawn_text(message: String, color: Color) -> void:
	var label = damage_number_scene.instantiate()
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(0, -50)
	label.show_text(message, color, 1.2)

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(character_sprite, "modulate", Color(0.971, 0.0, 0.183, 1.0), 0.2)
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
	death_started.emit()
	character_sprite.play("death_" + last_direction_label)
	await character_sprite.animation_finished
	# Un respiro para que el efecto de muerte luzca antes del Game Over.
	await get_tree().create_timer(0.6, true, false, true).timeout
	died.emit()
	
func _on_frame_changed():
	if (!is_attacking): return
	if (character_sprite.frame == 3):
		attack_hitbox.disabled = false
		_spawn_slash()
	if (character_sprite.frame == 5):
		attack_hitbox.disabled = true

func _spawn_slash() -> void:
	var dir := last_direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var slash := WeaponFx.Slash.new()
	slash.color = weapon["color"]
	slash.radius = 34.0 * weapon["reach"]
	slash.rotation = dir.angle()
	get_parent().add_child(slash)
	slash.global_position = global_position + dir * 18.0

	if weapon.get("effect") == "wave":
		var wave := WeaponFx.ArcaneWave.new()
		wave.source = self
		wave.direction = dir
		wave.color = weapon["color"]
		wave.damage = attack_damage * weapon["damage"] * 0.6
		get_parent().add_child(wave)
		wave.global_position = global_position + dir * 30.0
		Sfx.play("bolt", 0.1, -4.0)
