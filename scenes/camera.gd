extends Node2D

@export var speed: float = 500.0  # Movement speed in pixels per second
@export var smoothing: float = 5.0  # Higher values mean smoother movement
@export var min_zoom: float = 0.1
@export var max_zoom: float = 2.0
@export var zoom_speed: float = 0.1

var target_position: Vector2 = Vector2.ZERO
var target_zoom: float = 1.0

func _ready() -> void:
    target_position = position
    if has_node("Camera2D"):
        target_zoom = $Camera2D.zoom.x

func _process(delta: float) -> void:
    var movement = Vector2.ZERO
    
    # Check for WASD input
    if Input.is_key_pressed(KEY_W):
        movement.y -= 1
    if Input.is_key_pressed(KEY_S):
        movement.y += 1
    if Input.is_key_pressed(KEY_A):
        movement.x -= 1
    if Input.is_key_pressed(KEY_D):
        movement.x += 1
    
    # Normalize the movement vector to prevent faster diagonal movement
    if movement.length() > 0:
        movement = movement.normalized()
    
    # Scale movement speed with zoom level (so you move faster when zoomed out)
    var zoom_factor = 1.0
    if has_node("Camera2D"):
        zoom_factor = 1.0 / $Camera2D.zoom.x
    
    # Update target position with zoom-scaled speed
    target_position += movement * speed * delta * zoom_factor
    
    # Smoothly move towards target position
    position = position.lerp(target_position, smoothing * delta)
    
    # Smoothly update zoom
    if has_node("Camera2D"):
        var current_zoom = $Camera2D.zoom.x
        var new_zoom = lerp(current_zoom, target_zoom, smoothing * delta)
        $Camera2D.zoom = Vector2(new_zoom, new_zoom)

func _unhandled_input(event: InputEvent) -> void:
    if not has_node("Camera2D"):
        return
    
    if event is InputEventMouseButton:
        # Mouse wheel up/down
        if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            # 1) Get mouse position in world space BEFORE zoom changes
            #    We'll use the camera's global mouse position. This is valid
            #    only if the Camera2D is current, otherwise you'd need to adjust
            #    to whichever camera is active.
            var old_mouse_world_pos = $Camera2D.get_global_mouse_position()
            
            # 2) Adjust target zoom
            var zoom_change = zoom_speed if event.button_index == MOUSE_BUTTON_WHEEL_UP else -zoom_speed
            target_zoom = clamp(target_zoom + zoom_change, min_zoom, max_zoom)
