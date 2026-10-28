class_name RoomBuilder
extends RefCounted
## Genera la distribucion de cada sala: pilares (bloquean el paso y los
## proyectiles, sirven de cobertura) y cajas rompibles. Las salas de jefe
## salen vacias para que haya sitio para pelear.

const Pillar := preload("res://Scenes/rooms/pillar.gd")
const Crate := preload("res://Scenes/rooms/crate.gd")

## Zona jugable (dentro de los muros de la arena).
const PLAY_AREA := Rect2(70, 70, 1012, 510)
## Por donde entra el jugador a cada sala nueva.
const ENTRY_POINT := Vector2(130, 330)
## Zonas que siempre quedan libres: la entrada y el centro (portal y
## posicion inicial del jugador).
const KEEP_CLEAR := [Rect2(60, 240, 210, 180), Rect2(466, 220, 220, 230)]
## Las columnas no pueden tener la base mas arriba que esto: son altas y
## taparian el HUD de arriba.
const PILLAR_MIN_Y := 200.0
## Alto aproximado del dibujo de una columna sobre su base.
const PILLAR_VISUAL_HEIGHT := 150.0
const CRATE_MIN_Y := 160.0

const LAYOUTS := ["four", "colonnade", "scatter", "corridor", "ring"]


## Construye una sala dentro de `parent`. Devuelve los rectangulos ocupados
## (para que el spawner no genere enemigos dentro de los obstaculos).
static func build(parent: Node2D, layout: String, palette: Dictionary) -> Array[Rect2]:
	var pillars: Array[Vector2] = []
	match layout:
		"four":
			pillars = [Vector2(330, 200), Vector2(822, 200), Vector2(330, 470), Vector2(822, 470)]
		"colonnade":
			for x in [360, 500, 650, 790]:
				pillars.append(Vector2(x, 210))
				pillars.append(Vector2(x, 490))
		"corridor":
			for y in [230, 400, 565]:
				pillars.append(Vector2(420, y))
				pillars.append(Vector2(740, y))
		"ring":
			# Separadas al menos lo que mide una columna de alto, para que no se monten.
			for i in 6:
				var angle := TAU * i / 6.0 + PI / 6.0
				pillars.append(Vector2(576, 380) + Vector2(cos(angle) * 300.0, sin(angle) * 170.0))
		"scatter":
			pillars = _scatter_points(6, 120.0, [], PILLAR_MIN_Y)
		_:
			pass

	var blocked: Array[Rect2] = []
	# Lo que ocupa cada columna en pantalla (base + altura), para que las
	# cajas no queden escondidas detras.
	var visual: Array[Rect2] = []
	for pos in pillars:
		var pillar := Pillar.new()
		pillar.palette = palette
		pillar.position = pos
		parent.add_child(pillar)
		var foot: Rect2 = pillar.footprint()
		blocked.append(foot)
		visual.append(Rect2(foot.position.x, foot.end.y - PILLAR_VISUAL_HEIGHT, foot.size.x, PILLAR_VISUAL_HEIGHT))

	if layout != "empty":
		for pos in _scatter_points(randi_range(3, 5), 70.0, visual, CRATE_MIN_Y):
			var crate := Crate.new()
			crate.position = pos
			parent.add_child(crate)
			blocked.append(crate.footprint())
			visual.append(crate.footprint())
	return blocked


static func random_layout() -> String:
	return LAYOUTS.pick_random()


## Puntos al azar dentro de la zona jugable, separados entre si y fuera
## de las zonas reservadas y de lo ya ocupado.
static func _scatter_points(count: int, spacing: float, occupied: Array[Rect2] = [], min_y: float = 0.0) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var area := PLAY_AREA.grow(-50)
	if min_y > area.position.y:
		area = Rect2(area.position.x, min_y, area.size.x, area.end.y - min_y)
	for attempt in count * 25:
		if points.size() >= count:
			break
		var p := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if is_blocked(p, occupied, 50.0) or _in_keep_clear(p):
			continue
		var ok := true
		for other in points:
			if other.distance_to(p) < spacing:
				ok = false
				break
		if ok:
			points.append(p)
	return points


static func _in_keep_clear(p: Vector2) -> bool:
	for zone in KEEP_CLEAR:
		if (zone as Rect2).has_point(p):
			return true
	return false


static func is_blocked(p: Vector2, occupied: Array[Rect2], margin: float = 30.0) -> bool:
	for rect in occupied:
		if rect.grow(margin).has_point(p):
			return true
	return false


## Punto libre de obstaculos, lo mas cerca posible de `preferred`.
static func free_point(preferred: Vector2, occupied: Array[Rect2]) -> Vector2:
	if not is_blocked(preferred, occupied, 40.0):
		return preferred
	for ring in range(1, 8):
		for i in 12:
			var p := preferred + Vector2.RIGHT.rotated(TAU * i / 12.0) * ring * 40.0
			if PLAY_AREA.has_point(p) and not is_blocked(p, occupied, 40.0):
				return p
	return preferred
