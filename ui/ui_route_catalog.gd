extends RefCounted

class_name OmniUIRouteCatalog

const SCREEN_MAIN_MENU := "main_menu"
const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const SCREEN_CHARACTER_CREATOR := "character_creator"
const SCREEN_GAMEPLAY_SHELL := "gameplay_shell"
const SCREEN_LOCATION_VIEW := "location_view"
const SCREEN_SETTINGS := "settings"
const SCREEN_SAVE_SLOT_LIST := "save_slot_list"
const SCREEN_PAUSE_MENU := "pause_menu"
const SCREEN_CREDITS := "credits"

const ENGINE_SCREEN_IDS := [
	SCREEN_MAIN_MENU,
	SCREEN_ASSEMBLY_EDITOR,
	SCREEN_CHARACTER_CREATOR,
	SCREEN_GAMEPLAY_SHELL,
	SCREEN_LOCATION_VIEW,
	SCREEN_SETTINGS,
	SCREEN_SAVE_SLOT_LIST,
	SCREEN_PAUSE_MENU,
	SCREEN_CREDITS,
]

const BACKEND_SCREEN_MAP := {
	"AssemblyEditorBackend": "assembly_editor",
	"ExchangeBackend": "exchange",
	"ListBackend": "list_view",
	"ChallengeBackend": "challenge",
	"TaskProviderBackend": "task_provider",
	"CatalogListBackend": "catalog_list",
	"DialogueBackend": "dialogue",
}


static func get_screen_id_for_backend(backend_class: String) -> String:
	var screen_id_value: Variant = BACKEND_SCREEN_MAP.get(backend_class, "")
	return str(screen_id_value)


static func has_backend_class(backend_class: String) -> bool:
	return BACKEND_SCREEN_MAP.has(backend_class)


static func has_known_screen_id(screen_id: String) -> bool:
	if screen_id.is_empty():
		return false
	if ENGINE_SCREEN_IDS.has(screen_id):
		return true
	for screen_id_value in BACKEND_SCREEN_MAP.values():
		if str(screen_id_value) == screen_id:
			return true
	return false


static func get_known_screen_ids() -> Array[String]:
	var screen_ids: Array[String] = []
	for screen_id in ENGINE_SCREEN_IDS:
		if not screen_ids.has(screen_id):
			screen_ids.append(screen_id)
	for screen_id_value in BACKEND_SCREEN_MAP.values():
		var screen_id := str(screen_id_value)
		if screen_id.is_empty() or screen_ids.has(screen_id):
			continue
		screen_ids.append(screen_id)
	screen_ids.sort()
	return screen_ids
