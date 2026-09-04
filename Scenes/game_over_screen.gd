extends CanvasLayer
## Pantalla de "Has muerto". Pausa el juego y permite reiniciar
## con el boton o con Enter / Espacio.

var _root: Control
var _restart_button: Button


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
	titulo.text = "HAS MUERTO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	box.add_child(titulo)

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


func show_screen() -> void:
	visible = true
	get_tree().paused = true
	if _restart_button != null:
		_restart_button.grab_focus()


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
