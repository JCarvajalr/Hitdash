extends CanvasLayer
## HUD del jugador: barra de vida + contador de enemigos.
## Construye su interfaz por codigo para no depender de nodos de escena.

var _health_bar: ProgressBar
var _health_label: Label
var _enemies_label: Label


func _ready() -> void:
	layer = 10
	_build_ui()
	set_process(true)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var vida_box := VBoxContainer.new()
	vida_box.custom_minimum_size = Vector2(260, 0)
	row.add_child(vida_box)

	var titulo := Label.new()
	titulo.text = "VIDA"
	titulo.add_theme_font_size_override("font_size", 14)
	vida_box.add_child(titulo)

	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(260, 22)
	_health_bar.show_percentage = false
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.75)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.23, 0.78, 0.32)
	fill.set_corner_radius_all(4)
	_health_bar.add_theme_stylebox_override("background", bg)
	_health_bar.add_theme_stylebox_override("fill", fill)
	vida_box.add_child(_health_bar)

	_health_label = Label.new()
	_health_label.text = "100 / 100"
	_health_label.add_theme_font_size_override("font_size", 13)
	vida_box.add_child(_health_label)

	_enemies_label = Label.new()
	_enemies_label.text = "Enemigos: 0"
	_enemies_label.add_theme_font_size_override("font_size", 14)
	row.add_child(_enemies_label)


func setup(max_health: float) -> void:
	if _health_bar == null:
		_build_ui()
	_health_bar.max_value = max_health
	_health_bar.value = max_health
	_refresh_health_text()


func update_health(current: float, maximum: float) -> void:
	if _health_bar == null:
		return
	_health_bar.max_value = maximum
	_health_bar.value = current
	_refresh_health_text()

	# Cambia el color de la barra segun el porcentaje de vida.
	var ratio := 0.0 if maximum <= 0.0 else current / maximum
	var fill := _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		if ratio > 0.5:
			fill.bg_color = Color(0.23, 0.78, 0.32)
		elif ratio > 0.25:
			fill.bg_color = Color(0.9, 0.7, 0.15)
		else:
			fill.bg_color = Color(0.85, 0.2, 0.2)


func _refresh_health_text() -> void:
	_health_label.text = "%d / %d" % [roundi(_health_bar.value), roundi(_health_bar.max_value)]


func _process(_delta: float) -> void:
	if _enemies_label != null:
		_enemies_label.text = "Enemigos: %d" % get_tree().get_nodes_in_group("Enemy").size()
