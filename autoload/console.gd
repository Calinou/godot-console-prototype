extends CanvasLayer

const VARIABLES_STORAGE_PATH = "user://variables.ini"

enum DisplayMode {
	DISPLAY_MODE_HIDDEN,
	DISPLAY_MODE_DETAILED,
	DISPLAY_MODE_COMPACT,
	DISPLAY_MODE_MAX,
}

@export var split_container: VSplitContainer
@export var log: RichTextLabel
@export var input_line: LineEdit
@export var version_label: Label

var display_mode := DisplayMode.DISPLAY_MODE_HIDDEN
var old_mouse_mode := Input.MOUSE_MODE_VISIBLE
var commands := {}
var variables := {}
var variables_storage := ConfigFile.new()

func _ready() -> void:
	variables_storage.load(VARIABLES_STORAGE_PATH)

	version_label.text = "%s %s\nGodot %s\n%s - %s - %s" % [
		ProjectSettings.get_setting_with_override("application/config/name"),
		ProjectSettings.get_setting_with_override("application/config/version"),
		"%s.%s.%s.%s.%s" % [Engine.get_version_info()["major"], Engine.get_version_info()["minor"], Engine.get_version_info()["patch"], Engine.get_version_info()["status"], Engine.get_version_info()["hash"].substr(0, 9)],
		OS.get_name(),
		ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method"),
		RenderingServer.get_video_adapter_name(),
	]

	add_builtin_command("help", [], "Displays usage instructions.",
		func() -> void:
			append_line("Enter [color=green]cmdlist[/color] to list commands, or [color=green]cvarlist[/color] to list variables.")
			append_line("")
			append_line("Example command syntax: [color=green]command_name first_argument second_argument ...[/color]")
			append_line("Example variable syntax: [color=yellow]variable_name value[/color]")
			append_line("Enter [color=yellow]variable_name[/color] alone to see the variable's value.")
	)

	add_builtin_command("quit", ["exit_code"], "Exits the project without confirmation.",
		func(exit_code: String = "0") -> void:
			get_tree().quit(int(exit_code))
	)

	add_builtin_command("echo", ["text"], "Prints the specified text to console with a blank line at the end.",
		func(text: String = "") -> void:
			append_line(text)
	)

	add_builtin_command("cmdlist", ["glob"], "Lists all console commands. If a glob is specified (example: \"*list*\"), filters the results accordingly.",
		func(glob: String = "") -> void:
			var matches := 0
			for command in commands:
				if glob.is_empty() or command.match(glob):
					matches += 1
					var arguments_string := ""
					for argument in commands[command].arguments:
						arguments_string += " <" + argument + ">"
					append_line("[color=green]%s[/color][color=gray]%s[/color]: %s[color=gray]%s[/color]" % [command, arguments_string, commands[command].description, " (built-in)" if commands[command].builtin else ""])
			if glob.is_empty():
				append_line("%d commands." % matches)
			else:
				append_line("%d commands matching the glob [color=cyan]%s[/color]." % [matches, glob])
	)

	add_builtin_command("cvarlist", ["glob"], "Lists all console variables. If a glob is specified (example: \"*list*\"), filters the results accordingly.",
		func(glob: String = "") -> void:
			var matches := 0
			for variable in variables:
				if glob.is_empty() or variable.match(glob):
					matches += 1
					append_line("[color=yellow]%s[/color][color=gray] = %s[/color]: %s" % [variable, variables[variable].value, variables[variable].description])
			if glob.is_empty():
				append_line("%d variables." % matches)
			else:
				append_line("%d variables matching the glob [color=cyan]%s[/color]." % [matches, glob])
	)


func set_display_mode(p_mode: DisplayMode) -> void:
	if p_mode == display_mode:
		return

	display_mode = p_mode

	match p_mode:
		DisplayMode.DISPLAY_MODE_DETAILED:
			visible = true
			input_line.visible = true
			version_label.visible = true
			old_mouse_mode = Input.mouse_mode
			if old_mouse_mode == Input.MOUSE_MODE_CONFINED_HIDDEN:
				Input.mouse_mode = Input.MOUSE_MODE_CONFINED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			input_line.grab_focus()
			# Prevent writing the toggle console character in the LineEdit, as we focus it automatically.
			get_viewport().set_input_as_handled()
		DisplayMode.DISPLAY_MODE_COMPACT:
			visible = true
			input_line.visible = false
			version_label.visible = false
			split_container.split_offset *= 0.5
			Input.mouse_mode = old_mouse_mode
		DisplayMode.DISPLAY_MODE_HIDDEN:
			visible = false
			# The effect of changing the split offset is visible after toggling
			# the detailed console again. We do it here so that the value isn't doubled on initial
			# display of the detailed console.
			split_container.split_offset *= 2


