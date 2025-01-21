@tool
extends MarginContainer

const PlacementMode = preload("res://src/grid.gd").PlacementMode
const LayerType = preload("res://src/grid.gd").LayerType

@export var terrain_id: int = -1
@export var placement_mode: PlacementMode = PlacementMode.SINGLE_TILE
@export var layer_type: LayerType = LayerType.WALLS

const HOVER_BRIGHTNESS = 1.2
const NORMAL_BRIGHTNESS = 1.0

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_inside_tree():
			$TextureButton.texture_normal = icon
	get:
		return icon

func _ready() -> void:
	if not icon and $TextureButton.texture_normal:
		icon = $TextureButton.texture_normal
	elif icon:
		$TextureButton.texture_normal = icon
		
	var button = $TextureButton
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)
	button.modulate = Color(NORMAL_BRIGHTNESS, NORMAL_BRIGHTNESS, NORMAL_BRIGHTNESS)
	button.pressed.connect(_on_button_pressed)

func _on_mouse_entered() -> void:
	$TextureButton.modulate = Color(HOVER_BRIGHTNESS, HOVER_BRIGHTNESS, HOVER_BRIGHTNESS)

func _on_mouse_exited() -> void:
	$TextureButton.modulate = Color(NORMAL_BRIGHTNESS, NORMAL_BRIGHTNESS, NORMAL_BRIGHTNESS)

func _on_button_pressed() -> void:
	var grid = get_tree().get_first_node_in_group("editor_grid")
	if grid:
		grid.select_terrain(terrain_id)
		grid.select_layer(layer_type)
		if placement_mode >= 0:
			grid.current_mode = placement_mode
