class_name Items
extends RefCounted
## Catalogo de armas y reliquias, y los dibujos (hechos por codigo) de sus
## iconos. Las armas cambian como ataca el jugador; las reliquias son
## mejoras pasivas que se acumulan durante la partida.

## Campos de cada arma:
##  damage: multiplicador de dano  ·  speed: velocidad de la animacion de ataque
##  reach: tamano del golpe  ·  crit: probabilidad de critico extra
##  effect: "none", "lifesteal", "chain", "burn", "wave"
const WEAPONS := {
	"sword": {
		"name": "Espada del Recluta",
		"desc": "Fiable. Nada mas.",
		"color": Color(0.85, 0.88, 0.95),
		"damage": 1.0, "speed": 1.0, "reach": 1.0, "crit": 0.0,
		"effect": "none",
	},
	"crimson": {
		"name": "Hoja Carmesi",
		"desc": "Cada golpe te devuelve vida.",
		"color": Color(0.95, 0.2, 0.3),
		"damage": 1.1, "speed": 1.05, "reach": 1.0, "crit": 0.0,
		"effect": "lifesteal",
	},
	"storm": {
		"name": "Mandoble de Tormenta",
		"desc": "Lento y brutal. Los rayos saltan a enemigos cercanos.",
		"color": Color(0.45, 0.75, 1.0),
		"damage": 1.8, "speed": 0.75, "reach": 1.45, "crit": 0.0,
		"effect": "chain",
	},
	"daggers": {
		"name": "Dagas Gemelas",
		"desc": "Golpes rapidisimos y criticos frecuentes.",
		"color": Color(0.7, 1.0, 0.55),
		"damage": 0.7, "speed": 1.7, "reach": 0.9, "crit": 0.2,
		"effect": "none",
	},
	"inferno": {
		"name": "Filo del Infierno",
		"desc": "Prende fuego a lo que toca.",
		"color": Color(1.0, 0.55, 0.15),
		"damage": 1.15, "speed": 1.0, "reach": 1.1, "crit": 0.0,
		"effect": "burn",
	},
	"arcane": {
		"name": "Hoja Arcana",
		"desc": "Cada tajo lanza una onda que atraviesa enemigos.",
		"color": Color(0.8, 0.45, 1.0),
		"damage": 1.0, "speed": 1.0, "reach": 1.0, "crit": 0.05,
		"effect": "wave",
	},
}

const RELICS := {
	"heart": {
		"name": "Corazon de Dragon",
		"desc": "+25 de vida maxima y curacion completa.",
		"color": Color(1.0, 0.3, 0.4),
	},
	"boots": {
		"name": "Botas Aladas",
		"desc": "+15% velocidad y dash mas frecuente.",
		"color": Color(0.4, 0.9, 1.0),
	},
	"fang": {
		"name": "Colmillo Afilado",
		"desc": "+10% de critico y criticos mas fuertes.",
		"color": Color(1.0, 0.85, 0.3),
	},
	"whetstone": {
		"name": "Piedra de Afilar",
		"desc": "+20% de dano con todo.",
		"color": Color(0.75, 0.75, 0.8),
	},
	"aegis": {
		"name": "Egida",
		"desc": "Escudo que bloquea los proximos 3 golpes.",
		"color": Color(0.5, 0.8, 1.0),
	},
	"hourglass": {
		"name": "Reloj de Arena",
		"desc": "+0.8 s para encadenar combos.",
		"color": Color(0.95, 0.75, 0.45),
	},
}


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["sword"])


static func item_name(kind: String, id: String) -> String:
	var table: Dictionary = WEAPONS if kind == "weapon" else RELICS
	return table[id]["name"] if table.has(id) else id


static func item_desc(kind: String, id: String) -> String:
	var table: Dictionary = WEAPONS if kind == "weapon" else RELICS
	return table[id]["desc"] if table.has(id) else ""


