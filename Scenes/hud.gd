extends CanvasLayer
## HUD del jugador: barra de vida, oleada actual, bajas, enemigos vivos,
## puntuacion, el medidor de estilo (combo + rango D -> SSS) y la barra
## de vida de los jefes.
## Construye su interfaz por codigo para no depender de nodos de escena.

var _health_bar: ProgressBar
var _health_label: Label
var _wave_label: Label
var _kills_label: Label
var _enemies_label: Label
var _banner: Label

var _score_label: Label
var _style_box: VBoxContainer
var _rank_label: Label
var _rank_title: Label
var _combo_label: Label
var _combo_bar: ProgressBar
var _style_tween: Tween
var _banner_tween: Tween
var _shown_score: float = 0.0
var _boss_panel: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_trail: ProgressBar
var _boss_trail_tween: Tween

var _weapon_icon: IconView
var _weapon_name: Label
var _weapon_desc: Label
var _relic_row: HBoxContainer
var _shield_label: Label
var _toast: Label
var _toast_tween: Tween
var _target_score: int = 0

var _kills: int = 0


func _ready() -> void:
	layer = 10
	_build_ui()
	set_process(true)
	Combat.combo_changed.connect(_on_combo_changed)
	Combat.rank_changed.connect(_on_rank_changed)
	Combat.combo_dropped.connect(_on_combo_dropped)
	Combat.score_changed.connect(_on_score_changed)


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

	_build_score()
	_build_style_meter()
	_build_boss_bar()
	_build_inventory()


## Panel de abajo a la izquierda: arma equipada, reliquias y escudo.
func _build_inventory() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 16
	panel.offset_bottom = -16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.07, 0.72)
	style.border_color = Color(0.9, 0.75, 0.5, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 8)
	weapon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(weapon_row)

	_weapon_icon = IconView.new()
	_weapon_icon.kind = "weapon"
	_weapon_icon.custom_minimum_size = Vector2(44, 44)
	weapon_row.add_child(_weapon_icon)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_row.add_child(texts)
	_weapon_name = Label.new()
	_weapon_name.add_theme_font_size_override("font_size", 15)
	texts.add_child(_weapon_name)
	_weapon_desc = Label.new()
	_weapon_desc.add_theme_font_size_override("font_size", 11)
	_weapon_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	texts.add_child(_weapon_desc)

	_relic_row = HBoxContainer.new()
	_relic_row.add_theme_constant_override("separation", 4)
	_relic_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_relic_row)

	_shield_label = Label.new()
	_shield_label.add_theme_font_size_override("font_size", 12)
	_shield_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_shield_label.visible = false
	column.add_child(_shield_label)

	# Aviso de objeto recogido, encima del panel.
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toast.offset_left = 18
	_toast.offset_top = -170
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.modulate.a = 0.0
	add_child(_toast)


func setup_inventory(player: Node) -> void:
	if _weapon_icon == null:
		return
	player.weapon_changed.connect(_on_weapon_changed)
	player.relics_changed.connect(_on_relics_changed)
	player.shield_changed.connect(_on_shield_changed)
	player.item_collected.connect(_on_item_collected)
	_on_weapon_changed(player.weapon_id)


func _on_weapon_changed(weapon_id: String) -> void:
	var data := Items.weapon(weapon_id)
	_weapon_icon.item_id = weapon_id
	_weapon_icon.queue_redraw()
	_weapon_name.text = data["name"]
	_weapon_name.add_theme_color_override("font_color", data["color"])
	_weapon_desc.text = data["desc"]


func _on_relics_changed(relics: Dictionary) -> void:
	for child in _relic_row.get_children():
		child.queue_free()
	for id in relics:
		var icon := IconView.new()
		icon.kind = "relic"
		icon.item_id = id
		icon.count = relics[id]
		icon.custom_minimum_size = Vector2(28, 28)
		_relic_row.add_child(icon)


func _on_shield_changed(charges: int) -> void:
	_shield_label.visible = charges > 0
	_shield_label.text = "Escudo: %d %s" % [charges, "golpe" if charges == 1 else "golpes"]


func _on_item_collected(kind: String, item_id: String) -> void:
	var prefix := "Nueva arma" if kind == "weapon" else "Reliquia"
	_toast.text = "%s: %s\n%s" % [prefix, Items.item_name(kind, item_id), Items.item_desc(kind, item_id)]
	_toast.add_theme_color_override("font_color", Items.item_color(kind, item_id))
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


