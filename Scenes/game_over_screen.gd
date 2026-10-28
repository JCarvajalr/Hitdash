extends CanvasLayer
## Pantalla de "Has muerto". Pausa el juego, muestra las estadisticas de
## la partida frente a los records y permite reiniciar con el boton o con
## Enter / Espacio.

var _root: Control
var _restart_button: Button
var _record_label: Label
var _title: Label
var _stats_grid: GridContainer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var titulo := Label.new()
	_title = titulo
	titulo.text = "HAS MUERTO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	box.add_child(titulo)

	_record_label = Label.new()
	_record_label.text = "¡NUEVO RECORD!"
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record_label.add_theme_font_size_override("font_size", 26)
	_record_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_record_label.visible = false
	box.add_child(_record_label)

	var stats_holder := CenterContainer.new()
	box.add_child(stats_holder)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 3
	_stats_grid.add_theme_constant_override("h_separation", 36)
	_stats_grid.add_theme_constant_override("v_separation", 6)
	stats_holder.add_child(_stats_grid)

	var ayuda := Label.new()
	ayuda.text = "Pulsa Reiniciar o Enter para volver a empezar"
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda.add_theme_font_size_override("font_size", 18)
	box.add_child(ayuda)

	_restart_button = Button.new()
	_restart_button.text = "Reiniciar"
	_restart_button.custom_minimum_size = Vector2(220, 56)
	_restart_button.add_theme_font_size_override("font_size", 24)
	_restart_button.pressed.connect(_on_restart_pressed)
	box.add_child(_restart_button)


func show_screen(wave_name: String = "") -> void:
	var new_record: bool = Combat.commit_records()
	_fill_stats(wave_name)
	_record_label.visible = new_record and Combat.score > 0
	if _record_label.visible:
		var tween := create_tween().set_loops(4)
		tween.tween_property(_record_label, "modulate:a", 0.3, 0.25)
		tween.tween_property(_record_label, "modulate:a", 1.0, 0.25)

	visible = true
	get_tree().paused = true
	if _restart_button != null:
		_restart_button.grab_focus()

	# Entrada: fundido del fondo y el titulo cae con rebote.
	_root.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 1.0, 0.5)
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2(2.2, 2.2)
	var slam := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	slam.tween_property(_title, "scale", Vector2.ONE, 0.6)


func _fill_stats(wave_name: String) -> void:
	for child in _stats_grid.get_children():
		child.queue_free()
	_add_stat_row("", "Partida", "Record", true)
	_add_stat_row("Puntuacion", str(Combat.score), str(Combat.best_score))
	_add_stat_row("Combo maximo", str(Combat.max_combo), str(Combat.best_combo))
	_add_stat_row("Tiempo", Combat.format_time(Combat.run_time), Combat.format_time(Combat.best_time))
	_add_stat_row("Bajas", str(Combat.kills), "")
	if wave_name != "":
		_add_stat_row("Oleada", wave_name, "")


func _add_stat_row(title: String, current: String, best: String, header: bool = false) -> void:
	var dim := Color(0.7, 0.7, 0.75)
	for i in 3:
		var label := Label.new()
		label.text = [title, current, best][i]
		label.add_theme_font_size_override("font_size", 16 if header else 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		if header or i == 0:
			label.add_theme_color_override("font_color", dim)
		elif i == 2:
			label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		_stats_grid.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		# Marcar el input como consumido ANTES de recargar la escena:
		# _on_restart_pressed() libera este nodo y get_viewport() pasa a ser null.
		get_viewport().set_input_as_handled()
		_on_restart_pressed()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
