extends Node2D
## Objeto tirado en el suelo: un arma o una reliquia.
##  - Reliquias: se cogen solo con pasar por encima.
##  - Armas: hay que pulsar "interact" (E). El arma que llevabas se queda
##    en el suelo, por si quieres volver a cambiarla.

@export var kind: String = "relic" # "weapon" o "relic"
@export var item_id: String = "heart"
@export var pickup_radius: float = 34.0
## Tras soltar un arma no se puede volver a coger hasta alejarse un poco.
var ignore_until_far: bool = false

var _player: Node2D
var _age: float = 0.0
var _taken: bool = false
var _label: Label
var _prompt: Label


func _ready() -> void:
	z_index = 6
	add_to_group("Pickup")
	_player = get_tree().get_first_node_in_group("Player")

	_label = _make_label(Items.item_name(kind, item_id), 14, Items.item_color(kind, item_id))
	_label.position.y = -58
	add_child(_label)

	_prompt = _make_label("[E] Equipar  ·  " + Items.item_desc(kind, item_id), 12, Color(1, 1, 1, 0.9))
	_prompt.position.y = 26
	_prompt.visible = false
	add_child(_prompt)

	# Aparece con un salto.
	scale = Vector2.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.size = Vector2(320, 20)
	label.position.x = -160
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(delta: float) -> void:
	if _taken:
		return
	_age += delta
	queue_redraw()
	if _player == null or not is_instance_valid(_player) or _player.get("is_dead"):
		_prompt.visible = false
		return

	var near := global_position.distance_to(_player.global_position) <= pickup_radius
	if ignore_until_far:
		if not near:
			ignore_until_far = false
		return

	if kind == "relic":
		if near:
			_take()
	else:
		_prompt.visible = near
		if near and Input.is_action_just_pressed("interact"):
			_take()


func _take() -> void:
	_taken = true
	_prompt.visible = false
	if kind == "weapon":
		var old_weapon: String = _player.weapon_id
		_player.equip_weapon(item_id)
		if old_weapon != "" and old_weapon != item_id:
			# Deja el arma vieja en el suelo, en el mismo sitio.
			var dropped = get_script().new()
			dropped.kind = "weapon"
			dropped.item_id = old_weapon
			dropped.ignore_until_far = true
			dropped.position = position
			get_parent().call_deferred("add_child", dropped)
	else:
		_player.add_relic(item_id)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()


func _draw() -> void:
	var bob := sin(_age * 3.0) * 4.0
	var color := Items.item_color(kind, item_id)
	var pulse := 0.5 + 0.5 * sin(_age * 5.0)

	# Haz de luz y halo en el suelo.
	var beam := color
	beam.a = 0.12 + 0.06 * pulse
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 10), Vector2(10, 10), Vector2(22, -90), Vector2(-22, -90),
	]), beam)
	var halo := color
	halo.a = 0.25 + 0.1 * pulse
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 26.0 + 3.0 * pulse, halo)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var glow := color
	glow.a = 0.25
	draw_circle(Vector2(0, -16 + bob), 20.0 + 2.0 * pulse, glow)
	Items.draw_icon(self, kind, item_id, Vector2(0, -16 + bob), 34.0)