## Mensaje grande en el centro (sala despejada, etc.).
func show_message(text: String) -> void:
	_show_banner(text)


## Icono de arma o reliquia dibujado por codigo (ver Items.draw_icon).
class IconView extends Control:
	var kind: String = "weapon"
	var item_id: String = "sword"
	var count: int = 1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, Color(0, 0, 0, 0.35))
		draw_rect(box, Items.item_color(kind, item_id).darkened(0.3), false, 1.0)
		Items.draw_icon(self, kind, item_id, size / 2.0, size.y * 0.8)
		if count > 1:
			draw_string(ThemeDB.fallback_font, Vector2(size.x - 14, size.y - 2), "x%d" % count,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


## Barra de jefe abajo en el centro, con una "estela" blanca que baja
## con retraso para que se lea cuanto dano hizo cada golpe.
func _build_boss_bar() -> void:
	_boss_panel = VBoxContainer.new()
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_boss_panel.offset_left = -300
	_boss_panel.offset_right = 300
	_boss_panel.offset_bottom = -28
	_boss_panel.add_theme_constant_override("separation", 4)
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	add_child(_boss_panel)

	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 20)
	_boss_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
	_boss_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_boss_name.add_theme_constant_override("outline_size", 6)
	_boss_panel.add_child(_boss_name)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(600, 16)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_child(stack)

	_boss_trail = _make_boss_bar(Color(1, 1, 1, 0.85), Color(0.06, 0.04, 0.06, 0.85))
	stack.add_child(_boss_trail)
	_boss_bar = _make_boss_bar(Color(0.85, 0.15, 0.2), Color(0, 0, 0, 0))
	stack.add_child(_boss_bar)


func _make_boss_bar(fill_color: Color, bg_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.show_percentage = false
	bar.step = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.set_corner_radius_all(3)
	if bg_color.a > 0.0:
		bg.border_color = Color(0.9, 0.75, 0.5, 0.8)
		bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func show_boss(boss: Node) -> void:
	if _boss_panel == null:
		return
	var max_hp: float = boss.get("max_health")
	_boss_name.text = "%s  -  %s" % [boss.get("boss_name"), boss.get("boss_title")]
	for bar in [_boss_bar, _boss_trail]:
		bar.max_value = max_hp
		bar.value = max_hp
	(_boss_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.85, 0.15, 0.2)
	boss.connect("health_changed", _on_boss_health_changed)
	boss.connect("phase_changed", _on_boss_phase_changed)
	_boss_panel.visible = true
	_boss_panel.modulate.a = 0.0
	create_tween().tween_property(_boss_panel, "modulate:a", 1.0, 0.5)
	_show_banner(str(boss.get("boss_name")).to_upper())


func hide_boss() -> void:
	if _boss_panel == null or not _boss_panel.visible:
		return
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_boss_panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): _boss_panel.visible = false)
	_show_banner("JEFE DERROTADO")


func _on_boss_health_changed(current: float, _maximum: float) -> void:
	_boss_bar.value = current
	if _boss_trail_tween != null and _boss_trail_tween.is_valid():
		_boss_trail_tween.kill()
	_boss_trail_tween = create_tween()
	_boss_trail_tween.tween_interval(0.35)
	_boss_trail_tween.tween_property(_boss_trail, "value", current, 0.4)


func _on_boss_phase_changed(_phase: int) -> void:
	(_boss_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(1.0, 0.4, 0.1)
	_show_banner("¡FASE 2!")


func _build_score() -> void:
	_score_label = Label.new()
	_score_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_score_label.offset_top = 14
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_label.text = "0"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 30)
	_score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_score_label.add_theme_constant_override("outline_size", 6)
	add_child(_score_label)


