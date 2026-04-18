extends Control

const SCREEN_MAIN_MENU := "main_menu"
const SHIPPED_DEPENDENCIES := [
	"Any-JSON (A2J)",
	"LimboAI",
	"Dialogue Manager",
	"NobodyWho",
]

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SubtitleLabel
@onready var _credits_label: Label = $MarginContainer/PanelContainer/VBoxContainer/ScrollContainer/CreditsLabel
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton


func initialize(_params: Dictionary = {}) -> void:
	_refresh()


func _ready() -> void:
	_refresh()


func on_route_revealed() -> void:
	_refresh()


func _refresh() -> void:
	_title_label.text = "Credits"
	_subtitle_label.text = "Engine attribution, shipped dependencies, and loaded mods."
	_credits_label.text = _build_credits_text()
	_back_button.text = "Back"


func _build_credits_text() -> String:
	var lines: Array[String] = []
	lines.append("Omni-Framework")
	lines.append("Version: %s" % str(ProjectSettings.get_setting("application/config/version", "0.1.0")))
	lines.append("")
	lines.append("Shipped Dependencies")
	for dependency_value in SHIPPED_DEPENDENCIES:
		lines.append("- %s" % str(dependency_value))
	lines.append("")
	lines.append("Loaded Mods")
	if ModLoader.loaded_mods.is_empty():
		lines.append("- None")
	else:
		for manifest_value in ModLoader.loaded_mods:
			if not manifest_value is Dictionary:
				continue
			var manifest: Dictionary = manifest_value
			var mod_name := str(manifest.get("name", manifest.get("id", "Unknown Mod")))
			var mod_id := str(manifest.get("id", "unknown"))
			var mod_version := str(manifest.get("version", "0.0.0"))
			lines.append("- %s (%s) v%s" % [mod_name, mod_id, mod_version])
	return "\n".join(lines)


func _on_back_button_pressed() -> void:
	if UIRouter.stack_depth() > 1:
		UIRouter.pop()
		return
	UIRouter.replace_all(SCREEN_MAIN_MENU)
