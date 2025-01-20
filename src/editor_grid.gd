extends TileMapLayer

@onready var tile_ghost: TileMapLayer = $GhostLayer

# Currently selected terrain for placement
var selected_terrain_id: int = 0
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
    if event is InputEventMouseMotion:
        # Update ghost tile position
        var mouse_pos = get_global_mouse_position()
        var cell = local_to_map(to_local(mouse_pos))
        tile_ghost.clear()
        if selected_terrain_id >= 0:
            var cells = [Vector2i(cell.x, cell.y)]
            tile_ghost.set_cells_terrain_connect(cells, 0, selected_terrain_id)
    
    elif event is InputEventMouseButton and event.pressed:
        var mouse_pos = get_global_mouse_position()
        var cell = local_to_map(to_local(mouse_pos))
        
        if event.button_index == MOUSE_BUTTON_LEFT and selected_terrain_id >= 0:
            # Place terrain
            var cells = [Vector2i(cell.x, cell.y)]
            set_cells_terrain_connect(cells, 0, selected_terrain_id)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            # Remove terrain
            erase_cell(Vector2i(cell.x, cell.y))

# Function to change the selected terrain
func select_terrain(terrain_id: int) -> void:
    selected_terrain_id = terrain_id
    # Update ghost tile appearance
    var mouse_pos = get_global_mouse_position()
    var cell = local_to_map(to_local(mouse_pos))
    tile_ghost.clear()
    if selected_terrain_id >= 0:
        var cells = [Vector2i(cell.x, cell.y)]
        tile_ghost.set_cells_terrain_connect(cells, 0, selected_terrain_id)

# Save the current grid layout to a file
func save_grid(path: String) -> void:
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        var cells = {}
        for cell in get_used_cells():
            var tile_data = get_cell_tile_data(cell)
            if tile_data:
                cells[var_to_str(cell)] = tile_data.terrain
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
            
            # Place loaded terrains
            for cell_str in cells.keys():
                var cell = str_to_var(cell_str)
                var terrain_id = str_to_var(cells[cell_str])
                if terrain_id >= 0:
                    var cells_to_set = [cell]
                    set_cells_terrain_connect(cells_to_set, 0, terrain_id)
