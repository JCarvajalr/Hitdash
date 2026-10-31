extends CanvasLayer
## Menu de pausa (Esc): continuar, opciones de volumen, reiniciar, menu principal o salir.
## Muestra los controles y los records actuales. Construye su interfaz por codigo.

## Si la pantalla de Game Over esta visible, Esc no abre la pausa.
var game_over_screen: CanvasLayer

var _continue_button: Button
var _options_panel: PanelContainer
var _main_box: VBoxContainer


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.0, 0.05, 0.75)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 14)
	center.add_child(_main_box)

	var titulo := Label.new()
	titulo.text = "PAUSA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 56)
	titulo.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	_main_box.add_child(titulo)

	_continue_button = _add_button(_main_box, "Continuar", _resume)
	_add_button(_main_box, "Opciones de Audio", _toggle_options)
	_add_button(_main_box, "Reiniciar", _restart)
	_add_button(_main_box, "Menu Principal", _to_main_menu)
	_add_button(_main_box, "Salir", func(): get_tree().quit())

	var controles := Label.new()
	controles.text = "WASD mover  ·  J / Click atacar  ·  Espacio dash  ·  E equipar arma\nMata durante el dash para recargarlo al instante"
	controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controles.add_theme_font_size_override("font_size", 14)
	controles.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	_main_box.add_child(controles)

	var records := Label.new()
	records.name = "Records"
	records.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	records.add_theme_font_size_override("font_size", 14)
	records.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_main_box.add_child(records)

	# Panel de opciones flotante
	_build_options_panel(root)


func _build_options_panel(parent: Control) -> void:
	_options_panel = PanelContainer.new()
	_options_panel.visible = false
	_options_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.98)
	style.border_color = Color(0.35, 0.65, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 32
	style.content_margin_top = 24
	style.content_margin_right = 32
	style.content_margin_bottom = 24
	_options_panel.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_panel.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "AJUSTES DE AUDIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.35, 0.65, 1.0))
	box.add_child(title)

	var sliders_box := VBoxContainer.new()
	sliders_box.add_theme_constant_override("separation", 14)
	box.add_child(sliders_box)

	_add_volume_row(sliders_box, "Volumen General", Sfx.master_volume, func(v): Sfx.set_master_volume(v))
	_add_volume_row(sliders_box, "Efectos (SFX)", Sfx.sfx_volume, func(v):
		Sfx.set_sfx_volume(v)
		Sfx.play("hit", 0.0, -4.0)
	)
	_add_volume_row(sliders_box, "Música", Sfx.music_volume, func(v): Sfx.set_music_volume(v))

	var close_btn := Button.new()
	close_btn.text = "VOLVER"
	close_btn.custom_minimum_size = Vector2(180, 44)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func():
		_options_panel.visible = false
		_main_box.visible = true
		_continue_button.grab_focus()
	)
	box.add_child(close_btn)

	parent.add_child(_options_panel)


func _add_volume_row(parent: Node, label_text: String, initial_val: float, callback: Callable) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var top_box := HBoxContainer.new()
	row.add_child(top_box)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	top_box.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(initial_val * 100)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	top_box.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_val
	slider.custom_minimum_size = Vector2(280, 22)
	slider.value_changed.connect(func(new_val: float):
		val_lbl.text = "%d%%" % int(new_val * 100)
		callback.call(new_val)
	)
	row.add_child(slider)


func _toggle_options() -> void:
	_main_box.visible = false
	_options_panel.visible = true
	var close_btn := _options_panel.find_children("", "Button", true, false).back() as Button
	if close_btn != null:
		close_btn.grab_focus()


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 48)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if game_over_screen != null and game_over_screen.visible:
		return
	get_viewport().set_input_as_handled()
	if _options_panel.visible:
		_options_panel.visible = false
		_main_box.visible = true
		_continue_button.grab_focus()
		return

	if visible:
		_resume()
	else:
		_pause()


func _pause() -> void:
	Engine.time_scale = 1.0
	var records := find_child("Records", true, false) as Label
	if records != null:
		records.text = "Record: %d pts  ·  combo %d  ·  %s" % [
			Combat.best_score, Combat.best_combo, Combat.format_time(Combat.best_time)
		]
	_options_panel.visible = false
	_main_box.visible = true
	visible = true
	get_tree().paused = true
	_continue_button.grab_focus()


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
