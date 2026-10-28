extends Node2D
## Cofre que aparece entre oleadas. Se abre al acercarse (o al golpearlo)
## y suelta un arma o una reliquia.

const ItemPickup := preload("res://Entities/Pickups/item_pickup.gd")
const HealOrb := preload("res://Entities/Pickups/heal_orb.gd")

## Probabilidad de que el cofre traiga un arma en vez de una reliquia.
@export var weapon_chance: float = 0.35
## Fuerza el contenido: "weapon", "relic", "heal" (orbes de vida) o "" (al azar).
@export var forced_kind: String = ""
@export var open_radius: float = 40.0
## Orbes que suelta un cofre de vida.
@export var heal_orbs: int = 5
@export var lifetime: float = 30.0

var _player: Node2D
var _age: float = 0.0
var _opened: bool = false
var _lid: float = 0.0


func _ready() -> void:
	z_index = 4
	add_to_group("Pickup")
	_player = get_tree().get_first_node_in_group("Player")
	# Cae del cielo.
	var landing := position
	position.y -= 300
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", landing, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _opened:
		return
	if _age >= lifetime:
		_opened = true
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.5)
		fade.tween_callback(queue_free)
		return
	if _player != null and is_instance_valid(_player) and _age > 0.5:
		if global_position.distance_to(_player.global_position) <= open_radius:
			open()


func open() -> void:
	if _opened:
		return
	_opened = true
	Sfx.play("chest", 0.0)
	Combat.shake(4.0)
	var tween := create_tween()
	tween.tween_property(self, "_lid", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if forced_kind == "heal":
		# Recompensa de vida: un punado de orbes que saltan del cofre.
		for i in heal_orbs:
			var orb := HealOrb.new()
			orb.position = position + Vector2(randf_range(-30, 30), -20)
			get_parent().call_deferred("add_child", orb)
		tween.tween_interval(1.5)
		tween.tween_property(self, "modulate:a", 0.0, 0.6)
		tween.tween_callback(queue_free)
		return

	var pickup := ItemPickup.new()
	var as_weapon := forced_kind == "weapon" or (forced_kind == "" and randf() < weapon_chance)
	if as_weapon:
		pickup.kind = "weapon"
		pickup.item_id = Items.random_weapon(_player.weapon_id if _player != null else "")
	else:
		pickup.kind = "relic"
		pickup.item_id = Items.random_relic()
	pickup.position = position + Vector2(0, -50)
	get_parent().call_deferred("add_child", pickup)

	tween.tween_interval(1.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var wood := Color(0.55, 0.32, 0.15)
	var dark := Color(0.3, 0.16, 0.07)
	var gold := Color(1.0, 0.82, 0.3)
	var outline := Color(0.06, 0.03, 0.02)

	# Sombra.
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Cuerpo.
	var body := Rect2(-22, -10, 44, 24)
	draw_rect(body, wood)
	draw_rect(Rect2(-22, -10, 44, 4), dark)
	draw_rect(body, outline, false, 2.0)
	draw_rect(Rect2(-3, -10, 6, 24), gold)

	# Tapa (se levanta al abrir).
	var lid_y := -22.0 - 14.0 * _lid
	var lid := Rect2(-23, lid_y, 46, 13)
	draw_rect(lid, wood.lightened(0.1))
	draw_rect(lid, outline, false, 2.0)
	draw_rect(Rect2(-3, lid_y, 6, 13), gold)

	# Brillo que se escapa por la rendija / al abrir.
	var shine := 0.5 + 0.5 * sin(_age * 4.0)
	if _opened:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-18, -10), Vector2(18, -10), Vector2(40, -90), Vector2(-40, -90),
		]), Color(1.0, 0.9, 0.5, 0.35 * (1.0 - _lid * 0.3)))
	else:
		draw_line(Vector2(-20, -10), Vector2(20, -10), Color(1.0, 0.9, 0.5, 0.4 + 0.5 * shine), 2.0)
		draw_circle(Vector2(0, -4), 2.5, Color(1, 1, 1, shine))
