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
const SCREEN_EXCHANGE := "exchange"
const SCREEN_LIST_VIEW := "list_view"
const SCREEN_CHALLENGE := "challenge"
const SCREEN_TASK_PROVIDER := "task_provider"
const SCREEN_CATALOG_LIST := "catalog_list"
const SCREEN_DIALOGUE := "dialogue"
const SCREEN_ENTITY_SHEET := "entity_sheet"
const SCREEN_QUEST_LOG := "quest_log"
const SCREEN_FACTION_REP := "faction_rep"
const SCREEN_ACHIEVEMENT_LIST := "achievement_list"
const SCREEN_EVENT_LOG := "event_log"

const MAIN_MENU_SCENE := "res://ui/screens/main_menu/main_menu_screen.tscn"
const ASSEMBLY_EDITOR_SCENE := "res://ui/screens/backends/assembly_editor_screen.tscn"
const GAMEPLAY_SHELL_SCENE := "res://ui/screens/gameplay_shell/gameplay_shell_screen.tscn"
const LOCATION_VIEW_SCENE := "res://ui/screens/location_view/location_view_screen.tscn"
const SETTINGS_SCENE := "res://ui/screens/settings/settings_screen.tscn"
const SAVE_SLOT_LIST_SCENE := "res://ui/screens/save_slot_list/save_slot_list_screen.tscn"
const PAUSE_MENU_SCENE := "res://ui/screens/pause_menu/pause_menu_screen.tscn"
const CREDITS_SCENE := "res://ui/screens/credits/credits_screen.tscn"
const EXCHANGE_SCENE := "res://ui/screens/backends/exchange_screen.tscn"
const LIST_VIEW_SCENE := "res://ui/screens/backends/list_screen.tscn"
const CHALLENGE_SCENE := "res://ui/screens/backends/challenge_screen.tscn"
const TASK_PROVIDER_SCENE := "res://ui/screens/backends/task_provider_screen.tscn"
const CATALOG_LIST_SCENE := "res://ui/screens/backends/catalog_list_screen.tscn"
const DIALOGUE_SCENE := "res://ui/screens/backends/dialogue_screen.tscn"
const ENTITY_SHEET_SCENE := "res://ui/screens/backends/entity_sheet_screen.tscn"
const QUEST_LOG_SCENE := "res://ui/screens/backends/active_quest_log_screen.tscn"
const FACTION_REP_SCENE := "res://ui/screens/backends/faction_reputation_screen.tscn"
const ACHIEVEMENT_LIST_SCENE := "res://ui/screens/backends/achievement_list_screen.tscn"
const EVENT_LOG_SCENE := "res://ui/screens/backends/event_log_screen.tscn"

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

const APP_SCREEN_REGISTRY := {
	SCREEN_MAIN_MENU: MAIN_MENU_SCENE,
	SCREEN_ASSEMBLY_EDITOR: ASSEMBLY_EDITOR_SCENE,
	SCREEN_CHARACTER_CREATOR: ASSEMBLY_EDITOR_SCENE,
	SCREEN_GAMEPLAY_SHELL: GAMEPLAY_SHELL_SCENE,
	SCREEN_LOCATION_VIEW: LOCATION_VIEW_SCENE,
	SCREEN_SETTINGS: SETTINGS_SCENE,
	SCREEN_SAVE_SLOT_LIST: SAVE_SLOT_LIST_SCENE,
	SCREEN_PAUSE_MENU: PAUSE_MENU_SCENE,
	SCREEN_CREDITS: CREDITS_SCENE,
}

const BACKEND_SCREEN_MAP := {
	"AssemblyEditorBackend": SCREEN_ASSEMBLY_EDITOR,
	"ExchangeBackend": SCREEN_EXCHANGE,
	"ListBackend": SCREEN_LIST_VIEW,
	"ChallengeBackend": SCREEN_CHALLENGE,
	"TaskProviderBackend": SCREEN_TASK_PROVIDER,
	"CatalogListBackend": SCREEN_CATALOG_LIST,
	"DialogueBackend": SCREEN_DIALOGUE,
	"EntitySheetBackend": SCREEN_ENTITY_SHEET,
	"ActiveQuestLogBackend": SCREEN_QUEST_LOG,
	"FactionReputationBackend": SCREEN_FACTION_REP,
	"AchievementListBackend": SCREEN_ACHIEVEMENT_LIST,
	"EventLogBackend": SCREEN_EVENT_LOG,
}

const BACKEND_SCREEN_REGISTRY := {
	SCREEN_EXCHANGE: EXCHANGE_SCENE,
	SCREEN_LIST_VIEW: LIST_VIEW_SCENE,
	SCREEN_CHALLENGE: CHALLENGE_SCENE,
	SCREEN_TASK_PROVIDER: TASK_PROVIDER_SCENE,
	SCREEN_CATALOG_LIST: CATALOG_LIST_SCENE,
	SCREEN_DIALOGUE: DIALOGUE_SCENE,
	SCREEN_ENTITY_SHEET: ENTITY_SHEET_SCENE,
	SCREEN_QUEST_LOG: QUEST_LOG_SCENE,
	SCREEN_FACTION_REP: FACTION_REP_SCENE,
	SCREEN_ACHIEVEMENT_LIST: ACHIEVEMENT_LIST_SCENE,
	SCREEN_EVENT_LOG: EVENT_LOG_SCENE,
}

static func get_screen_id_for_backend(backend_class: String) -> String:
	var screen_id_value: Variant = BACKEND_SCREEN_MAP.get(backend_class, "")
	return str(screen_id_value)

static func has_backend_class(backend_class: String) -> bool:
	return BACKEND_SCREEN_MAP.has(backend_class)

static func has_known_screen_id(screen_id: String) -> bool:
	if screen_id.is_empty():
		return false
	if APP_SCREEN_REGISTRY.has(screen_id):
		return true
	return BACKEND_SCREEN_REGISTRY.has(screen_id)

static func get_known_screen_ids() -> Array[String]:
	var screen_ids: Array[String] = []
	for screen_id_value in APP_SCREEN_REGISTRY.keys():
		screen_ids.append(str(screen_id_value))
	for screen_id_value in BACKEND_SCREEN_REGISTRY.keys():
		var screen_id := str(screen_id_value)
		if screen_ids.has(screen_id):
			continue
		screen_ids.append(screen_id)
	screen_ids.sort()
	return screen_ids

static func get_runtime_screen_registry() -> Dictionary:
	var runtime_registry := get_app_screen_registry()
	runtime_registry.merge(get_backend_screen_registry(), true)
	return runtime_registry

static func get_app_screen_registry() -> Dictionary:
	return APP_SCREEN_REGISTRY.duplicate(true)

static func get_backend_screen_registry() -> Dictionary:
	return BACKEND_SCREEN_REGISTRY.duplicate(true)
