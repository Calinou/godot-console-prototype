extends CanvasLayer

var commands := {}
var variables := {}

@export var version_label: Label

func _ready() -> void:
	version_label.text = "%s %s\nGodot %s\n%s - %s - %s" % [
		ProjectSettings.get_setting_with_override("application/config/name"),
		ProjectSettings.get_setting_with_override("application/config/version"),
		"%s.%s.%s.%s.%s" % [Engine.get_version_info()["major"], Engine.get_version_info()["minor"], Engine.get_version_info()["patch"], Engine.get_version_info()["status"], Engine.get_version_info()["hash"].substr(0, 9)],
		OS.get_name(),
		ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method"),
		RenderingServer.get_video_adapter_name(),
	]
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

	add_command("help", [], "Displays usage instructions.",
		func() -> void:
			append_line("Enter [color=cyan]cmdlist[/color] to list commands, or [color=cyan]cvarlist[/color] to list variables.")
			append_line("")
			append_line("Example command syntax: [color=cyan]command_name first_argument second_argument ...[/color]")
			append_line("Example variable syntax: [color=yellow]variable_name value[/color]")
			append_line("Enter [color=yellow]variable_name[/color] alone to see the variable's value.")
	)

	add_command("quit", ["exit_code"], "Exits the project without confirmation.",
		func(exit_code: int = 0) -> void:
			get_tree().quit(exit_code)
	)

	add_command("echo", ["text"], "Prints the specified text to console with a blank line at the end.",
		func(text: String = "") -> void:
			append_line(text)
	)

	add_command("cmdlist", ["glob"], "Lists all console commands. If a glob is specified (example: \"*list*\"), filters the results accordingly.",
		func(glob: String = "") -> void:
			var matches := 0
			for command in commands:
				if glob.is_empty() or command.match(glob):
					matches += 1
					var arguments_string := ""
					for argument in commands[command].arguments:
						arguments_string += " <" + argument + ">"
					append_line("[color=cyan]%s[/color][color=gray]%s[/color]: %s" % [command, arguments_string, commands[command].description])
			if glob.is_empty():
				append_line("%d commands." % matches)
			else:
				append_line("%d commands matching the glob \"%s\"." % [matches, glob])
	)

	add_command("cvarlist", ["glob"], "Lists all console variables. If a glob is specified (example: \"*list*\"), filters the results accordingly.",
		func(glob: String = "") -> void:
			var matches := 0
			for variable in variables:
				if glob.is_empty() or variable.match(glob):
					matches += 1
					append_line("[color=yellow]%s[/color][color=gray] = %s[/color]: %s" % [variable, variables[variable].value, variables[variable].description])
			if glob.is_empty():
				append_line("%d variables." % matches)
			else:
				append_line("%d variables matching the glob \"%s\"." % [matches, glob])
	)


func _on_visibility_changed() -> void:
	if visible:
		$VSplitContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_console"):
		visible = not visible
		# Prevent writing the toggle console character in the LineEdit, as we focus it automatically.
		get_viewport().set_input_as_handled()


func append_line(text: String = "") -> void:
	print_rich(text)
	$VSplitContainer/PanelContainer/MarginContainer/VBoxContainer/RichTextLabel.append_text(text + "\n")


func add_command(p_name: String, p_arguments: Array[String], p_description: String, p_command: Callable) -> void:
	if variables.get(p_name) != null:
		push_error("Can't register console command \"%s\" as there is already a console variable with the same name." % p_name)
		return

	# TODO: Support marking optional arguments as such, so they can be distinguished in the help.
	commands[p_name] = {
		arguments = p_arguments,
		description = p_description,
		command = p_command,
	}


func add_variable(p_name: String, p_type: String, p_value_hint: String, p_default: Variant, p_min: float, p_max: float, p_description: String, p_setter: Callable):
	if commands.get(p_name) != null:
		push_error("Can't register console variable \"%s\" as there is already a console command with the same name." % p_name)
		return

	variables[p_name] = {
		type = p_type,
		value = p_default,
		value_hint = p_value_hint,
		default = p_default,
		min = p_min,
		max = p_max,
		description = p_description,
		setter = p_setter,
	}


func remove_command(p_name: String) -> void:
	commands[p_name] = null


func remove_variable(p_name: String) -> void:
	variables[p_name] = null


func _on_line_edit_text_submitted(new_text: String) -> void:
	$VSplitContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit.clear()

	if not new_text.strip_edges().is_empty():
		var new_text_stripped := new_text.strip_edges()
		append_line("[i][color=gray]> " + new_text_stripped + "[/color][/i]")

		var text_split := new_text_stripped.split(" ")
		if commands.get(text_split[0]) != null:
			# TODO: Handle strings with quotes. Remove quotes from the string arguments themselves,
			# whether they're double quotes or single quotes.
			var arguments: Array = text_split.slice(1)
			commands[text_split[0]].command.callv(arguments)
		elif variables.get(text_split[0]) != null:
			var variable: Dictionary = variables[text_split[0]]
			var value := float(text_split[-1])
			if value < variable.min:
				append_line("Value is too low; clamped.")
			if value > variable.max:
				append_line("Value is too high; clamped.")
			var return_value: Variant = variables[text_split[0]].setter.call(clamp(value, variable.min, variable.max))
			variables[text_split[0]].value = return_value
		else:
			append_line("[color=red]Unknown command or variable: %s[/color]" % text_split[0])

		# Add a blank line to make future lines easier to distinguish from the command run.
		append_line("")
