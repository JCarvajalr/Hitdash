extends Label



func show_damage(amount: int):
	text = "-" + str(amount)

	var original_position := position

	# Aparece un poco más grande
	scale = Vector2(0.5, 0.5)
	
	var appear_tween := create_tween()
	appear_tween.set_parallel(true)

	appear_tween.tween_property(
		self,
		"scale",
		Vector2(1.2, 1.2),
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
