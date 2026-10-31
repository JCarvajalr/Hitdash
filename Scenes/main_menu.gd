extends Control
## Menu inicial principal para Hitdash: Jugar, Opciones, Controles, Records y Salir.
## Cuenta con fondo animado, titulo estilizado, efectos de sonido y transicion suave.

const ARENA_SCENE_PATH := "res://Scenes/arena.tscn"

var _play_button: Button
var _options_button: Button
var _controls_button: Button
var _records_button: Button
var _quit_button: Button

var _options_panel: PanelContainer
var _controls_panel: PanelContainer
var _records_panel: PanelContainer
var _overlay_dim: ColorRect

var _records_grid: GridContainer

var _floating_title: Label
var _particles: CPUParticles2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	Sfx.play_music("main")
	_animate_intro()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 1. Fondo base oscuro
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.05, 0.09)
	add_child(bg)

	# 2. Textura de suelo decorativa
	var floor_tex := preload("res://sprites/background/floor_bricks.png")
	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = floor_tex
	floor_sprite.position = Vector2(576, 324)
	floor_sprite.scale = Vector2(0.4, 0.5)
	floor_sprite.modulate = Color(0.35, 0.3, 0.45, 0.45)
	add_child(floor_sprite)

	# 3. Particulas ambientales flotantes
	_particles = CPUParticles2D.new()
	_particles.position = Vector2(576, 680)
	_particles.amount = 32
	_particles.lifetime = 4.5
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(600, 10)
	_particles.direction = Vector2(0, -1)
	_particles.spread = 15.0
	_particles.gravity = Vector2(0, -15)
	_particles.initial_velocity_min = 25.0
	_particles.initial_velocity_max = 60.0
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 4.5
	_particles.color = Color(1.0, 0.45, 0.25, 0.6)
	add_child(_particles)

	# 4. Viñeta oscura en bordes
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.0, 0.0, 0.0, 0.35)
	add_child(vignette)

	# 5. Contenedor principal centrado
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_vbox := VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 24)
	center.add_child(main_vbox)

	# --- Encabezado / Logo ---
	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 4)
	main_vbox.add_child(title_box)

	_floating_title = Label.new()
	_floating_title.text = "HITDASH"
	_floating_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floating_title.add_theme_font_size_override("font_size", 76)
	_floating_title.add_theme_color_override("font_color", Color(0.98, 0.25, 0.22))
	_floating_title.add_theme_color_override("font_shadow_color", Color(0.4, 0.05, 0.05, 0.85))
	_floating_title.add_theme_constant_override("shadow_offset_x", 4)
	_floating_title.add_theme_constant_override("shadow_offset_y", 4)
	title_box.add_child(_floating_title)

	var subtitle := Label.new()
	subtitle.text = "— COMBATE VERTIGINOSO —"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	title_box.add_child(subtitle)

	# Separador sutil
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	main_vbox.add_child(sep)

	# --- Botones del Menu ---
	var buttons_vbox := VBoxContainer.new()
	buttons_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_vbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(buttons_vbox)

	_play_button = _create_menu_button("JUGAR", _on_play_pressed)
	buttons_vbox.add_child(_play_button)

	_options_button = _create_menu_button("OPCIONES", _on_options_pressed)
	buttons_vbox.add_child(_options_button)

	_controls_button = _create_menu_button("CONTROLES", _on_controls_pressed)
	buttons_vbox.add_child(_controls_button)

	_records_button = _create_menu_button("RECORDS", _on_records_pressed)
	buttons_vbox.add_child(_records_button)

	_quit_button = _create_menu_button("SALIR", _on_quit_pressed)
	buttons_vbox.add_child(_quit_button)

	# Pie de pagina con version / info
	var footer := Label.new()
	footer.text = "v1.0 · Creado con Godot Engine"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	main_vbox.add_child(footer)

	# 6. Capa de oscurecimiento para modales
	_overlay_dim = ColorRect.new()
	_overlay_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_dim.color = Color(0.02, 0.02, 0.04, 0.75)
	_overlay_dim.visible = false
	add_child(_overlay_dim)

	# 7. Modales de Opciones, Controles y Records
	_build_options_modal()
	_build_controls_modal()
	_build_records_modal()

	_play_button.grab_focus()


func _create_menu_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 48)
	btn.add_theme_font_size_override("font_size", 21)
	
	# Estilo personalizado para el boton
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.11, 0.18, 0.85)
	style_normal.border_color = Color(0.35, 0.32, 0.45)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.14, 0.28, 0.95)
	style_hover.border_color = Color(0.95, 0.75, 0.3)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("focus", style_hover)

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.4, 0.12, 0.15)
	style_pressed.border_color = Color(1.0, 0.3, 0.3)
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.pressed.connect(func():
		Sfx.play("hit", 0.05, -6.0)
		callback.call()
	)
	return btn


