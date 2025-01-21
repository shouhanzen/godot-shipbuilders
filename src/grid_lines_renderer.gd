extends Node2D

@export var tilemap: TileMapLayer

const GRID_SCALES = [
	{"scale": 1, "thickness": 1.0, "min_zoom": 0.8, "max_zoom": 4.0},
	{"scale": 5, "thickness": 2.0, "min_zoom": 0.2, "max_zoom": 2.0},
	{"scale": 25, "thickness": 10.0, "min_zoom": 0, "max_zoom": 0.5}
]

var base_grid_color = Color(1, 1, 1, 0.1) # Faint white color
var target_opacity = 1.0
var current_opacity = 1.0
const OPACITY_LERP_SPEED = 10.0

func set_opacity(value: float) -> void:
	target_opacity = value
	queue_redraw()

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	current_opacity = lerp(current_opacity, target_opacity, delta * OPACITY_LERP_SPEED)
	
	queue_redraw()

func _draw() -> void:
	if not tilemap or not tilemap.tile_set or current_opacity <= 0:
		return
		
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
		
	var viewport_rect = get_viewport_rect()
	var camera_pos = camera.global_position
	var camera_zoom = camera.zoom
	
	# Calculate visible area in world space
	var top_left = camera_pos - (viewport_rect.size / 2) / camera_zoom
	var bottom_right = camera_pos + (viewport_rect.size / 2) / camera_zoom
	
	var start_pos = tilemap.to_local(top_left)
	var end_pos = tilemap.to_local(bottom_right)
	
	var start_cell = tilemap.local_to_map(start_pos)
	var end_cell = tilemap.local_to_map(end_pos)
	
	# Add dynamic buffer based on zoom level to ensure coverage during movement and zooming
	var buffer_size = int(max(10.0 / camera_zoom.x, 5))
	start_cell -= Vector2i(buffer_size, buffer_size)
	end_cell += Vector2i(buffer_size, buffer_size)
	
	# Get half cell size for offset
	var half_cell = Vector2(tilemap.tile_set.tile_size) / 2
	
	# Draw grid for each scale
	for scale_info in GRID_SCALES:
		var scale = scale_info["scale"]
		var thickness = scale_info["thickness"]
		
		# Calculate opacity based on camera zoom
		var zoom_factor = camera_zoom.x  # Assuming uniform zoom
		var falloff_range = 0.2  # 20% falloff range
		
		# Calculate smoothstep bounds with falloff outside min/max zoom
		var min_with_falloff = scale_info["min_zoom"] - falloff_range * scale_info["min_zoom"]
		var max_with_falloff = scale_info["max_zoom"] + falloff_range * scale_info["max_zoom"]
		
		# Full opacity within bounds, smooth falloff outside
		var opacity_factor = 1.0
		if zoom_factor < scale_info["min_zoom"]:
			opacity_factor = smoothstep(min_with_falloff, scale_info["min_zoom"], zoom_factor)
		elif zoom_factor > scale_info["max_zoom"]:
			opacity_factor = 1.0 - smoothstep(scale_info["max_zoom"], max_with_falloff, zoom_factor)
			
		var grid_color = base_grid_color
		grid_color.a *= opacity_factor * current_opacity
		
		if opacity_factor <= 0:
			continue
			
		# Adjust cell range for current scale
		var scaled_start = start_cell / scale
		var scaled_end = end_cell / scale
		
		# Draw vertical lines
		for x in range(scaled_start.x, scaled_end.x + 1):
			var real_x = x * scale
			var from_pos = tilemap.map_to_local(Vector2i(real_x, start_cell.y)) + half_cell
			var to_pos = tilemap.map_to_local(Vector2i(real_x, end_cell.y)) + half_cell
			draw_line(from_pos, to_pos, grid_color, thickness)
		
		# Draw horizontal lines
		for y in range(scaled_start.y, scaled_end.y + 1):
			var real_y = y * scale
			var from_pos = tilemap.map_to_local(Vector2i(start_cell.x, real_y)) + half_cell
			var to_pos = tilemap.map_to_local(Vector2i(end_cell.x, real_y)) + half_cell
			draw_line(from_pos, to_pos, grid_color, thickness)
