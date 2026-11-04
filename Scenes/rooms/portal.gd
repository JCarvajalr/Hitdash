extends Node2D
## Portal a la siguiente sala: un arco de piedra antiguo con un vortice en
## espiral dentro (shader), runas que laten, un circulo runico girando en
## el suelo, luz propia y particulas que el vortice se traga.
## Aparece con un rayo de luz al despejar la sala; al acercarse se acelera
## y al entrar emite `entered` (la arena hace la transicion).
##
## Cada portal anuncia la recompensa de la sala a la que lleva (arma,
## reliquia, vida o jefe) con un emblema flotante y su propio color.
## En modo "exit" es el portal de llegada: escupe al jugador y se cierra.

signal entered

const PIXEL_SCALE := 3.0
const GATE_TEXTURE := preload("res://sprites/props/portal_gate.png")
const RUNES_TEXTURE := preload("res://sprites/props/portal_runes.png")
const LIGHT_TEXTURE := preload("res://sprites/props/light.png")

const VORTEX_SHADER := """
shader_type canvas_item;

uniform vec4 core_color : source_color = vec4(0.04, 0.02, 0.09, 1.0);
uniform vec4 swirl_color : source_color = vec4(0.6, 0.4, 1.0, 1.0);
uniform float open = 0.0;
uniform float speed = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME * speed;
	// Dos espirales logaritmicas girando en sentidos distintos.
	float s1 = sin(a * 3.0 + log(r + 0.02) * 9.0 - t * 5.0);
	float s2 = sin(a * 5.0 - log(r + 0.02) * 6.0 - t * 3.0);
	float bands = smoothstep(-0.2, 1.0, s1) * 0.7 + smoothstep(0.3, 1.0, s2) * 0.4;
	vec3 col = mix(core_color.rgb, swirl_color.rgb, clamp(bands * (0.35 + r), 0.0, 1.0));
	// Nucleo brillante y centro casi blanco.
	col += swirl_color.rgb * pow(clamp(1.0 - r, 0.0, 1.0), 4.0) * 1.4;
	col += vec3(1.0) * pow(clamp(1.0 - r * 2.4, 0.0, 1.0), 2.0) * 0.9;
	// Borde encendido.
	float rim = smoothstep(0.78, 0.97, r) * (1.0 - smoothstep(0.97, 1.0, r));
	col += swirl_color.rgb * rim * 1.3;
	float radius = max(open, 0.001);
	float alpha = 1.0 - smoothstep(0.94 * radius, radius, r);
	COLOR = vec4(col, alpha * step(0.01, open));
}
"""

## Recompensa de la sala de destino.
const REWARDS := {
	"weapon": {"label": "ARMA", "color": Color(1.0, 0.72, 0.25)},
	"relic": {"label": "RELIQUIA", "color": Color(0.35, 0.85, 1.0)},
	"heal": {"label": "VIDA", "color": Color(0.35, 1.0, 0.5)},
	"boss": {"label": "JEFE", "color": Color(1.0, 0.18, 0.22)},
}

