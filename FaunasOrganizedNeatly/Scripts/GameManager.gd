class_name GameManager
extends Node


@export var grid: Grid

@export var held_piece_flat_speed: float
@export var held_piece_distance_speed: float
@export var held_piece_settle_delay: float # The amount of time the held piece must remain motionless before settling
@export var held_piece_settle_animation_duration: float # The amount of time the held piece takes to move to it's settled position

var held_piece: Piece

# Cells of the grid that are currently occupied by a blocker or piece
# Key is all that matters, value is just a dummy since gdscript doesn't have HashSet
var occupied_grid_cells: Dictionary

var held_piece_settled: bool
var previous_mouse_position: Vector2
var remaining_settle_delay: float


func _ready():
	occupied_grid_cells = {}

func _process(delta):
	if held_piece == null:
		return
		
	_do_held_piece_settle(delta)
	_held_piece_towards_cursor(delta)
	_rotate_held_piece()
	
	_do_place_held_piece()

func on_piece_clicked(clicked_piece: Piece):
	if held_piece != null:
		return
	
	held_piece = clicked_piece
	_remove_occupied_cells(held_piece)
	
	_reset_settled()

func _held_piece_towards_cursor(delta):
	if held_piece_settled:
		return
	
	var target_position: Vector2 = get_viewport().get_mouse_position()
	target_position -= held_piece.pivot_offset
	var held_piece_to_mouse: Vector2 = target_position - held_piece.position
	var held_piece_to_mouse_distance: float = held_piece_to_mouse.length()
	
	var distance_step: float = (held_piece_flat_speed + held_piece_distance_speed * held_piece_to_mouse_distance) * delta
	
	if distance_step > held_piece_to_mouse_distance:
		held_piece.position = target_position
		return
	
	held_piece.position += held_piece_to_mouse.normalized() * distance_step

func _rotate_held_piece():
	if Input.is_action_just_pressed("RotateClockwise"):
		held_piece.rotate_clockwise()
		_reset_settled()
	elif Input.is_action_just_pressed("RotateAnticlockwise"):
		held_piece.rotate_anticlockwise()
		_reset_settled()

func _get_held_piece_grid_origin() -> Vector2i:
	var mouse_position = get_viewport().get_mouse_position()
	var piece_origin_cell_center: Vector2 = mouse_position - held_piece.current_offset
	piece_origin_cell_center -= grid.global_position
	piece_origin_cell_center += Vector2(grid.texture_size * 0.5, grid.texture_size * 0.5)
	var x = floor(piece_origin_cell_center.x / grid.texture_size)
	var y = floor(piece_origin_cell_center.y / grid.texture_size)
	return Vector2i(x, y)

func _do_held_piece_settle(delta):
	var mouse_position = get_viewport().get_mouse_position()
	var mouse_distance_moved = (mouse_position - previous_mouse_position).length()
	if mouse_distance_moved > 0.1:
		_reset_settled()
		held_piece.cancel_movement_tween()
		previous_mouse_position = mouse_position
	else:
		if held_piece_settled:
			return
		remaining_settle_delay -= delta
		if remaining_settle_delay <= 0:
			held_piece_settled = true
			var held_piece_grid_origin = _get_held_piece_grid_origin()
			if !_held_piece_fits_grid(held_piece_grid_origin):
				return
			var settle_position = _held_piece_placed_position(held_piece_grid_origin)
			held_piece.movement_tween_to(settle_position, held_piece_settle_animation_duration)

func _reset_settled():
	held_piece_settled = false
	remaining_settle_delay = held_piece_settle_delay

func _held_piece_placed_position(held_piece_grid_origin: Vector2i) -> Vector2:
	var placed_position = grid.grid_to_world_position(held_piece_grid_origin)
	placed_position += (held_piece.current_offset - held_piece.pivot_offset)
	return placed_position

func _held_piece_fits_grid(held_piece_grid_origin: Vector2i) -> bool:
	if held_piece_grid_origin.x < 0 or held_piece_grid_origin.y < 0:
		return false # One of the held piece's cells is outside the grid
	
	for i in range(held_piece._current_cells.size()):
		var cell = held_piece_grid_origin + held_piece._current_cells[i]
		if cell.x >= grid.width or cell.y >= grid.height:
			return false # One of the held piece's cells is outside the grid
		if occupied_grid_cells.has(cell):
			return false # One of the held piece's cells overlaps an occupied grid cell
	
	return true

func _remove_occupied_cells(piece: Piece):
	if piece.current_placement_state != Piece.PlacementStates.PLACED:
		return
	
	for i in range(piece._current_cells.size()):
		var cell_grid_position = piece.placed_grid_position + piece._current_cells[i]
		occupied_grid_cells.erase(cell_grid_position)
		print("Removed cell " + str(cell_grid_position))

func _do_place_held_piece():
	# Try to place the held piece
	if !Input.is_action_just_released("PlacePiece"):
		return # Place piece input was not given
	if held_piece == null:
		return # There is no held piece to place
	
	# Find the position the held piece would occupy on the grid and check if it fits
	var held_piece_grid_origin = _get_held_piece_grid_origin()
	if !_held_piece_fits_grid(held_piece_grid_origin):
		held_piece.return_piece()
		held_piece = null
		return # Piece does not fit
	
	# Place the piece
	# Add the newly occupied cells to the dictionary
	for i in range(held_piece._current_cells.size()):
		var cell_grid_position = held_piece_grid_origin + held_piece._current_cells[i]
		occupied_grid_cells[cell_grid_position] = true
		print("Placed cell " + str(cell_grid_position))
	
	# Find the grid aligned position on screen to move the placed piece to
	var placed_position = _held_piece_placed_position(held_piece_grid_origin)
	held_piece.place_piece(held_piece_grid_origin, placed_position)
	
	held_piece = null # Piece is no longer being held
