extends Node2D

# Path for saving/loading grid data
const SAVE_PATH: String = "user://saved_grid.json"

# Auto-save timer
var save_timer: Timer

@onready var tile_ghost: TileMapLayer = $GhostLayer
@onready var construction_sfx: AudioStreamPlayer = $ConstructionSFX
@onready var grid_lines: Node2D = $GridLinesRenderer

# Layer references
@onready var walls_layer: TileMapLayer = $WallsLayer
@onready var floors_layer: TileMapLayer = $FloorsLayer
@onready var props_layer: TileMapLayer = $PropsLayer
@onready var camera: Node2D = get_tree().get_first_node_in_group("camera")

enum PlacementMode {SINGLE_TILE, ROOM}
enum LayerType {WALLS, FLOORS, PROPS}

# Currently selected options for placement
var selected_terrain_id: int = 0
var selected_layer: LayerType = LayerType.WALLS
var current_mode: PlacementMode = PlacementMode.SINGLE_TILE
var room_start_pos: Vector2i = Vector2i.ZERO

# Store cells during drag operation
var is_dragging: bool = false
var cells_to_place: Array[Vector2i] = []
var is_destroy_dragging: bool = false
var cells_to_destroy: Array[Vector2i] = []

func _ready() -> void:
	if camera:
		camera.transform_changed.connect(_on_camera_moved)
		# Initial update in case camera starts moving before mouse moves
		_on_camera_moved()
	
	# Set up auto-save timer
	save_timer = Timer.new()
	save_timer.wait_time = 60.0  # Save every minute
	save_timer.one_shot = false
	save_timer.timeout.connect(_on_save_timer_timeout)
	add_child(save_timer)
	save_timer.start()
	
	# Load saved grid when game starts
	var deltas = load_grid(SAVE_PATH)
	print("Loaded grid with deltas: ", deltas)

# Called every minute for auto-save
func _on_save_timer_timeout() -> void:
	save_grid(SAVE_PATH)

# Save grid before the game exits
func _exit_tree() -> void:
	save_grid(SAVE_PATH)

# Get the active layer based on selected type
func get_active_layer() -> TileMapLayer:
	match selected_layer:
		LayerType.WALLS:
			return walls_layer
		LayerType.FLOORS:
			return floors_layer
		LayerType.PROPS:
			return props_layer
		_:
			return walls_layer

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
		walls_layer.set_cells_terrain_connect(wall_cells, 0, wall_terrain)
	if floor_cells.size() > 0:
		floors_layer.set_cells_terrain_connect(floor_cells, 0, 1) # Floor uses terrain_id 1

# Handle input events for tile placement and removal
func _input(event: InputEvent) -> void:
	# Handle UI hover state
	var hovered_control = get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		var canvas_layer = hovered_control.get_canvas_layer_node()
		if canvas_layer != null and canvas_layer.layer > 0:
			tile_ghost.clear()
			return
	
	var active_layer = get_active_layer()
		
	if event is InputEventMouseMotion:
		# Update ghost tile position and collect cells during drag
		var mouse_pos = get_global_mouse_position()
		var cell = active_layer.local_to_map(active_layer.to_local(mouse_pos))
		
		# Add cell to collection if dragging
		if is_dragging and selected_terrain_id >= 0:
			if not cells_to_place.has(Vector2i(cell.x, cell.y)):
				cells_to_place.append(Vector2i(cell.x, cell.y))
		
		# Update ghost preview
		update_ghost_preview(mouse_pos)
	
	elif event is InputEventMouseButton:
		var button = event.button_index
		
		if button == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_global_mouse_position()
			var cell = active_layer.local_to_map(active_layer.to_local(mouse_pos))
			
			if current_mode == PlacementMode.SINGLE_TILE:
				if event.pressed and selected_terrain_id >= 0:
					# Start dragging in single tile mode
					is_dragging = true
					cells_to_place.clear()
					cells_to_place.append(Vector2i(cell.x, cell.y))
				elif not event.pressed and is_dragging:
					# End dragging and place all collected cells
					if cells_to_place.size() > 0:
						active_layer.set_cells_terrain_connect(cells_to_place, 0, selected_terrain_id)
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
		
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Start right-drag destruction
				is_destroy_dragging = true
				cells_to_destroy.clear()
				var mouse_pos = get_global_mouse_position()
				var cell = active_layer.local_to_map(active_layer.to_local(mouse_pos))
				cells_to_destroy.append(Vector2i(cell.x, cell.y))
			else:
				if is_destroy_dragging:
					# Remove tiles and update their connections by setting terrain to -1
					for cell in cells_to_destroy:
						if active_layer.get_cell_tile_data(cell):
							# Remove the tile and update its connections
							active_layer.set_cells_terrain_connect([cell], 0, -1, false)
							
							# Update surrounding cells to recalc their autotile variations
							var neighbors = active_layer.get_surrounding_cells(cell)
							for neighbor in neighbors:
								if active_layer.get_cell_tile_data(neighbor):
									var neighbor_terrain = active_layer.get_cell_tile_data(neighbor).terrain
									if neighbor_terrain >= 0:
										active_layer.set_cells_terrain_connect([neighbor], 0, neighbor_terrain, false)
					
					construction_sfx.play()
					is_destroy_dragging = false
					cells_to_destroy.clear()

