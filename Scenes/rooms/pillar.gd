extends Node2D
## Columna de la sala (pixel art de tools/gen_props.py). Bloquea a
## personajes y proyectiles. Puede estar rota y algunas enteras llevan una
## antorcha con luz que parpadea. La posicion del nodo es la base de la
## columna, para que el y-sort la ponga delante o detras de los personajes.

const PIXEL_SCALE := 3.0
const FOOT := Vector2(54, 24)
const LIGHT_TEXTURE := preload("res://sprites/props/light.png")
const TORCH_TEXTURE := preload("res://sprites/props/torch.png")
const TEXTURES := {
	"dungeon": [preload("res://sprites/props/pillar_dungeon_intact.png"), preload("res://sprites/props/pillar_dungeon_broken.png")],
	"garden": [preload("res://sprites/props/pillar_garden_intact.png"), preload("res://sprites/props/pillar_garden_broken.png")],
	"castle": [preload("res://sprites/props/pillar_castle_intact.png"), preload("res://sprites/props/pillar_castle_broken.png")],
	"abyss": [preload("res://sprites/props/pillar_abyss_intact.png"), preload("res://sprites/props/pillar_abyss_broken.png")],
}

## Datos del escenario (ver BIOMES en arena.gd): "props" y "flame".
var palette: Dictionary = {}
@export var broken_chance: float = 0.3
@export var torch_chance: float = 0.45

var _sprite: Sprite2D
var _light: PointLight2D
var _light_energy: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	var style: String = palette.get("props", "dungeon")
	var broken := randf() < broken_chance
	var texture: Texture2D = TEXTURES.get(style, TEXTURES["dungeon"])[1 if broken else 0]

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.scale = Vector2.ONE * PIXEL_SCALE
	_sprite.position = Vector2(-texture.get_width() * PIXEL_SCALE / 2.0, -texture.get_height() * PIXEL_SCALE + 6)
	_sprite.flip_h = randf() < 0.5 and broken
	add_child(_sprite)

	var body := StaticBody2D.new()
	body.collision_layer = 3 # mundo + paredes: bloquea a todos y a los proyectiles
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = FOOT
	shape.shape = rect
	shape.position = Vector2(0, -FOOT.y / 2.0)
	body.add_child(shape)
	add_child(body)

	if not broken and randf() < torch_chance:
		_add_torch(palette.get("flame", Color(1.0, 0.6, 0.25)))

	# Aparece desde el suelo.
	_sprite.scale.y = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale:y", PIXEL_SCALE, 0.35)


func footprint() -> Rect2:
	return Rect2(position - Vector2(FOOT.x / 2.0, FOOT.y), FOOT)


## Antorcha en la cara frontal: soporte, llama de particulas y luz.
func _add_torch(flame_color: Color) -> void:
	var height := _sprite.texture.get_height() * PIXEL_SCALE
	var mount := Vector2(0, -height * 0.55)

	var torch := Sprite2D.new()
	torch.texture = TORCH_TEXTURE
	torch.scale = Vector2.ONE * PIXEL_SCALE
	torch.position = mount
	add_child(torch)

	var flame := CPUParticles2D.new()
	flame.position = mount + Vector2(0, -16)
	flame.amount = 18
	flame.lifetime = 0.45
	flame.direction = Vector2.UP
	flame.spread = 18.0
	flame.initial_velocity_min = 25.0
	flame.initial_velocity_max = 45.0
	flame.gravity = Vector2(0, -40)
	flame.scale_amount_min = 3.0
	flame.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.add_point(0.35, flame_color)
	ramp.set_color(ramp.get_point_count() - 1, Color(flame_color.r * 0.5, flame_color.g * 0.2, flame_color.b * 0.2, 0.0))
	flame.color_ramp = ramp
	add_child(flame)

	_light = PointLight2D.new()
	_light.texture = LIGHT_TEXTURE
	_light.texture_scale = 2.6
	_light.color = flame_color
	_light.energy = 0.65
	_light.position = mount + Vector2(0, -14)
	_light_energy = _light.energy
	add_child(_light)
	_time = randf() * 10.0


func _process(delta: float) -> void:
	if _light == null:
		set_process(false)
		return
	# Parpadeo de fuego: dos senos desfasados y algo de ruido.
	_time += delta
	var flicker := 0.85 + 0.1 * sin(_time * 9.0) + 0.06 * sin(_time * 23.0) + randf_range(-0.04, 0.04)
	_light.energy = _light_energy * flicker
