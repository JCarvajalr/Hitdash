class_name SpriteSheets
extends RefCounted
## Construye SpriteFrames a partir de las hojas de personaje del proyecto:
## cuadros de 64x64 y 4 filas en el orden abajo, arriba, izquierda, derecha.
## Cada animacion "x" genera "x_down", "x_up", "x_left" y "x_right".

const FRAME_SIZE := 64
const DIRECTIONS := ["down", "up", "left", "right"]


## `anims` = { "idle": [textura, fps, loop], ... }
static func build(anims: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim_name in anims:
		var data: Array = anims[anim_name]
		var texture: Texture2D = data[0]
		var fps: float = data[1]
		var loop: bool = data[2]
		var columns := int(texture.get_width() / FRAME_SIZE)
		for row in DIRECTIONS.size():
			var full_name := "%s_%s" % [anim_name, DIRECTIONS[row]]
			frames.add_animation(full_name)
			frames.set_animation_speed(full_name, fps)
			frames.set_animation_loop(full_name, loop)
			for col in columns:
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(col * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
				frames.add_frame(full_name, atlas)
	return frames


## Etiqueta de direccion (down/up/left/right) para un vector.
static func direction_label(direction: Vector2) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"
