extends Boss
## Conde Vampiro: mantiene la distancia, se teletransporta y castiga con
## abanicos y novas de sangre. En fase 2 dispara doble e invoca vampiros.

@export var minion_scene: PackedScene = preload("res://Entities/Enemies/vampire_1.tscn")
@export var preferred_distance: float = 300.0

var _strafe_sign: float = 1.0


func _init() -> void:
	boss_name = "Conde Vampiro"
	boss_title = "Senor del Castillo"
	bolt_color = Color(1.0, 0.25, 0.35)
	max_health = 1800.0
	attack_damage = 14.0
	contact_damage = 16.0
	speed = 110.0
	boss_scale = 4.2
	body_radius = 9.0
	attack_interval = 1.9
	attack_interval_phase_two = 1.2


func _build_frames() -> SpriteFrames:
	return SpriteSheets.build({
		"idle": [preload("res://sprites/characters/vampire/vampire3_idle.png"), 7.0, true],
		"run": [preload("res://sprites/characters/vampire/vampire3_run.png"), 10.0, true],
		"attack": [preload("res://sprites/characters/vampire/vampire3_attack.png"), 18.0, false],
		"death": [preload("res://sprites/characters/vampire/vampire3_death.png"), 9.0, false],
	})


## Se mueve en circulos alrededor del jugador a media distancia.
func _think(_delta: float) -> void:
	var to_player := _to_player()
	var distance := to_player.length()
	var dir := to_player.normalized()
	var move := dir.orthogonal() * _strafe_sign
	if distance > preferred_distance + 60.0:
		move += dir
	elif distance < preferred_distance - 60.0:
		move -= dir
	if randf() < 0.005:
		_strafe_sign = -_strafe_sign
	velocity = move.normalized() * speed * (1.25 if phase == 2 else 1.0)
	# Si choca con un borde cambia el sentido del giro.
	if get_slide_collision_count() > 0:
		_strafe_sign = -_strafe_sign


func _update_animation() -> void:
	# Siempre mira al jugador aunque se mueva de lado.
	if _anim_locked or is_dead or player == null or not is_instance_valid(player):
		return
	face_player()
	var anim := "run_" if velocity.length() > 5.0 else "idle_"
	sprite.play(anim + SpriteSheets.direction_label(facing))


func _choose_attack() -> void:
	var options := ["fan", "fan", "teleport", "nova"]
	if phase == 2:
		options.append_array(["summon", "teleport"])
	match options.pick_random():
		"fan":
			await _fan()
		"teleport":
			await _teleport()
		"nova":
			await _nova()
		"summon":
			await _summon()


func _fan() -> void:
	face_player()
	await telegraph(0.35, 10.0, Color(1.0, 0.2, 0.3))
	var volleys := 2 if phase == 2 else 1
	for v in volleys:
		if is_dead:
			return
		var aim := face_player()
		play_once("attack", 1.3)
		fire_fan(aim, 7 if phase == 2 else 5, 55.0, 280.0)
		await wait(0.35)
	await wait(0.3)


## Desaparece, reaparece lejos del jugador y dispara al instante.
func _teleport() -> void:
	_invulnerable = true
	Sfx.play("teleport")
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.25)
	await fade_out.finished
	if is_dead:
		return
	global_position = random_arena_point(260.0)
	await wait(0.35)
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.2)
	Sfx.play("teleport", 0.1)
	await fade_in.finished
	_invulnerable = false
	if is_dead:
		return
	var aim := face_player()
	play_once("attack", 1.4)
	fire_fan(aim, 3 if phase == 1 else 5, 30.0, 320.0)
	await wait(0.3)


func _nova() -> void:
	await telegraph(0.6, 18.0, Color(0.8, 0.1, 0.3))
	if is_dead:
		return
	play_once("attack")
	var start := randf() * TAU
	fire_ring(20, 150.0, start)
	if phase == 2:
		await wait(0.45)
		if not is_dead:
			fire_ring(20, 190.0, start + PI / 20.0)
	await wait(0.5)


func _summon() -> void:
	await play_once("attack", 0.9)
	if is_dead:
		return
	summon(minion_scene, 2, global_position, 90.0, 3)
	await wait(0.5)
