class_name WeaponLook
extends RefCounted
## Hace que el arma equipada se vea en el personaje:
##  - Un shader recolorea la espada de los sprites (sus 4 tonos exactos) y
##    la estela del ataque con el color del arma, con un brillo que recorre
##    la hoja.
##  - Un aura de particulas propia de cada arma (brasas, chispas, motas...).

const SHADER := """
shader_type canvas_item;

uniform vec4 blade_color : source_color = vec4(1.0);
uniform float blade_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec4 slash_color : source_color = vec4(1.0);
uniform float slash_mix : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer = 0.0;

varying vec4 vertex_color;

// Tonos de la hoja en las hojas de sprites, de mas claro a mas oscuro.
const vec3 BLADE_1 = vec3(242.0, 243.0, 199.0) / 255.0;
const vec3 BLADE_2 = vec3(215.0, 213.0, 152.0) / 255.0;
const vec3 BLADE_3 = vec3(195.0, 190.0, 138.0) / 255.0;
const vec3 BLADE_4 = vec3(169.0, 160.0, 121.0) / 255.0;
const vec3 SLASH = vec3(225.0, 234.0, 242.0) / 255.0;

void vertex() {
	vertex_color = COLOR;
}

bool same(vec3 a, vec3 b) {
	return distance(a, b) < 0.02;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float shade = -1.0;
	if (same(tex.rgb, BLADE_1)) shade = 1.0;
	else if (same(tex.rgb, BLADE_2)) shade = 0.78;
	else if (same(tex.rgb, BLADE_3)) shade = 0.62;
	else if (same(tex.rgb, BLADE_4)) shade = 0.45;

	if (shade > 0.0) {
		vec3 tinted = blade_color.rgb * (0.35 + 0.85 * shade);
		// Destello que recorre la hoja.
		float wave = 0.5 + 0.5 * sin(TIME * 7.0 + (UV.x + UV.y) * 90.0);
		tinted += vec3(shimmer * wave * 0.45);
		tex.rgb = mix(tex.rgb, tinted, blade_mix);
	} else if (same(tex.rgb, SLASH)) {
		tex.rgb = mix(tex.rgb, slash_color.rgb, slash_mix);
	}
	COLOR = tex * vertex_color;
}
"""

## Aura por arma: [cantidad, color, gravedad, velocidad, vida, tamano].
const AURAS := {
	"crimson": [10, Color(0.9, 0.1, 0.2), Vector2(0, 60), 10.0, 0.9, 2.5],
	"storm": [14, Color(0.6, 0.85, 1.0), Vector2.ZERO, 70.0, 0.25, 2.0],
	"daggers": [10, Color(0.6, 1.0, 0.45), Vector2(0, -20), 25.0, 0.6, 2.0],
	"inferno": [16, Color(1.0, 0.55, 0.15), Vector2(0, -70), 20.0, 0.7, 3.0],
	"arcane": [12, Color(0.8, 0.45, 1.0), Vector2(0, -15), 30.0, 1.0, 2.5],
}


static func make_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


## Aplica el aspecto de `weapon_id` al sprite y al aura del personaje.
static func apply(sprite: CanvasItem, aura: CPUParticles2D, weapon_id: String) -> void:
	var data := Items.weapon(weapon_id)
	var material := sprite.material as ShaderMaterial
	if material != null:
		var is_basic := weapon_id == "sword"
		material.set_shader_parameter("blade_color", data["color"])
		material.set_shader_parameter("blade_mix", 0.0 if is_basic else 1.0)
		material.set_shader_parameter("slash_color", (data["color"] as Color).lightened(0.35))
		material.set_shader_parameter("slash_mix", 0.0 if is_basic else 0.85)
		material.set_shader_parameter("shimmer", 0.0 if is_basic else 1.0)

	if aura == null:
		return
	if not AURAS.has(weapon_id):
		aura.emitting = false
		return
	var cfg: Array = AURAS[weapon_id]
	aura.amount = cfg[0]
	aura.color = cfg[1]
	aura.gravity = cfg[2]
	aura.initial_velocity_min = cfg[3] * 0.5
	aura.initial_velocity_max = cfg[3]
	aura.lifetime = cfg[4]
	# Las particulas van en coordenadas globales: se compensa la escala del personaje.
	aura.scale_amount_min = cfg[5] * 1.4
	aura.scale_amount_max = cfg[5] * 2.4
	aura.emitting = true


## Emisor del aura, pensado para ir como hijo del personaje.
static func make_aura() -> CPUParticles2D:
	var aura := CPUParticles2D.new()
	aura.emitting = false
	aura.local_coords = false
	aura.z_index = 1
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 9.0
	aura.direction = Vector2.UP
	aura.spread = 180.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	aura.color_ramp = fade
	return aura