# This needs to be `_input` and not `_unhandled_input`, as we want to handle input
# already handled by the console's LineEdit or other project nodes.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_console"):
		set_display_mode(wrapi(display_mode + 1, 0, DisplayMode.DISPLAY_MODE_MAX) as DisplayMode)

	# Replicate RichTextLabel scrolling behavior even if not focused on the node.
	# Don't apply double-scrolling by checking whether the RichTextLabel is focused first.
	# Use exact match, so that selecting text using Shift + Home/Shift + End in the input doesn't scroll the console.
	if event.is_action_pressed(&"ui_page_up", true, true) and display_mode != DisplayMode.DISPLAY_MODE_HIDDEN and not log.has_focus():
		log.get_v_scroll_bar().set_value(log.get_v_scroll_bar().get_value() - log.get_v_scroll_bar().get_page())

	if event.is_action_pressed(&"ui_page_down", true, true) and display_mode != DisplayMode.DISPLAY_MODE_HIDDEN and not log.has_focus():
		log.get_v_scroll_bar().set_value(log.get_v_scroll_bar().get_value() + log.get_v_scroll_bar().get_page())

	if event.is_action_pressed(&"ui_home", true, true) and display_mode != DisplayMode.DISPLAY_MODE_HIDDEN and not log.has_focus():
		log.get_v_scroll_bar().set_value(0)

	if event.is_action_pressed(&"ui_end", true, true) and display_mode != DisplayMode.DISPLAY_MODE_HIDDEN and not log.has_focus():
		log.get_v_scroll_bar().set_value(log.get_v_scroll_bar().get_max())

	# `ui_up` and `ui_down` are not handled here, as they likely conflict with project controls
	# (e.g. if a character is controlled using the arrow keys).


func append_line(text: String = "") -> void:
	print_rich(text)
	log.append_text(text + "\n")


func add_command(p_name: String, p_arguments: Array[String], p_description: String, p_command: Callable) -> void:
	if variables.get(p_name) != null:
		push_error("Can't register console command \"%s\" as there is already a console variable with the same name." % p_name)
		return

	# TODO: Support marking optional arguments as such, so they can be distinguished in the help.
	commands[p_name] = {
		arguments = p_arguments,
		description = p_description,
		command = p_command,
		builtin = false,
	}


func add_builtin_command(p_name: String, p_arguments: Array[String], p_description: String, p_command: Callable) -> void:
	add_command(p_name, p_arguments, p_description, p_command)
	commands[p_name].builtin = true


func add_variable(p_name: String, p_type: String, p_value_hint: String, p_default: Variant, p_min: float, p_max: float, p_description: String, p_setter: Callable):
	if commands.get(p_name) != null:
		push_error("Can't register console variable \"%s\" as there is already a console command with the same name." % p_name)
		return

	variables[p_name] = {
		type = p_type,
		# Load configuration value when the variable is registered,
		# as it may not be registered when the console is first initialized.
		value = variables_storage.get_value("", p_name, p_default),
		value_hint = p_value_hint,
		default = p_default,
		min = p_min,
		max = p_max,
		description = p_description,
		setter = p_setter,
		builtin = false,
	}

	# Call variable setter automatically, so that the value is always effective
	# when loading a scene (regardless of whether it's the default or not).
	set_variable(p_name, variables[p_name].value)


func remove_command(p_name: String) -> void:
	commands[p_name] = null


func remove_variable(p_name: String) -> void:
	variables[p_name] = null


func run_command(p_name: String, p_arguments: Array) -> void:
	commands[p_name].command.callv(p_arguments)


func set_variable(p_name: String, p_value: Variant) -> void:
	var variable: Dictionary = variables[p_name]
	var value_clamped := clampf(p_value, variable.min, variable.max)
	if p_value < variable.min:
		append_line("[color=yellow]Value specified is outside the valid range [%s; %s]. Value was clamped to %s.[/color]" % [variable.min, variable.max, value_clamped])
	if p_value > variable.max:
		append_line("[color=yellow]Value specified is outside the valid range [%s; %s]. Value was clamped to %s.[/color]" % [variable.min, variable.max, value_clamped])
	var return_value: Variant = variables[p_name].setter.call(value_clamped)
	variables[p_name].value = return_value
	variables_storage.set_value("", p_name, return_value)


func _on_line_edit_text_submitted(new_text: String) -> void:
	input_line.clear()

	if not new_text.strip_edges().is_empty():
		var new_text_stripped := new_text.strip_edges()
		append_line("[i][color=gray]> " + new_text_stripped + "[/color][/i]")

		var text_split := new_text_stripped.split(" ")
		if commands.get(text_split[0]) != null:
			# TODO: Handle strings with quotes that span multiple words.
			var arguments := []
			for word in text_split.slice(1):
				arguments.push_back(word.lstrip("\"'").rstrip("\"'"))
			run_command(text_split[0], arguments)
		elif variables.get(text_split[0]) != null:
			var value := float(text_split[-1])
			set_variable(text_split[0], value)
		else:
			append_line("[color=red]Unknown command or variable: %s[/color]" % text_split[0])

		# Add a blank line to make future lines easier to distinguish from the command run.
		append_line("")


func _exit_tree() -> void:
	variables_storage.save(VARIABLES_STORAGE_PATH)
