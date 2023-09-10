extends Node2D


func _ready() -> void:
	Console.register_command("do_stuff", ["required_arg", "optional_arg"], "Do some stuff.",
			func(required_arg, optional_arg = 2):
				print("I do stuff with %d and %d." % [required_arg, optional_arg])
	)

	Console.register_variable("sprite_y", "float", "height", 120, 0, 500, "The sprite's height in the game world.",
			func(value: float):
				$CanvasLayer/Sprite2D.position.y = value
	)
