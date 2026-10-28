extends CanvasLayer
## Secuencia cinematica al morir el jugador:
##  - Destello blanco, temblor fuerte y camara lenta.
##  - Zoom de la camara hacia el jugador.
##  - La pantalla pierde el color y se cierra una vineta roja.
##  - Onda expansiva y almas que suben desde el cuerpo.
## Todo usa tiempo real (ignora la camara lenta) para durar lo mismo siempre.

const DESATURATE_SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focus = vec2(0.5, 0.5);

void fragment() {
	vec3 color = texture(screen_tex, SCREEN_UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(color, vec3(gray) * vec3(1.08, 0.92, 0.92), amount);
	float dist = distance(SCREEN_UV, focus);
	float vignette = smoothstep(0.2, 0.8, dist) * amount;
	COLOR = vec4(mix(tinted, vec3(0.3, 0.0, 0.03), vignette * 0.85), 1.0);
}
"""

@export var slow_motion_scale: float = 0.25
@export var slow_motion_time: float = 1.6
@export var zoom_amount: float = 1.8

var _grade: ColorRect
var _flash: ColorRect


func _ready() -> void:
	layer = 5 # por encima del mundo, por debajo del HUD y del Game Over
	process_mode = Node.PROCESS_MODE_ALWAYS

	_grade = ColorRect.new()
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = DESATURATE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_grade.material = material
	add_child(_grade)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)


func play(player: Node2D, camera: Camera2D) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_pos := player.get_global_transform_with_canvas().origin
	(_grade.material as ShaderMaterial).set_shader_parameter("focus", screen_pos / viewport_size)

	Sfx.play("player_death", 0.0)
	Combat.shake(18.0)
	Combat.hitstop(slow_motion_time, slow_motion_scale)

	_flash.color.a = 0.85
	var flash := create_tween().set_ignore_time_scale(true)
	flash.tween_property(_flash, "color:a", 0.0, 0.35)

	var grade := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	grade.tween_method(_set_grade, 0.0, 1.0, 1.3)

	if camera != null and is_instance_valid(camera):
		var zoom := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		zoom.tween_method(_zoom_camera.bind(camera, player.global_position, viewport_size), 0.0, 1.0, 1.4)

	_spawn_world_effects(player)


func _set_grade(value: float) -> void:
	(_grade.material as ShaderMaterial).set_shader_parameter("amount", value)


## Acerca la camara (anclada arriba a la izquierda) centrando al jugador,
## sin dejar ver fuera de la arena.
func _zoom_camera(t: float, camera: Camera2D, focus: Vector2, viewport_size: Vector2) -> void:
	if not is_instance_valid(camera):
		return
	var zoom := lerpf(1.0, zoom_amount, t)
	var view := viewport_size / zoom
	var target := (focus - view / 2.0).clamp(Vector2.ZERO, viewport_size - view)
	camera.zoom = Vector2(zoom, zoom)
	camera.position = Vector2.ZERO.lerp(target, t)


func _spawn_world_effects(player: Node2D) -> void:
	var world := player.get_parent()

	var ring := DeathRing.new()
	ring.position = player.global_position
	world.add_child(ring)

	var souls := CPUParticles2D.new()
	souls.position = player.global_position
	souls.z_index = 30
	souls.one_shot = true
	souls.explosiveness = 0.85
	souls.amount = 40
	souls.lifetime = 2.2
	souls.direction = Vector2.UP
	souls.spread = 70.0
	souls.initial_velocity_min = 40.0
	souls.initial_velocity_max = 140.0
	souls.gravity = Vector2(0, -60)
	souls.damping_min = 20.0
	souls.damping_max = 40.0
	souls.scale_amount_min = 2.0
	souls.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.add_point(0.3, Color(1.0, 0.3, 0.3, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.0, 0.05, 0.0))
	souls.color_ramp = ramp
	world.add_child(souls)
	souls.emitting = true


## Onda expansiva: dos anillos que crecen y se desvanecen.
class DeathRing extends Node2D:
	var _t: float = 0.0

	func _ready() -> void:
		z_index = 25
		var tween := create_tween().set_ignore_time_scale(true)
		tween.tween_property(self, "_t", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var alpha := 1.0 - _t
		draw_arc(Vector2.ZERO, 20.0 + 260.0 * _t, 0.0, TAU, 64, Color(1.0, 0.85, 0.85, alpha), 6.0 * alpha + 1.0)
		draw_arc(Vector2.ZERO, 10.0 + 160.0 * _t, 0.0, TAU, 48, Color(1.0, 0.2, 0.2, alpha * 0.8), 4.0 * alpha + 1.0)
		draw_circle(Vector2.ZERO, 40.0 * (1.0 - _t), Color(1, 1, 1, alpha * 0.6))
