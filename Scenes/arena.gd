extends Node2D
## Escena de combate: conecta al jugador con el HUD, el generador
## de enemigos y la pantalla de Game Over.

@onready var hud: CanvasLayer = $HUD
@onready var game_over_screen: CanvasLayer = $GameOverScreen

var player: MainCharacter = null


func _ready() -> void:
	player = _find_player()
	if player == null:
		push_warning("Arena: no se encontro al MainCharacter en el grupo 'Player'.")
		return

	player.health_changed.connect(hud.update_health)
	player.died.connect(_on_player_died)

	# Estado inicial del HUD (la senal inicial del jugador ya se
	# emitio antes de conectar, por eso lo inicializamos a mano).
	hud.setup(player.max_health)


func _find_player() -> MainCharacter:
	for node in get_tree().get_nodes_in_group("Player"):
		if node is MainCharacter:
			return node
	return null


func _on_player_died() -> void:
	game_over_screen.show_screen()