## Distorsiona lo que hay detras del portal, como aire caliente girando.
const DISTORT_SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
uniform vec2 size_px = vec2(300.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float fall = smoothstep(1.0, 0.15, r);
	float angle = fall * strength * (0.7 + 0.3 * sin(TIME * 3.0));
	vec2 swirled = vec2(cos(angle) * p.x - sin(angle) * p.y, sin(angle) * p.x + cos(angle) * p.y);
	vec2 ripple = p * sin(r * 22.0 - TIME * 7.0) * 0.015 * fall * strength;
	vec2 offset_px = (swirled - p + ripple) * size_px * 0.5;
	vec3 col = texture(screen_tex, SCREEN_UV + offset_px * SCREEN_PIXEL_SIZE).rgb;
	COLOR = vec4(col, smoothstep(1.0, 0.8, r) * step(0.001, strength));
}
"""

@export var color: Color = Color(0.6, 0.4, 1.0)
## "", "weapon", "relic", "heal" o "boss" (ver REWARDS).
@export var reward: String = ""
## "enter": portal normal. "exit": portal de llegada a la sala nueva.
@export var mode: String = "enter"
@export var enter_radius: float = 40.0
## A esta distancia el portal "despierta": gira mas rapido y llama.
@export var notice_radius: float = 170.0
## Segundos antes de que se pueda usar (para que no lo pises sin querer).
@export var arm_time: float = 1.0

var _player: Node2D
var _age: float = 0.0
var _used: bool = false
## Si el portal aparece encima del jugador, no se activa hasta que salga de el.
var _armed: bool = false
var _open: float = 0.0
var _rise: float = 0.0
var _excite: float = 0.0

var _vortex: ColorRect
var _gate: Sprite2D
var _runes: Sprite2D
var _light: PointLight2D
var _swirl: CPUParticles2D
var _label: Label
var _beam: Beam
var _distort: ColorRect
var _emblem: Emblem
var _closing: bool = false


func _ready() -> void:
	z_index = 3
	add_to_group("Pickup")
	_player = get_tree().get_first_node_in_group("Player")
	if REWARDS.has(reward):
		color = REWARDS[reward]["color"]
	var gate_size := GATE_TEXTURE.get_size() * PIXEL_SCALE
	var gate_origin := Vector2(-gate_size.x / 2.0, -gate_size.y + 6)

	# Aire distorsionado alrededor del vortice (lo primero, para quedar detras).
	_distort = ColorRect.new()
	_distort.size = Vector2(300, 300)
	_distort.position = gate_origin + Vector2(24, 28) * PIXEL_SCALE - _distort.size / 2.0
	_distort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var distort_shader := Shader.new()
	distort_shader.code = DISTORT_SHADER
	var distort_material := ShaderMaterial.new()
	distort_material.shader = distort_shader
	distort_material.set_shader_parameter("size_px", _distort.size)
	_distort.material = distort_material
	add_child(_distort)

	# Vortice dentro del hueco del arco (detras de la piedra).
	_vortex = ColorRect.new()
	_vortex.size = Vector2(31, 46) * PIXEL_SCALE
	_vortex.position = gate_origin + Vector2(8.5, 10) * PIXEL_SCALE
	_vortex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VORTEX_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("swirl_color", color)
	material.set_shader_parameter("core_color", color.darkened(0.92))
	_vortex.material = material
	add_child(_vortex)

	_gate = Sprite2D.new()
	_gate.texture = GATE_TEXTURE
	_gate.centered = false
	_gate.scale = Vector2(PIXEL_SCALE, 0.0)
	_gate.position = gate_origin
	add_child(_gate)

	_runes = Sprite2D.new()
	_runes.texture = RUNES_TEXTURE
	_runes.centered = false
	_runes.scale = _gate.scale
	_runes.position = gate_origin
	_runes.modulate = color.lightened(0.3)
	add_child(_runes)

	_swirl = CPUParticles2D.new()
	_swirl.position = _vortex_center()
	_swirl.amount = 40
	_swirl.lifetime = 1.0
	_swirl.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	_swirl.emission_ring_radius = 110.0
	_swirl.emission_ring_inner_radius = 80.0
	_swirl.radial_accel_min = -260.0
	_swirl.radial_accel_max = -180.0
	_swirl.tangential_accel_min = 90.0
	_swirl.tangential_accel_max = 140.0
	_swirl.gravity = Vector2.ZERO
	_swirl.scale_amount_min = 2.0
	_swirl.scale_amount_max = 4.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 0.0))
	ramp.add_point(0.3, color.lightened(0.4))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.9))
	_swirl.color_ramp = ramp
	_swirl.emitting = false
	add_child(_swirl)

	_light = PointLight2D.new()
	_light.texture = LIGHT_TEXTURE
	_light.texture_scale = 3.5
	_light.color = color
	_light.energy = 0.0
	_light.position = _vortex_center()
	add_child(_light)

	_label = Label.new()
	_label.text = REWARDS[reward]["label"] if REWARDS.has(reward) else "SIGUIENTE SALA"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(220, 20)
	_label.position = Vector2(-110, gate_origin.y - 30)
	_label.add_theme_font_size_override("font_size", 17 if REWARDS.has(reward) else 15)
	_label.add_theme_color_override("font_color", color.lightened(0.5))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.modulate.a = 0.0
	add_child(_label)

	if REWARDS.has(reward):
		_emblem = Emblem.new()
		_emblem.reward = reward
		_emblem.color = color
		_emblem.position = Vector2(0, gate_origin.y - 62)
		_emblem.modulate.a = 0.0
		add_child(_emblem)

	_beam = Beam.new()
	_beam.color = color
	add_child(_beam)

	if mode == "exit":
		_appear_exit()
	else:
		_appear()


func _vortex_center() -> Vector2:
	return _vortex.position + _vortex.size / 2.0


## Entrada: rayo de luz desde arriba, el arco sale del suelo y el vortice se abre.
func _appear() -> void:
	Sfx.play("portal_open", 0.0)
	Combat.shake(8.0)
	var tween := create_tween()
	tween.tween_property(_beam, "strength", 1.0, 0.1)
	tween.tween_interval(0.2)
	tween.tween_property(_beam, "strength", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.tween_callback(_beam.queue_free)
	var rise := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_interval(0.1)
	rise.tween_property(self, "_rise", 1.0, 0.5)
	var open := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	open.tween_interval(0.45)
	open.tween_property(self, "_open", 1.0, 1.0)
	open.parallel().tween_property(_label, "modulate:a", 1.0, 0.5)
	if _emblem != null:
		open.parallel().tween_property(_emblem, "modulate:a", 1.0, 0.5)
	open.tween_callback(func(): _swirl.emitting = true)


## Portal de llegada: ya esta abierto, sin letrero, y se cierra solo.
func _appear_exit() -> void:
	_beam.queue_free()
	_label.visible = false
	_rise = 1.0
	_used = true
	var open := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open.tween_property(self, "_open", 1.0, 0.3)
	open.tween_interval(1.0)
	open.tween_callback(close)


## Punto (en coordenadas globales) del centro del vortice.
func vortex_global_position() -> Vector2:
	return to_global(_vortex_center())


## Se cierra: el vortice colapsa, el arco se hunde y desaparece.
func close() -> void:
	if _closing:
		return
	_closing = true
	_used = true
	_swirl.emitting = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "_open", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_label, "modulate:a", 0.0, 0.2)
	if _emblem != null:
		tween.tween_property(_emblem, "modulate:a", 0.0, 0.2)
	tween.chain().tween_property(self, "_rise", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_age += delta
	_gate.scale.y = PIXEL_SCALE * _rise
	_runes.scale.y = _gate.scale.y
	_gate.position.y = -GATE_TEXTURE.get_height() * PIXEL_SCALE * _rise + 6
	_runes.position.y = _gate.position.y

	# Se emociona cuando el jugador se acerca.
	var target_excite := 0.0
	var inside := false
	if _player != null and is_instance_valid(_player) and not _player.get("is_dead"):
		var distance := (global_position + Vector2(0, -20)).distance_to(_player.global_position)
		target_excite = clampf(1.0 - (distance - enter_radius) / notice_radius, 0.0, 1.0)
		inside = distance <= enter_radius
	_excite = move_toward(_excite, target_excite, delta * 2.5)

	var material := _vortex.material as ShaderMaterial
	material.set_shader_parameter("open", _open)
	material.set_shader_parameter("speed", 1.0 + 2.5 * _excite)
	(_distort.material as ShaderMaterial).set_shader_parameter("strength", _open * (0.5 + 0.9 * _excite))
	var pulse := 0.5 + 0.5 * sin(_age * (3.0 + 6.0 * _excite))
	_runes.modulate.a = 0.55 + 0.45 * pulse
	_light.energy = _open * (0.9 + 0.35 * pulse + 0.6 * _excite)
	_swirl.speed_scale = 1.0 + 1.5 * _excite
	_label.scale = Vector2.ONE * (1.0 + 0.08 * _excite * pulse)
	if _emblem != null:
		_emblem.excite = _excite
	queue_redraw()

	if _used or _age < arm_time:
		return
	if not _armed:
		_armed = not inside
		return
	if inside:
		_used = true
		Sfx.play("teleport", 0.0)
		entered.emit()


func _draw() -> void:
	# Circulo runico en el suelo, girando.
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.38))
	var r := 92.0 * _open
	if r > 1.0:
		var c := color
		c.a = 0.18 + 0.1 * _excite
		draw_circle(Vector2.ZERO, r, c)
		c.a = 0.7
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, c, 3.0)
		draw_arc(Vector2.ZERO, r * 0.78, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.45), 2.0)
		# Marcas que giran entre los dos anillos.
		var spin := _age * (0.6 + 1.6 * _excite)
		for i in 12:
			var a := spin + TAU * i / 12.0
			var p1 := Vector2(cos(a), sin(a)) * r * 0.8
			var p2 := Vector2(cos(a + 0.12), sin(a + 0.12)) * r * 0.97
			draw_line(p1, p2, color.lightened(0.4), 3.0)
		# Rombos en sentido contrario.
		for i in 6:
			var a := -spin * 1.4 + TAU * i / 6.0
			var p := Vector2(cos(a), sin(a)) * r * 0.55
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -9), p + Vector2(6, 0), p + Vector2(0, 9), p + Vector2(-6, 0),
			]), Color(1, 1, 1, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Medallon flotante sobre el arco con el icono de la recompensa.
class Emblem extends Node2D:
	var reward: String = ""
	var color: Color = Color.WHITE
	var excite: float = 0.0
	var _t: float = 0.0

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(0, sin(_t * 2.5) * 5.0)
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		# Halo y medallon.
		draw_circle(c, 34.0 + 4.0 * pulse + 6.0 * excite, Color(color.r, color.g, color.b, 0.18))
		draw_circle(c, 26.0, Color(0.06, 0.03, 0.09, 0.92))
		draw_arc(c, 26.0, 0.0, TAU, 40, color, 3.0)
		# Rayos que giran alrededor.
		for i in 8:
			var a := _t * 1.2 + TAU * i / 8.0
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * 30.0, c + dir * (36.0 + 4.0 * pulse), Color(color.r, color.g, color.b, 0.8), 2.0)
		match reward:
			"weapon":
				Items.draw_icon(self, "weapon", "sword", c, 34.0)
			"relic":
				# Gema.
				var gem := PackedVector2Array([
					c + Vector2(0, -15), c + Vector2(12, -4), c + Vector2(7, 13),
					c + Vector2(-7, 13), c + Vector2(-12, -4),
				])
				draw_colored_polygon(gem, color)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -15), c + Vector2(12, -4), c + Vector2(0, -2), c + Vector2(-12, -4),
				]), color.lightened(0.5))
				var outline := gem.duplicate()
				outline.append(gem[0])
				draw_polyline(outline, Color(0.05, 0.03, 0.08), 2.0)
			"heal":
				Items.draw_icon(self, "relic", "heart", c + Vector2(0, 2), 34.0)
			"boss":
				# Calavera.
				var bone := Color(0.95, 0.92, 0.85)
				var dark := Color(0.1, 0.04, 0.05)
				draw_circle(c + Vector2(0, -3), 14.0, bone)
				draw_rect(Rect2(c + Vector2(-8, 6), Vector2(16, 9)), bone)
				draw_circle(c + Vector2(-5.5, -3), 4.5, Color(0.65, 0.05, 0.08))
				draw_circle(c + Vector2(5.5, -3), 4.5, Color(0.65, 0.05, 0.08))
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, 3), c + Vector2(-2.5, 7), c + Vector2(2.5, 7),
				]), dark)
				for x in [-5.0, 0.0, 5.0]:
					draw_line(c + Vector2(x, 10), c + Vector2(x, 15), dark, 1.5)


## Rayo de luz que cae del cielo al aparecer el portal (por encima de todo).
class Beam extends Node2D:
	var color: Color = Color.WHITE
	var strength: float = 0.0:
		set(value):
			strength = value
			queue_redraw()

	func _ready() -> void:
		z_index = 30

	func _draw() -> void:
		if strength <= 0.0:
			return
		var w := 80.0 * strength
		var glow := color.lightened(0.5)
		glow.a = 0.35 * strength
		draw_rect(Rect2(-w, -900, w * 2.0, 900), glow)
		glow.a = 0.8 * strength
		draw_rect(Rect2(-w / 2.0, -900, w, 900), glow)
		draw_rect(Rect2(-w / 6.0, -900, w / 3.0, 900), Color(1, 1, 1, strength))
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 150.0 * (1.3 - strength * 0.5), Color(1, 1, 1, 0.45 * strength))
