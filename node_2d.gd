extends Node2D


func _ready() -> void:
	Console.add_command("do_stuff", ["required_arg", "optional_arg"], "Do some stuff.",
			func(required_arg: String, optional_arg: String = "2.0") -> void:
				Console.append_line("I do stuff with %d and %d." % [float(required_arg), float(optional_arg)])
	)

	Console.add_variable("sprite_y", "float", "height", 120, 0, 500, "The sprite's height in the game world.",
			func(value: float) -> Variant:
				$CanvasLayer/Sprite2D.position.y = value
				return value
	)
