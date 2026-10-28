extends CanvasLayer
## Menu de pausa (Esc): continuar, reiniciar o salir. Muestra los
## controles y los records actuales. Construye su interfaz por codigo.

## Si la pantalla de Game Over esta visible, Esc no abre la pausa.
var game_over_screen: CanvasLayer

var _continue_button: Button


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
	dim.color = Color(0.02, 0.0, 0.05, 0.7)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var titulo := Label.new()
	titulo.text = "PAUSA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 56)
	titulo.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	box.add_child(titulo)

	_continue_button = _add_button(box, "Continuar", _resume)
	_add_button(box, "Reiniciar", _restart)
	_add_button(box, "Salir", func(): get_tree().quit())

	var controles := Label.new()
	controles.text = "WASD mover  ·  J / Click atacar  ·  Espacio dash  ·  E equipar arma\nMata durante el dash para recargarlo al instante"
	controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controles.add_theme_font_size_override("font_size", 14)
	controles.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	box.add_child(controles)

	var records := Label.new()
	records.name = "Records"
	records.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	records.add_theme_font_size_override("font_size", 14)
	records.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	box.add_child(records)


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
	visible = true
	get_tree().paused = true
	_continue_button.grab_focus()


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