func _on_camera_moved() -> void:
	var mouse_pos = get_global_mouse_position()
	update_ghost_preview(mouse_pos)

func update_ghost_preview(mouse_pos: Vector2) -> void:
	var active_layer = get_active_layer()
	var cell = active_layer.local_to_map(active_layer.to_local(mouse_pos))
	
	tile_ghost.clear()
	if selected_terrain_id >= 0:
		if current_mode == PlacementMode.SINGLE_TILE:
			var ghost_cells = cells_to_place.duplicate()
			if not is_dragging:
				ghost_cells = [Vector2i(cell.x, cell.y)]
			elif not ghost_cells.has(Vector2i(cell.x, cell.y)):
				ghost_cells.append(Vector2i(cell.x, cell.y))
			tile_ghost.set_cells_terrain_connect(ghost_cells, 0, selected_terrain_id)
		else: # ROOM mode
			if is_dragging:
				var bounds = get_room_bounds(room_start_pos, cell)
				var ghost_wall_cells = get_room_wall_cells(bounds)
				var ghost_floor_cells = get_room_floor_cells(bounds)
				
				if ghost_wall_cells.size() > 0:
					tile_ghost.set_cells_terrain_connect(ghost_wall_cells, 0, selected_terrain_id)
				if ghost_floor_cells.size() > 0:
					tile_ghost.set_cells_terrain_connect(ghost_floor_cells, 0, 1)
			else:
				tile_ghost.set_cells_terrain_connect([Vector2i(cell.x, cell.y)], 0, selected_terrain_id)

# Function to change the selected terrain
func select_terrain(terrain_id: int) -> void:
	selected_terrain_id = terrain_id
	grid_lines.set_opacity(1.0 if terrain_id >= 0 else 0.0)

# Function to change the selected layer
func select_layer(layer_type: LayerType) -> void:
	selected_layer = layer_type
	
# Function to toggle placement mode
func toggle_placement_mode() -> void:
	if current_mode == PlacementMode.SINGLE_TILE:
		current_mode = PlacementMode.ROOM
	else:
		current_mode = PlacementMode.SINGLE_TILE

	# Update ghost tile appearance
	var mouse_pos = get_global_mouse_position()
	var cell = get_active_layer().local_to_map(get_active_layer().to_local(mouse_pos))
	tile_ghost.clear()
	if selected_terrain_id >= 0:
		var cells = [Vector2i(cell.x, cell.y)]
		tile_ghost.set_cells_terrain_connect(cells, 0, selected_terrain_id)

# Save the current grid layout to a file
func save_grid(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		var grid_data = {
			"walls": {},
			"floors": {},
			"props": {}
		}
		
		# Save walls
		for cell in walls_layer.get_used_cells():
			var tile_data = walls_layer.get_cell_tile_data(cell)
			if tile_data:
				grid_data.walls[var_to_str(cell)] = tile_data.terrain
				
		# Save floors
		for cell in floors_layer.get_used_cells():
			var tile_data = floors_layer.get_cell_tile_data(cell)
			if tile_data:
				grid_data.floors[var_to_str(cell)] = tile_data.terrain
				
		# Save props
		for cell in props_layer.get_used_cells():
			var tile_data = props_layer.get_cell_tile_data(cell)
			if tile_data:
				grid_data.props[var_to_str(cell)] = tile_data.terrain
				
		file.store_string(JSON.stringify(grid_data))
		file.close()

# Load a grid layout from a file and return deltas
func load_grid(path: String) -> Dictionary:
	var deltas = {
		"walls": [],
		"floors": [],
		"props": []
	}
	
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file != null:
			var grid_data = JSON.parse_string(file.get_as_text())
			file.close()
			
			# Clear all layers
			walls_layer.clear()
			floors_layer.clear()
			props_layer.clear()
			
			# Load walls
			for cell_str in grid_data.walls.keys():
				var cell = str_to_var(cell_str)
				var terrain_id = int(grid_data.walls[cell_str])
				if terrain_id >= 0:
					walls_layer.set_cells_terrain_connect([cell], 0, terrain_id)
					deltas.walls.append({"cell": cell, "terrain": terrain_id})
					
			# Load floors
			for cell_str in grid_data.floors.keys():
				var cell = str_to_var(cell_str)
				var terrain_id = int(grid_data.floors[cell_str])
				if terrain_id >= 0:
					floors_layer.set_cells_terrain_connect([cell], 0, terrain_id)
					deltas.floors.append({"cell": cell, "terrain": terrain_id})
					
			# Load props
			for cell_str in grid_data.props.keys():
				var cell = str_to_var(cell_str)
				var terrain_id = int(grid_data.props[cell_str])
				if terrain_id >= 0:
					props_layer.set_cells_terrain_connect([cell], 0, terrain_id)
					deltas.props.append({"cell": cell, "terrain": terrain_id})
	
	return deltas