static func item_color(kind: String, id: String) -> Color:
	var table: Dictionary = WEAPONS if kind == "weapon" else RELICS
	return table[id]["color"] if table.has(id) else Color.WHITE


## Arma al azar distinta de `exclude` (y nunca la espada inicial).
static func random_weapon(exclude: String = "") -> String:
	var options: Array = WEAPONS.keys().filter(func(k): return k != "sword" and k != exclude)
	return options.pick_random()


static func random_relic() -> String:
	return RELICS.keys().pick_random()


# --- Iconos -------------------------------------------------------------

## Dibuja el icono de un objeto centrado en `center` sobre `canvas`.
## `size` es aproximadamente el alto del icono en pixeles.
static func draw_icon(canvas: CanvasItem, kind: String, id: String, center: Vector2, size: float) -> void:
	if kind == "weapon":
		_draw_weapon(canvas, id, center, size)
	else:
		_draw_relic(canvas, id, center, size)


static func _draw_weapon(canvas: CanvasItem, id: String, c: Vector2, s: float) -> void:
	var col := item_color("weapon", id)
	match id:
		"daggers":
			_draw_blade(canvas, c + Vector2(-s * 0.14, 0), s * 0.7, s * 0.09, col, -0.35)
			_draw_blade(canvas, c + Vector2(s * 0.14, 0), s * 0.7, s * 0.09, col, 0.35)
		"storm":
			_draw_blade(canvas, c, s * 1.05, s * 0.2, col, 0.0)
			# Rayo sobre la hoja.
			var bolt := PackedVector2Array([
				c + Vector2(-s * 0.05, -s * 0.35), c + Vector2(s * 0.06, -s * 0.12),
				c + Vector2(-s * 0.03, -s * 0.1), c + Vector2(s * 0.05, s * 0.12),
			])
			canvas.draw_polyline(bolt, Color(1, 1, 0.7), maxf(s * 0.05, 1.0))
		"inferno":
			_draw_blade(canvas, c, s * 0.95, s * 0.15, col, 0.0)
			canvas.draw_circle(c + Vector2(0, -s * 0.42), s * 0.1, Color(1.0, 0.9, 0.3, 0.9))
			canvas.draw_circle(c + Vector2(0, -s * 0.3), s * 0.07, Color(1.0, 0.35, 0.1, 0.8))
		"arcane":
			_draw_blade(canvas, c, s * 0.95, s * 0.14, col, 0.0)
			canvas.draw_circle(c + Vector2(0, s * 0.1), s * 0.08, Color(1.0, 0.85, 1.0))
		_:
			_draw_blade(canvas, c, s * 0.95, s * 0.13, col, 0.0)


## Una espada: hoja con punta, guarda y empunadura. `tilt` en radianes.
static func _draw_blade(canvas: CanvasItem, c: Vector2, length: float, width: float, col: Color, tilt: float) -> void:
	var t := Transform2D(tilt, c)
	var blade_top := -length * 0.5
	var guard_y := length * 0.18
	var blade := PackedVector2Array([
		Vector2(0, blade_top), Vector2(width * 0.5, blade_top + width * 0.9),
		Vector2(width * 0.5, guard_y), Vector2(-width * 0.5, guard_y),
		Vector2(-width * 0.5, blade_top + width * 0.9),
	])
	var outline := Color(0.05, 0.03, 0.06)
	canvas.draw_colored_polygon(t * blade, col)
	var closed := blade.duplicate()
	closed.append(blade[0])
	canvas.draw_polyline(t * closed, outline, maxf(width * 0.12, 1.0))
	# Brillo central de la hoja.
	canvas.draw_line(t * Vector2(0, blade_top + width), t * Vector2(0, guard_y - width * 0.3), col.lightened(0.6), maxf(width * 0.15, 1.0))
	# Guarda y empunadura.
	canvas.draw_line(t * Vector2(-width * 1.3, guard_y), t * Vector2(width * 1.3, guard_y), Color(0.85, 0.7, 0.3), maxf(width * 0.45, 1.5))
	canvas.draw_line(t * Vector2(0, guard_y), t * Vector2(0, length * 0.5), Color(0.4, 0.25, 0.15), maxf(width * 0.4, 1.5))
	canvas.draw_circle(t * Vector2(0, length * 0.5), maxf(width * 0.3, 1.2), Color(0.85, 0.7, 0.3))


