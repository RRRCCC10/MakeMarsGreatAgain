extends Node

@onready var camera: Camera2D = $"../Camera2D"

var highlight_rect: ColorRect

func _ready() -> void:
	# Crea un ColorRect che farà da highlight visivo
	highlight_rect = ColorRect.new()
	highlight_rect.size = Vector2(GridManager.TILE_SIZE, GridManager.TILE_SIZE)
	# Imposta un colore semi-trasparente (es. verde chiaro con alpha a 0.4)
	highlight_rect.color = Color(0.2, 0.8, 0.2, 0.4)
	# Nascondilo finché il mouse non entra nell'area di gioco
	highlight_rect.visible = false
	# Disabilita le collisioni o l'input sul rettangolo per evitare interferenze
	highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Aggiunge il rettangolo alla scena
	add_child(highlight_rect)

func _process(_delta: float) -> void:
	# Calcola la posizione della tile corrente in base al mouse
	var cell_pos = GridManager.get_mouse_grid_position(camera)
	
	# Converte le coordinate della griglia in coordinate globali pixel
	var world_pos = Vector2(cell_pos.x * GridManager.TILE_SIZE, cell_pos.y * GridManager.TILE_SIZE)
	
	# Posiziona l'highlight sulla tile
	highlight_rect.global_position = world_pos
	highlight_rect.visible = true

func _unhandled_input(event: InputEvent) -> void:
	var cell_pos = GridManager.get_mouse_grid_position(camera)
	
	# Esempio di piazzamento con il clic sinistro usando l'highlight come riferimento
	if event.is_action_pressed("click_left"):
		if GridManager.is_cell_empty(cell_pos):
			GridManager.place_item(cell_pos, "MacchinarioBase")
			print("Piazzato in: ", cell_pos)
