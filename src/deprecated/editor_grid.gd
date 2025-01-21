extends TileMapLayer

@onready var tile_ghost: TileMapLayer = $GhostLayer
@onready var construction_sfx: AudioStreamPlayer = $ConstructionSFX
@onready var grid_lines: Node2D = $GridLinesRenderer

enum PlacementMode {SINGLE_TILE, ROOM}

# Currently selected terrain for placement
var selected_terrain_id: int = 0
var current_mode: PlacementMode = PlacementMode.SINGLE_TILE
var room_start_pos: Vector2i = Vector2i.ZERO

# Store cells during drag operation
var is_dragging: bool = false
var cells_to_place: Array[Vector2i] = []

# Calculate room bounds from two points
func get_room_bounds(start_pos: Vector2i, end_pos: Vector2i) -> Dictionary:
    return {
        "min_x": min(start_pos.x, end_pos.x),
        "max_x": max(start_pos.x, end_pos.x),
        "min_y": min(start_pos.y, end_pos.y),
        "max_y": max(start_pos.y, end_pos.y)
    }

# Generate wall cells for a room
func get_room_wall_cells(bounds: Dictionary) -> Array[Vector2i]:
    var wall_cells: Array[Vector2i] = []
    
    # Add horizontal walls
    for x in range(bounds.min_x, bounds.max_x + 1):
        wall_cells.append(Vector2i(x, bounds.min_y)) # Top wall
        wall_cells.append(Vector2i(x, bounds.max_y)) # Bottom wall
    
    # Add vertical walls
    for y in range(bounds.min_y + 1, bounds.max_y):
        wall_cells.append(Vector2i(bounds.min_x, y)) # Left wall
        wall_cells.append(Vector2i(bounds.max_x, y)) # Right wall
    
    return wall_cells

# Generate floor cells for a room
func get_room_floor_cells(bounds: Dictionary) -> Array[Vector2i]:
    var floor_cells: Array[Vector2i] = []
    
    for x in range(bounds.min_x + 1, bounds.max_x):
        for y in range(bounds.min_y + 1, bounds.max_y):
            floor_cells.append(Vector2i(x, y))
    
    return floor_cells

# Place room tiles (walls and floor)
func place_room(wall_cells: Array[Vector2i], floor_cells: Array[Vector2i], wall_terrain: int) -> void:
    if wall_cells.size() > 0:
        set_cells_terrain_connect(wall_cells, 0, wall_terrain)
    if floor_cells.size() > 0:
        set_cells_terrain_connect(floor_cells, 0, 1) # Floor uses terrain_id 1