static func _draw_relic(canvas: CanvasItem, id: String, c: Vector2, s: float) -> void:
	var col := item_color("relic", id)
	var outline := Color(0.05, 0.03, 0.06)
	match id:
		"heart":
			canvas.draw_circle(c + Vector2(-s * 0.18, -s * 0.1), s * 0.22, col)
			canvas.draw_circle(c + Vector2(s * 0.18, -s * 0.1), s * 0.22, col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.39, -s * 0.02), c + Vector2(s * 0.39, -s * 0.02), c + Vector2(0, s * 0.4),
			]), col)
			canvas.draw_circle(c + Vector2(-s * 0.2, -s * 0.16), s * 0.06, Color(1, 1, 1, 0.8))
		"boots":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.2, -s * 0.35), c + Vector2(s * 0.1, -s * 0.35), c + Vector2(s * 0.1, s * 0.1),
				c + Vector2(s * 0.35, s * 0.2), c + Vector2(s * 0.35, s * 0.35), c + Vector2(-s * 0.2, s * 0.35),
			]), col)
			# Alita.
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.2, -s * 0.2), c + Vector2(-s * 0.45, -s * 0.35), c + Vector2(-s * 0.4, -s * 0.05),
			]), Color(1, 1, 1, 0.9))
		"fang":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.25, -s * 0.35), c + Vector2(s * 0.25, -s * 0.35), c + Vector2(0, s * 0.4),
			]), Color(0.98, 0.95, 0.85))
			canvas.draw_line(c + Vector2(-s * 0.25, -s * 0.35), c + Vector2(s * 0.25, -s * 0.35), col, maxf(s * 0.1, 1.5))
		"whetstone":
			var rect := Rect2(c - Vector2(s * 0.4, s * 0.17), Vector2(s * 0.8, s * 0.34))
			canvas.draw_rect(rect, col)
			canvas.draw_rect(rect, outline, false, maxf(s * 0.05, 1.0))
			canvas.draw_line(c + Vector2(-s * 0.3, -s * 0.05), c + Vector2(s * 0.3, -s * 0.05), Color(1, 1, 1, 0.6), maxf(s * 0.04, 1.0))
		"aegis":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.35, -s * 0.38), c + Vector2(s * 0.35, -s * 0.38), c + Vector2(s * 0.32, s * 0.05),
				c + Vector2(0, s * 0.42), c + Vector2(-s * 0.32, s * 0.05),
			]), col)
			canvas.draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), Color(1, 1, 1, 0.8), maxf(s * 0.06, 1.0))
			canvas.draw_line(c + Vector2(-s * 0.25, -s * 0.1), c + Vector2(s * 0.25, -s * 0.1), Color(1, 1, 1, 0.8), maxf(s * 0.06, 1.0))
		"hourglass":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.28, -s * 0.38), c + Vector2(s * 0.28, -s * 0.38), c + Vector2(0, 0),
			]), col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, 0), c + Vector2(s * 0.28, s * 0.38), c + Vector2(-s * 0.28, s * 0.38),
			]), col.darkened(0.25))
			canvas.draw_line(c + Vector2(-s * 0.34, -s * 0.4), c + Vector2(s * 0.34, -s * 0.4), Color(0.5, 0.3, 0.15), maxf(s * 0.08, 1.5))
			canvas.draw_line(c + Vector2(-s * 0.34, s * 0.4), c + Vector2(s * 0.34, s * 0.4), Color(0.5, 0.3, 0.15), maxf(s * 0.08, 1.5))
		_:
			canvas.draw_circle(c, s * 0.35, col)
