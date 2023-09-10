extends CanvasLayer

var commands := {}
var variables := {}

func _ready() -> void:
	$VSplitContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit.grab_focus()


func append_line(text) -> void:
	$VSplitContainer/PanelContainer/MarginContainer/VBoxContainer/RichTextLabel.append_text(text + "\n")

func register_command(p_name: String, p_args: Array[String], p_description: String, p_command: Callable):
	commands[p_name] = {
		args = p_args,
		description = p_description,
		command = p_command,
	}


func register_variable(p_name: String, p_type: String, p_value_hint: String, p_default: Variant, p_min: float, p_max: float, p_description: String, p_setter: Callable):
	variables[p_name] = {
		type = p_type,
		value_hint = p_value_hint,
		default = p_default,
		min = p_min,
		max = p_max,
		description = p_description,
		setter = p_setter,
	}


func _on_line_edit_text_submitted(new_text: String) -> void:
	if not new_text.is_empty():
		var text_split := new_text.split(" ")
		if commands.get(text_split[0]) != null:
			commands[text_split[0]].command.call(1234) # TODO: Read arguments from command line
		elif variables.get(text_split[0]) != null:
			var variable: Dictionary = variables[text_split[0]]
			var value := float(text_split[-1])
			if value < variable.min:
				append_line("Value is too low; clamped.")
			if value > variable.max:
				append_line("Value is too high; clamped.")
			variables[text_split[0]].setter.call(clamp(value, variable.min, variable.max))

		append_line(new_text)
		$VSplitContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit.clear()