# Handle input events for tile placement and removal
func _input(event: InputEvent) -> void:
    # Handle UI hover state
    var hovered_control = get_viewport().gui_get_hovered_control()
    if hovered_control != null:
        var canvas_layer = hovered_control.get_canvas_layer_node()
        if canvas_layer != null and canvas_layer.layer > 0:
            tile_ghost.clear()
            return
        
    if event is InputEventMouseMotion:
        # Update ghost tile position and collect cells during drag
        var mouse_pos = get_global_mouse_position()
        var cell = local_to_map(to_local(mouse_pos))
        
        # Add cell to collection if dragging
        if is_dragging and selected_terrain_id >= 0:
            if not cells_to_place.has(Vector2i(cell.x, cell.y)):
                cells_to_place.append(Vector2i(cell.x, cell.y))
        
        # Update ghost preview
        tile_ghost.clear()
        if selected_terrain_id >= 0:
            if current_mode == PlacementMode.SINGLE_TILE:
                var ghost_cells = cells_to_place.duplicate()
                if not is_dragging:
                    # Just show current cell if not dragging
                    ghost_cells = [Vector2i(cell.x, cell.y)]
                elif not ghost_cells.has(Vector2i(cell.x, cell.y)):
                    # Add current cell to preview if dragging
                    ghost_cells.append(Vector2i(cell.x, cell.y))
                tile_ghost.set_cells_terrain_connect(ghost_cells, 0, selected_terrain_id)
            else: # ROOM mode
                if is_dragging:
                    var bounds = get_room_bounds(room_start_pos, cell)
                    var ghost_wall_cells = get_room_wall_cells(bounds)
                    var ghost_floor_cells = get_room_floor_cells(bounds)
                    
                    # Show ghost preview
                    if ghost_wall_cells.size() > 0:
                        tile_ghost.set_cells_terrain_connect(ghost_wall_cells, 0, selected_terrain_id)
                    if ghost_floor_cells.size() > 0:
                        tile_ghost.set_cells_terrain_connect(ghost_floor_cells, 0, 1)
                else:
                    # Just show current cell if not dragging
                    tile_ghost.set_cells_terrain_connect([Vector2i(cell.x, cell.y)], 0, selected_terrain_id)
    
    elif event is InputEventMouseButton:
        var button = event.button_index
        
        if button == MOUSE_BUTTON_LEFT:
            var mouse_pos = get_global_mouse_position()
            var cell = local_to_map(to_local(mouse_pos))
            
            if current_mode == PlacementMode.SINGLE_TILE:
                if event.pressed and selected_terrain_id >= 0:
                    # Start dragging in single tile mode
                    is_dragging = true
                    cells_to_place.clear()
                    cells_to_place.append(Vector2i(cell.x, cell.y))
                elif not event.pressed and is_dragging:
                    # End dragging and place all collected cells
                    if cells_to_place.size() > 0:
                        set_cells_terrain_connect(cells_to_place, 0, selected_terrain_id)
                        construction_sfx.play()
                    is_dragging = false
                    cells_to_place.clear()
            else: # ROOM mode
                if event.pressed and selected_terrain_id >= 0:
                    # Start room creation
                    is_dragging = true
                    room_start_pos = cell
                    cells_to_place.clear()
                elif not event.pressed and is_dragging:
                    # Create room
                    if cells_to_place.size() > 0:
                        var bounds = get_room_bounds(room_start_pos, cell)
                        var wall_cells = get_room_wall_cells(bounds)
                        var floor_cells = get_room_floor_cells(bounds)
                        
                        place_room(wall_cells, floor_cells, selected_terrain_id)
                        construction_sfx.play()
                    is_dragging = false
                    cells_to_place.clear()
        
        elif button == MOUSE_BUTTON_RIGHT and event.pressed:
            # Remove terrain
            var mouse_pos = get_global_mouse_position()
            var cell = local_to_map(to_local(mouse_pos))
            var cell_vec = Vector2i(cell.x, cell.y)
            # Get terrain type before erasing
            var terrain_id = get_cell_tile_data(cell_vec).terrain if get_cell_tile_data(cell_vec) else -1
            erase_cell(cell_vec)
            # Update surrounding cells if there was terrain
            if terrain_id >= 0:
                # Get neighboring cells
                var neighbors = [
                    Vector2i(cell.x - 1, cell.y),
                    Vector2i(cell.x + 1, cell.y),
                    Vector2i(cell.x, cell.y - 1),
                    Vector2i(cell.x, cell.y + 1)
                ]
                # Update terrain connections for neighbors
                for neighbor in neighbors:
                    if get_cell_tile_data(neighbor):
                        set_cells_terrain_connect([neighbor], 0, terrain_id)

# Function to change the selected terrain
func select_terrain(terrain_id: int) -> void:
    selected_terrain_id = terrain_id
    grid_lines.set_opacity(1.0 if terrain_id >= 0 else 0.0)
    
# Function to toggle placement mode
func toggle_placement_mode() -> void:
    if current_mode == PlacementMode.SINGLE_TILE:
        current_mode = PlacementMode.ROOM
    else:
        current_mode = PlacementMode.SINGLE_TILE

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
