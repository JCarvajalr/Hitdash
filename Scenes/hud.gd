extends CanvasLayer
## HUD del jugador: barra de vida, oleada actual, bajas y enemigos vivos.
## Construye su interfaz por codigo para no depender de nodos de escena.

var _health_bar: ProgressBar
var _health_label: Label
var _wave_label: Label
var _kills_label: Label
var _enemies_label: Label
var _banner: Label

var _kills: int = 0


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
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	# --- Bloque izquierdo: vida ---
	var vida_box := VBoxContainer.new()
	vida_box.custom_minimum_size = Vector2(260, 0)
	vida_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# --- Separador elastico ---
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# --- Bloque derecho: oleada, bajas y enemigos vivos ---
	var wave_box := VBoxContainer.new()
	wave_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	wave_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(wave_box)

	_wave_label = Label.new()
	_wave_label.text = "Oleada 1"
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_label.add_theme_font_size_override("font_size", 18)
	_wave_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	wave_box.add_child(_wave_label)

	_kills_label = Label.new()
	_kills_label.text = "Bajas: 0"
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kills_label.add_theme_font_size_override("font_size", 14)
	wave_box.add_child(_kills_label)

	_enemies_label = Label.new()
	_enemies_label.text = "Enemigos: 0"
	_enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemies_label.add_theme_font_size_override("font_size", 14)
	wave_box.add_child(_enemies_label)

	# --- Cartel central de cambio de oleada ---
	var banner_holder := CenterContainer.new()
	banner_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_holder)

	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	banner_holder.add_child(_banner)


# --- Vida ---------------------------------------------------------------

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
	var ratio: float = 0.0 if maximum <= 0.0 else current / maximum
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


# --- Oleadas ------------------------------------------------------------

func update_wave(_index: int, display_name: String, endless_level: int) -> void:
	if _wave_label == null:
		return
	_wave_label.text = display_name
	# La primera oleada no merece cartel: solo se anuncian los ascensos.
	if _index > 0 or endless_level > 0:
		_show_banner(display_name)


func update_kills(kills: int) -> void:
	_kills = kills
	if _kills_label != null:
		_kills_label.text = "Bajas: %d" % kills


func _show_banner(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	tween.tween_interval(1.3)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _process(_delta: float) -> void:
	if _enemies_label != null:
		_enemies_label.text = "Enemigos: %d" % get_tree().get_nodes_in_group("Enemy").size()