## Medidor de estilo: letra de rango enorme, titulo, combo y barra de tiempo.
func _build_style_meter() -> void:
	_style_box = VBoxContainer.new()
	_style_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_style_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_style_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_style_box.offset_left = -190
	_style_box.offset_right = -24
	_style_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_style_box.add_theme_constant_override("separation", 2)
	_style_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_box.modulate.a = 0.0
	add_child(_style_box)

	_rank_label = Label.new()
	_rank_label.text = "D"
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rank_label.add_theme_font_size_override("font_size", 72)
	_rank_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_rank_label.add_theme_constant_override("outline_size", 10)
	_rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_box.add_child(_rank_label)

	_rank_title = Label.new()
	_rank_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rank_title.add_theme_font_size_override("font_size", 16)
	_rank_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_rank_title.add_theme_constant_override("outline_size", 4)
	_style_box.add_child(_rank_title)

	_combo_label = Label.new()
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_size_override("font_size", 20)
	_combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_combo_label.add_theme_constant_override("outline_size", 4)
	_style_box.add_child(_combo_label)

	_combo_bar = ProgressBar.new()
	_combo_bar.show_percentage = false
	_combo_bar.custom_minimum_size = Vector2(160, 6)
	_combo_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_combo_bar.max_value = 1.0
	_combo_bar.step = 0.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.75)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	fill.set_corner_radius_all(3)
	_combo_bar.add_theme_stylebox_override("background", bg)
	_combo_bar.add_theme_stylebox_override("fill", fill)
	_style_box.add_child(_combo_bar)


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


## Desvanece todo el HUD (al morir, para que la escena quede limpia).
func fade_out(duration: float = 0.6) -> void:
	var tween := create_tween().set_parallel(true).set_ignore_time_scale(true)
	for child in get_children():
		if child is CanvasItem:
			tween.tween_property(child, "modulate:a", 0.0, duration)


func _show_banner(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.modulate.a = 0.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	_banner_tween.tween_interval(1.3)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	if _enemies_label != null:
		_enemies_label.text = "Enemigos: %d" % get_tree().get_nodes_in_group("Enemy").size()

	# La puntuacion "cuenta" hacia arriba en vez de saltar.
	if _score_label != null and roundi(_shown_score) != _target_score:
		_shown_score = move_toward(_shown_score, _target_score, maxf(absf(_target_score - _shown_score) * 10.0, 60.0) * delta)
		_score_label.text = str(roundi(_shown_score))

	if _combo_bar != null and Combat.combo > 0:
		_combo_bar.value = Combat.combo_time_left / Combat.current_combo_window()


# --- Estilo -------------------------------------------------------------

func _on_score_changed(score: int) -> void:
	_target_score = score


func _on_combo_changed(combo: int, rank_index: int) -> void:
	if _style_box == null or combo <= 0:
		return
	var color: Color = Combat.RANK_COLORS[rank_index]
	_rank_label.text = Combat.RANKS[rank_index]
	_rank_label.add_theme_color_override("font_color", color)
	_rank_title.text = Combat.RANK_TITLES[rank_index]
	_rank_title.add_theme_color_override("font_color", color)
	_combo_label.text = "x%d COMBO  ·  x%.1f" % [combo, Combat.multiplier()]
	(_combo_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color

	if _style_tween != null and _style_tween.is_valid():
		_style_tween.kill()
	_style_box.modulate.a = 1.0
	# Pequeno "pulso" del contador en cada golpe.
	_combo_label.pivot_offset = _combo_label.size * Vector2(1.0, 0.5)
	_combo_label.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_combo_label, "scale", Vector2.ONE, 0.12)


func _on_rank_changed(rank_index: int) -> void:
	if _rank_label == null or rank_index <= 0:
		return
	_rank_label.pivot_offset = _rank_label.size * Vector2(1.0, 0.5)
	_rank_label.scale = Vector2(1.8, 1.8)
	_rank_label.rotation = deg_to_rad(-12)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rank_label, "scale", Vector2.ONE, 0.3)
	tween.tween_property(_rank_label, "rotation", 0.0, 0.3)
	Sfx.play("rank_up", 0.0)
	if rank_index >= 4:
		_show_banner("¡" + Combat.RANK_TITLES[rank_index].to_upper() + "!")


func _on_combo_dropped(final_combo: int) -> void:
	if _style_box == null:
		return
	if final_combo >= Combat.RANK_THRESHOLDS[1]:
		_combo_label.text = "Combo perdido (%d)" % final_combo
	if _style_tween != null and _style_tween.is_valid():
		_style_tween.kill()
	_style_tween = create_tween()
	_style_tween.tween_interval(0.6)
	_style_tween.tween_property(_style_box, "modulate:a", 0.0, 0.4)
