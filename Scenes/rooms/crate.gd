extends StaticBody2D
## Objeto rompible de la sala: caja, barril o vasija (pixel art de
## tools/gen_props.py). Bloquea el paso y los proyectiles hasta que lo
## rompes a golpes; a veces suelta un orbe de vida.

const HealOrb := preload("res://Entities/Pickups/heal_orb.gd")
const PIXEL_SCALE := 2.8

## textura, vida, probabilidad de soltar vida, tamano de la base, color de los trozos
const KINDS := {
	"crate": [preload("res://sprites/props/crate.png"), 50.0, 0.3, Vector2(44, 20), Color(0.6, 0.38, 0.18)],
	"barrel": [preload("res://sprites/props/barrel.png"), 70.0, 0.35, Vector2(36, 18), Color(0.5, 0.3, 0.15)],
	"pot": [preload("res://sprites/props/pot.png"), 15.0, 0.25, Vector2(30, 16), Color(0.85, 0.45, 0.25)],
}

## El jugador lo golpea como a un enemigo, pero no cuenta para combos ni bajas.
var is_prop: bool = true
var is_dead: bool = false
var health: float = 50.0
var kind: String = ""

var _sprite: Sprite2D
var _foot: Vector2
var _drop_chance: float
var _debris_color: Color


func _ready() -> void:
	if kind == "":
		kind = ["crate", "crate", "barrel", "pot", "pot"].pick_random()
	var data: Array = KINDS[kind]
	health = data[1]
	_drop_chance = data[2]
	_foot = data[3]
	_debris_color = data[4]

	collision_layer = 11 # mundo + paredes + enemigos (para que lo golpeen)
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _foot
	shape.shape = rect
	shape.position = Vector2(0, -_foot.y / 2.0)
	add_child(shape)

	var texture: Texture2D = data[0]
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.scale = Vector2.ONE * PIXEL_SCALE
	_sprite.offset = Vector2(0, -texture.get_height() / 2.0 + 1)
	_sprite.flip_h = randf() < 0.5
	add_child(_sprite)


func footprint() -> Rect2:
	var foot := _foot if _foot != Vector2.ZERO else Vector2(44, 20)
	return Rect2(position - Vector2(foot.x / 2.0, foot.y), foot)


func hurt(damage: float) -> void:
	if is_dead:
		return
	health -= damage
	if health <= 0.0:
		_break()
		return
	# Destello y sacudida.
	_sprite.modulate = Color(2.5, 2.5, 2.5)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	var shake := create_tween()
	for i in 3:
		shake.tween_property(_sprite, "position:x", randf_range(-3.0, 3.0), 0.03)
	shake.tween_property(_sprite, "position:x", 0.0, 0.03)


func _break() -> void:
	is_dead = true
	set_deferred("collision_layer", 0)
	Sfx.play("slam", 0.25, -8.0 if kind != "pot" else -12.0)

	var debris := CPUParticles2D.new()
	debris.position = position + Vector2(0, -16)
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.amount = 16
	debris.lifetime = 0.7
	debris.spread = 180.0
	debris.initial_velocity_min = 80.0
	debris.initial_velocity_max = 200.0
	debris.gravity = Vector2(0, 450)
	debris.scale_amount_min = 3.0
	debris.scale_amount_max = 6.0
	debris.color = _debris_color
	get_parent().add_child(debris)
	debris.emitting = true
	debris.finished.connect(debris.queue_free)

	if randf() < _drop_chance:
		var orb := HealOrb.new()
		orb.position = position
		get_parent().call_deferred("add_child", orb)
	queue_free()
