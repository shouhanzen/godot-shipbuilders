extends Control

@onready var arrow1 = preload("res://sprites/Dark/Arrows/Arrow1.png")
@onready var arrow2 = preload("res://sprites/Dark/Arrows/Arrow2.png")
@onready var arrow3 = preload("res://sprites/Dark/Arrows/Arrow3.png")
@onready var arrow4 = preload("res://sprites/Dark/Arrows/Arrow4.png")
@onready var click_sfx: AudioStreamPlayer = $ClickSFX

func _ready() -> void:
	# Hide the default system cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Set initial texture
	$MouseSprite.texture = arrow1

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			click_sfx.play()
			
func _process(_delta: float) -> void:
	# Update position to follow mouse
	position = get_global_mouse_position()
	
	# Update cursor texture based on held state
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		$MouseSprite.texture = arrow2
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		$MouseSprite.texture = arrow3
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		$MouseSprite.texture = arrow4
	else:
		$MouseSprite.texture = arrow1
