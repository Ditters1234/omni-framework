## GameState — Active runtime state.
## Holds the player entity instance, current location, tick counter,
## active currencies, and any other live session data.
## Serialized to / restored from save files by SaveManager.
extends Node

class_name OmniGameState

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

## The player's EntityInstance. Null until a game is started or loaded.
var player: Object = null  # EntityInstance

## All live entity instances keyed by runtime/entity id.
var entity_instances: Dictionary = {}

## ID of the location the player is currently at.
var current_location_id: String = ""

## Current absolute tick count (set by TimeKeeper).
var current_tick: int = 0

## Current in-game day.
var current_day: int = 1

## Active quest instances: { quest_id → QuestInstance }
var active_quests: Dictionary = {}

## Completed quest ids.
var completed_quests: Array[String] = []

## Unlocked achievement ids.
var unlocked_achievements: Array[String] = []

## Arbitrary flags set by script hooks / quests: { flag_key → Variant }
var flags: Dictionary = {}
var _quest_tracker: QuestTracker = null

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_quest_tracker = QuestTracker.new()
	add_child(_quest_tracker)


# ---------------------------------------------------------------------------
# Session lifecycle
# ---------------------------------------------------------------------------

## Initializes a fresh game state from config defaults.
func new_game() -> void:
	reset()

	var player_template_id := str(DataManager.get_config_value("game.starting_player_id", "base:player"))
	var player_template := DataManager.get_entity(player_template_id)
	if player_template.is_empty():
		push_warning("GameState: unable to find starting player template '%s'" % player_template_id)
		return

	player = EntityInstance.from_template(player_template)
	entity_instances[player.entity_id] = player
	current_location_id = str(DataManager.get_config_value("game.starting_location", player.location_id))
	player.location_id = current_location_id
	GameEvents.game_started.emit()


## Resets all runtime state (called before loading a save).
func reset() -> void:
	player = null
	entity_instances.clear()
	current_location_id = ""
	current_tick = 0
	current_day = 1
	active_quests.clear()
	completed_quests.clear()
	unlocked_achievements.clear()
	flags.clear()


# ---------------------------------------------------------------------------
# Location
# ---------------------------------------------------------------------------

## Moves the player to a new location and emits location_changed.
func travel_to(location_id: String) -> void:
	if location_id.is_empty():
		return
	var old_id := current_location_id
	current_location_id = location_id
	if player:
		player.location_id = location_id
	GameEvents.location_changed.emit(old_id, current_location_id)


# ---------------------------------------------------------------------------
# Currency
# ---------------------------------------------------------------------------

func get_currency(currency_key: String) -> float:
	if player and player is EntityInstance:
		return player.get_currency(currency_key)
	return 0.0


func add_currency(currency_key: String, amount: float) -> void:
	if player and player is EntityInstance:
		player.add_currency(currency_key, amount)


func spend_currency(currency_key: String, amount: float) -> bool:
	if player and player is EntityInstance:
		return player.spend_currency(currency_key, amount)
	return false


func has_currency(currency_key: String, amount: float) -> bool:
	return get_currency(currency_key) >= amount


# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------

func set_flag(flag_key: String, value: Variant) -> void:
	flags[flag_key] = value


func get_flag(flag_key: String, default_value: Variant = null) -> Variant:
	return flags.get(flag_key, default_value)


func has_flag(flag_key: String) -> bool:
	return flags.has(flag_key)


# ---------------------------------------------------------------------------
# Quests
# ---------------------------------------------------------------------------

func start_quest(quest_id: String) -> bool:
	if _quest_tracker == null:
		return false
	return _quest_tracker.start_quest(quest_id)


func advance_quest(quest_id: String, transition: String = "") -> void:
	if _quest_tracker == null:
		return
	_quest_tracker.advance_quest(quest_id, transition)


func complete_quest(quest_id: String) -> void:
	if _quest_tracker == null:
		return
	_quest_tracker.complete_quest(quest_id)


func fail_quest(quest_id: String) -> void:
	if _quest_tracker == null:
		return
	_quest_tracker.fail_quest(quest_id)


# ---------------------------------------------------------------------------
# Serialization (called by SaveManager)
# ---------------------------------------------------------------------------

## Returns a Dictionary suitable for A2J serialization.
func to_dict() -> Dictionary:
	var entities_payload: Dictionary = {}
	for entity_id in entity_instances.keys():
		var entity: EntityInstance = entity_instances[entity_id]
		entities_payload[entity_id] = entity.to_dict()

	return {
		"player_id": "" if player == null else player.entity_id,
		"entity_instances": entities_payload,
		"current_location_id": current_location_id,
		"current_tick": current_tick,
		"current_day": current_day,
		"active_quests": active_quests.duplicate(true),
		"completed_quests": completed_quests.duplicate(),
		"unlocked_achievements": unlocked_achievements.duplicate(),
		"flags": flags.duplicate(true),
	}


## Restores state from a deserialized Dictionary.
func from_dict(data: Dictionary) -> void:
	reset()
	current_location_id = str(data.get("current_location_id", ""))
	current_tick = int(data.get("current_tick", 0))
	current_day = int(data.get("current_day", 1))
	active_quests = data.get("active_quests", {}).duplicate(true)
	completed_quests = _to_string_array(data.get("completed_quests", []))
	unlocked_achievements = _to_string_array(data.get("unlocked_achievements", []))
	flags = data.get("flags", {}).duplicate(true)

	for entity_id in data.get("entity_instances", {}).keys():
		var entity := EntityInstance.new()
		entity.from_dict(data["entity_instances"][entity_id])
		entity_instances[entity.entity_id] = entity

	var player_id := str(data.get("player_id", ""))
	if not player_id.is_empty() and entity_instances.has(player_id):
		player = entity_instances[player_id]


func get_entity_instance(entity_id: String) -> EntityInstance:
	if entity_id == "player" and player:
		return player
	return entity_instances.get(entity_id, null)


func commit_entity_instance(entity: EntityInstance, lookup_id: String = "") -> void:
	if entity == null:
		return
	entity_instances[entity.entity_id] = entity
	if lookup_id == "player":
		player = entity
		return
	var current_player := player as EntityInstance
	if current_player != null and current_player.entity_id == entity.entity_id:
		player = entity


func _to_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		result.append(str(value))
	return result
