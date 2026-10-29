extends CharacterBody2D

const SPEED = 300.0
@onready var camera: Camera2D = $Camera2D # Assicurati di avere una Camera2D come figlia del player o nella scena

func _physics_process(delta: float) -> void:
	var direction = movement_input()
	movement(direction)
	update_animations(direction)
	move_and_slide()

func movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func movement(direction: Vector2) -> void:
	if direction:
		velocity = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)

func update_animations(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		pass
	else:
		pass


func _unhandled_input(event: InputEvent) -> void:
	# Usa GridManager direttamente ovunque ti serva la tile_size o le funzioni di griglia
	var cell_pos = GridManager.get_mouse_grid_position(camera)
	
	if event.is_action_pressed("left_click"):
		if GridManager.is_cell_empty(cell_pos):
			GridManager.place_item(cell_pos, "MacchinarioBase")
			print("Piazzato in: ", cell_pos, " | Totale oggetti in griglia: ", GridManager.grid.size())
