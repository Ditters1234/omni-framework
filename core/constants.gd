## Constants — Project-wide shared constants.
## Import with: const C = preload("res://core/constants.gd")
extends RefCounted

class_name OmniConstants

# ---------------------------------------------------------------------------
# Namespacing
# ---------------------------------------------------------------------------
const BASE_MOD_ID := "base"
const ID_SEPARATOR := ":"

# ---------------------------------------------------------------------------
# Save system
# ---------------------------------------------------------------------------
const MAX_SAVE_SLOTS := 5
const SAVE_SCHEMA_VERSION := 1

# ---------------------------------------------------------------------------
# Stat system
# ---------------------------------------------------------------------------
const CAPACITY_SUFFIX := "_max"      # e.g. "health_max"
const STAT_MIN := 0.0

# ---------------------------------------------------------------------------
# Mod loading
# ---------------------------------------------------------------------------
const MOD_MANIFEST_FILE := "mod.json"
const BASE_MOD_LOAD_ORDER := 0

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
const NOTIFICATION_LEVEL_INFO := "info"
const NOTIFICATION_LEVEL_WARN := "warn"
const NOTIFICATION_LEVEL_ERROR := "error"

# ---------------------------------------------------------------------------
# Data file names (relative to a mod's data/ directory)
# ---------------------------------------------------------------------------
const DATA_DEFINITIONS := "definitions.json"
const DATA_PARTS := "parts.json"
const DATA_ENTITIES := "entities.json"
const DATA_LOCATIONS := "locations.json"
const DATA_FACTIONS := "factions.json"
const DATA_QUESTS := "quests.json"
const DATA_TASKS := "tasks.json"
const DATA_RECIPES := "recipes.json"
const DATA_ACHIEVEMENTS := "achievements.json"
const DATA_AI_PERSONAS := "ai_personas.json"
const DATA_AI_TEMPLATES := "ai_templates.json"
const DATA_CONFIG := "config.json"
