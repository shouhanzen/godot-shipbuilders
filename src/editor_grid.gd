extends TileMapLayer

# Currently selected tile coordinates for placement
var selected_tile_coords: Vector2i = Vector2i(0, 0)
var grid_color = Color(1, 1, 1, 0.1) # Faint white color
var grid_size = 64 # Default grid size

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    # Initialize any required setup
    queue_redraw()

# Override _draw to render grid lines
func _draw() -> void:
    draw_grid()

# Draw the grid lines
func draw_grid() -> void:
    if not tile_set:
        return
        
    var viewport_rect = get_viewport_rect()
    var start_pos = to_local(viewport_rect.position)
    var end_pos = to_local(viewport_rect.end)
    
    var start_cell = local_to_map(start_pos)
    var end_cell = local_to_map(end_pos)
    
    # Get half cell size for offset
    var half_cell = Vector2(tile_set.tile_size) / 2
    
    # Draw vertical lines
    for x in range(start_cell.x - 1, end_cell.x + 2):
        var from_pos = map_to_local(Vector2i(x, start_cell.y - 1)) + half_cell
        var to_pos = map_to_local(Vector2i(x, end_cell.y + 1)) + half_cell
        draw_line(from_pos, to_pos, grid_color)
    
    # Draw horizontal lines
    for y in range(start_cell.y - 1, end_cell.y + 2):
        var from_pos = map_to_local(Vector2i(start_cell.x - 1, y)) + half_cell
        var to_pos = map_to_local(Vector2i(end_cell.x + 1, y)) + half_cell
        draw_line(from_pos, to_pos, grid_color)

# Handle input events for tile placement and removal
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        var mouse_pos = get_global_mouse_position()
        var cell = local_to_map(to_local(mouse_pos))
        
        if event.button_index == MOUSE_BUTTON_LEFT:
            # Place tile
            set_cell(Vector2i(cell.x, cell.y), 0, selected_tile_coords)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            # Remove tile
            erase_cell(Vector2i(cell.x, cell.y))

# Function to change the selected tile
func select_tile(tile_coords: Vector2i) -> void:
    selected_tile_coords = tile_coords

# Save the current grid layout to a file
func save_grid(path: String) -> void:
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        var cells = {}
        for cell in get_used_cells():
            cells[var_to_str(cell)] = get_cell_source_id(cell)
        file.store_string(JSON.stringify(cells))
        file.close()

# Load a grid layout from a file
func load_grid(path: String) -> void:
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        if file != null:
            var cells = JSON.parse_string(file.get_as_text())
            file.close()
            
            # Clear current grid
            clear()
            
            # Place loaded tiles
            for cell_str in cells.keys():
                var cell = str_to_var(cell_str)
                var tile_coords = str_to_var(cells[cell_str])
                set_cell(cell, 0, tile_coords)