func _build_options_modal() -> void:
	_options_panel = PanelContainer.new()
	_options_panel.visible = false
	_options_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.96)
	style.border_color = Color(0.35, 0.65, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 36
	style.content_margin_top = 28
	style.content_margin_right = 36
	style.content_margin_bottom = 28
	_options_panel.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_panel.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var title := Label.new()
	title.text = "AJUSTES DE AUDIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.35, 0.65, 1.0))
	box.add_child(title)

	var sliders_box := VBoxContainer.new()
	sliders_box.add_theme_constant_override("separation", 16)
	box.add_child(sliders_box)

	_add_volume_row(sliders_box, "Volumen General", Sfx.master_volume, func(v): Sfx.set_master_volume(v))
	_add_volume_row(sliders_box, "Efectos (SFX)", Sfx.sfx_volume, func(v):
		Sfx.set_sfx_volume(v)
		Sfx.play("hit", 0.0, -4.0)
	)
	_add_volume_row(sliders_box, "Música", Sfx.music_volume, func(v): Sfx.set_music_volume(v))

	var close_btn := _create_menu_button("CERRAR", _close_modals)
	close_btn.custom_minimum_size = Vector2(180, 44)
	box.add_child(close_btn)

	add_child(_options_panel)


func _add_volume_row(parent: Node, label_text: String, initial_val: float, callback: Callable) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var top_box := HBoxContainer.new()
	row.add_child(top_box)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	top_box.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(initial_val * 100)
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	top_box.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_val
	slider.custom_minimum_size = Vector2(320, 24)
	slider.value_changed.connect(func(new_val: float):
		val_lbl.text = "%d%%" % int(new_val * 100)
		callback.call(new_val)
	)
	row.add_child(slider)


func _build_controls_modal() -> void:
	_controls_panel = PanelContainer.new()
	_controls_panel.visible = false
	_controls_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.96)
	style.border_color = Color(0.85, 0.35, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 32
	style.content_margin_top = 28
	style.content_margin_right = 32
	style.content_margin_bottom = 28
	_controls_panel.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_panel.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	var title := Label.new()
	title.text = "CONTROLES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)

	var control_list := [
		["Movimiento", "W, A, S, D / Flechas"],
		["Atacar", "J / Click Izquierdo"],
		["Dash / Esquivar", "Espacio"],
		["Interactuar / Equipar", "E"],
		["Pausa", "Escape"]
	]
	for item in control_list:
		var action_label := Label.new()
		action_label.text = item[0]
		action_label.add_theme_font_size_override("font_size", 20)
		action_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		grid.add_child(action_label)

		var key_label := Label.new()
		key_label.text = item[1]
		key_label.add_theme_font_size_override("font_size", 20)
		key_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		grid.add_child(key_label)

	var tip := Label.new()
	tip.text = "💡 Consejo: Eliminar enemigos durante el Dash lo recarga de inmediato."
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 15)
	tip.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	box.add_child(tip)

	var close_btn := _create_menu_button("CERRAR", _close_modals)
	close_btn.custom_minimum_size = Vector2(180, 44)
	box.add_child(close_btn)

	add_child(_controls_panel)


func _build_records_modal() -> void:
	_records_panel = PanelContainer.new()
	_records_panel.visible = false
	_records_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.96)
	style.border_color = Color(0.95, 0.75, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 32
	style.content_margin_top = 28
	style.content_margin_right = 32
	style.content_margin_bottom = 28
	_records_panel.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_records_panel.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	var title := Label.new()
	title.text = "SALÓN DE RECORDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	box.add_child(title)

	_records_grid = GridContainer.new()
	_records_grid.columns = 2
	_records_grid.add_theme_constant_override("h_separation", 48)
	_records_grid.add_theme_constant_override("v_separation", 12)
	box.add_child(_records_grid)

	var close_btn := _create_menu_button("CERRAR", _close_modals)
	close_btn.custom_minimum_size = Vector2(180, 44)
	box.add_child(close_btn)

	add_child(_records_panel)


func _update_records_display() -> void:
	for child in _records_grid.get_children():
		child.queue_free()

	var stats := [
		["Mejor Puntuación", str(Combat.best_score) + " pts"],
		["Combo Más Alto", str(Combat.best_combo) + " golpes"],
		["Mayor Tiempo Sobrevivido", Combat.format_time(Combat.best_time)]
	]

	for item in stats:
		var name_label := Label.new()
		name_label.text = item[0]
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		_records_grid.add_child(name_label)

		var val_label := Label.new()
		val_label.text = item[1]
		val_label.add_theme_font_size_override("font_size", 20)
		val_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		_records_grid.add_child(val_label)


func _animate_intro() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_floating_title, "position:y", _floating_title.position.y - 6.0, 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_floating_title, "position:y", _floating_title.position.y, 1.8).set_trans(Tween.TRANS_SINE)


func _on_play_pressed() -> void:
	_play_button.disabled = true
	_options_button.disabled = true
	_controls_button.disabled = true
	_records_button.disabled = true
	_quit_button.disabled = true

	# Transicion suave a negro
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade)

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.45)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(ARENA_SCENE_PATH)
	)


func _on_options_pressed() -> void:
	_overlay_dim.visible = true
	_options_panel.visible = true
	var close_btn := _options_panel.find_children("", "Button", true, false).back() as Button
	if close_btn != null:
		close_btn.grab_focus()


func _on_controls_pressed() -> void:
	_overlay_dim.visible = true
	_controls_panel.visible = true
	var close_btn := _controls_panel.find_children("", "Button", true, false).back() as Button
	if close_btn != null:
		close_btn.grab_focus()


func _on_records_pressed() -> void:
	_update_records_display()
	_overlay_dim.visible = true
	_records_panel.visible = true
	var close_btn := _records_panel.find_children("", "Button", true, false).back() as Button
	if close_btn != null:
		close_btn.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _close_modals() -> void:
	_overlay_dim.visible = false
	_options_panel.visible = false
	_controls_panel.visible = false
	_records_panel.visible = false
	_play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _options_panel.visible or _controls_panel.visible or _records_panel.visible:
			get_viewport().set_input_as_handled()
			_close_modals()
