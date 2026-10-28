class_name Pathing
extends RefCounted
## Navegacion de los enemigos alrededor de pilares y cajas.
## La arena hornea un NavigationPolygon por sala (bake_room) y cada enemigo
## pide su direccion con next_direction(), que recalcula el camino cada
## poco tiempo en vez de cada frame.

## Radio de los enemigos: el camino se separa esto de los obstaculos.
const AGENT_RADIUS := 22.0
## Cada cuanto (segundos) se recalcula el camino de un enemigo.
const REPATH_TIME := 0.25


## Crea (o reemplaza) la region navegable de la sala actual.
static func bake_room(region: NavigationRegion2D, area: Rect2, obstacles: Array[Rect2]) -> void:
	var nav := NavigationPolygon.new()
	nav.agent_radius = AGENT_RADIUS
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_rect_outline(area))
	for rect in obstacles:
		source.add_obstruction_outline(_rect_outline(rect))
	NavigationServer2D.bake_from_source_geometry_data(nav, source)
	region.navigation_polygon = nav


## Direccion (normalizada) que debe seguir `agent` para llegar a `target`
## esquivando obstaculos. Si no hay mapa listo, va en linea recta.
static func next_direction(agent: Node2D, target: Vector2) -> Vector2:
	var from := agent.global_position
	var direct := (target - from).normalized()
	var map := agent.get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		return direct

	var now := Time.get_ticks_msec() / 1000.0
	var path: PackedVector2Array = agent.get_meta("_nav_path", PackedVector2Array())
	var stamp: float = agent.get_meta("_nav_time", -1.0)
	if path.is_empty() or now - stamp >= REPATH_TIME:
		path = NavigationServer2D.map_get_path(map, from, target, true)
		agent.set_meta("_nav_path", path)
		agent.set_meta("_nav_time", now)

	if path.size() < 2:
		return direct
	# Tramo del camino mas cercano al enemigo y se apunta al final de ese
	# tramo, que siempre queda por delante. (Apuntar al "primer punto lejano"
	# hacia que volviera a puntos ya pasados y temblara adelante y atras.)
	var segment := 0
	var best := INF
	for i in path.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(from, path[i], path[i + 1])
		var d := from.distance_squared_to(closest)
		if d < best:
			best = d
			segment = i
	var next := segment + 1
	if from.distance_to(path[next]) < 8.0 and next < path.size() - 1:
		next += 1
	var to_next := path[next] - from
	return to_next.normalized() if to_next.length() > 1.0 else direct


static func _rect_outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
