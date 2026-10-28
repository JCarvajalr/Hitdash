extends Boss
## Reina Carnivora: planta gigante que embiste y llena la arena de semillas.
## Fase 1: embestida con aviso y rafagas en anillo.
## Fase 2: se vuelve mas rapida, dispara en espiral e invoca plantas escupidoras.

@export var minion_scene: PackedScene = preload("res://Entities/Enemies/plants/plant_spitter.tscn")
@export var lunge_speed: float = 620.0
@export var lunge_time: float = 0.38


func _init() -> void:
	boss_name = "Reina Carnivora"
	boss_title = "Senora del Invernadero"
	bolt_color = Color(0.55, 1.0, 0.35)
	max_health = 1400.0
	attack_damage = 12.0
	contact_damage = 18.0
	speed = 60.0
	boss_scale = 5.5
	body_radius = 8.0


func _build_frames() -> SpriteFrames:
	return SpriteSheets.build({
		"idle": [preload("res://sprites/characters/plantmob/plant1_idle.png"), 6.0, true],
		"run": [preload("res://sprites/characters/plantmob/plant1_run.png"), 10.0, true],
		"attack": [preload("res://sprites/characters/plantmob/plant1_attack.png"), 12.0, false],
		"death": [preload("res://sprites/characters/plantmob/plant1_death.png"), 9.0, false],
	})


func _choose_attack() -> void:
	var options := ["lunge", "lunge", "burst"]
	if phase == 2:
		options.append_array(["spiral", "summon", "lunge"])
	match options.pick_random():
		"lunge":
			await _lunge()
		"burst":
			await _seed_burst()
		"spiral":
			await _spiral()
		"summon":
			await _summon()


## Embestida: avisa, fija la direccion y sale disparada hacia el jugador.
func _lunge() -> void:
	face_player()
	await telegraph(0.55, 16.0, Color(1.0, 0.25, 0.2))
	if is_dead:
		return
	var dir := face_player()
	play_once("attack", 1.4)
	velocity = dir * lunge_speed
	await wait(lunge_time)
	velocity = Vector2.ZERO
	if is_dead:
		return
	Sfx.play("slam")
	Combat.shake(8.0)
	if phase == 2:
		fire_ring(10, 200.0, randf() * TAU)
	await wait(0.45)


## Rafaga de semillas en anillo (dos anillos desfasados en fase 2).
func _seed_burst() -> void:
	face_player()
	await telegraph(0.45, 12.0, Color(0.5, 1.0, 0.3))
	if is_dead:
		return
	play_once("attack")
	var count := 16 if phase == 2 else 12
	var start := randf() * TAU
	fire_ring(count, 190.0, start)
	if phase == 2:
		await wait(0.3)
		if not is_dead:
			fire_ring(count, 230.0, start + PI / count)
	await wait(0.5)


## Espiral de dos brazos durante unos segundos.
func _spiral() -> void:
	await telegraph(0.4, 14.0, Color(0.8, 1.0, 0.3))
	var angle := randf() * TAU
	for i in 34:
		if is_dead:
			return
		fire_bolt(Vector2.RIGHT.rotated(angle), 210.0, 0.8)
		fire_bolt(Vector2.RIGHT.rotated(angle + PI), 210.0, 0.8)
		if i % 4 == 0:
			Sfx.play("bolt", 0.1, -8.0)
		angle += 0.33
		await wait(0.07)
	await wait(0.4)


func _summon() -> void:
	face_player()
	await play_once("attack", 0.8)
	if is_dead:
		return
	var target := player.global_position if is_instance_valid(player) else global_position
	summon(minion_scene, 3, target, 200.0, 4)
	await wait(0.6)
