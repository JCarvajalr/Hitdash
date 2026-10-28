extends Label



func show_damage(amount: int, color: Color = Color.TRANSPARENT, crit: bool = false):
	if crit:
		show_text("¡CRIT! -" + str(amount), color, 1.35)
	else:
		show_text("-" + str(amount), color)


## Muestra un texto flotante con el mismo efecto que los numeros de dano.
## Si `color` es transparente se mantiene el color de la escena.
func show_text(message: String, color: Color = Color.TRANSPARENT, size_mult: float = 1.0):
	text = message
	z_index = 200
	if color.a > 0.0 and label_settings != null:
		label_settings = label_settings.duplicate()
		label_settings.font_color = color

	# Centrar el texto sobre el punto donde se genera.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	pivot_offset = size / 2.0
	position -= size / 2.0

	var original_position := position

	# Aparece un poco más grande
	scale = Vector2(0.5, 0.5) * size_mult

	var appear_tween := create_tween()
	appear_tween.set_parallel(true)

	appear_tween.tween_property(
		self,
		"scale",
		Vector2(1.2, 1.2) * size_mult,
		0.08
	)

	await appear_tween.finished

	# Pequeño temblor
	for i in range(5):
		var offset := Vector2(
			randf_range(-4.0, 4.0),
			randf_range(-3.0, 3.0)
		)

		var shake := create_tween()
		shake.tween_property(
			self,
			"position",
			original_position + offset,
			0.04
		)

		await shake.finished

	# Volver a la posición
	var return_tween := create_tween()
	return_tween.tween_property(
		self,
		"position",
		original_position,
		0.04
	)

	await return_tween.finished

	# Subir y desaparecer
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)

	fade_tween.tween_property(
		self,
		"position",
		original_position + Vector2(0, -30),
		0.4
	)

	fade_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.4
	)

	await fade_tween.finished
	queue_free()
