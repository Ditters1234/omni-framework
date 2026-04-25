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

## Active task instances: { runtime_id → task_instance_dict }
var active_tasks: Dictionary = {}

## Completed quest ids.
var completed_quests: Array[String] = []

## Completed non-repeatable task template ids.
var completed_task_templates: Array[String] = []

## Unlocked achievement ids.
var unlocked_achievements: Array[String] = []

## Arbitrary flags set by script hooks / quests: { flag_key → Variant }
var flags: Dictionary = {}
var achievement_stats: Dictionary = {}
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

	var player_template_id := str(DataManager.get_config_value("game.starting_player_id", ""))
	if player_template_id.is_empty():
		push_warning("GameState: config key 'game.starting_player_id' must reference a player entity template.")
		return
	var player_template := DataManager.get_entity(player_template_id)
	if player_template.is_empty():
		push_warning("GameState: unable to find starting player template '%s'" % player_template_id)
		return

	var player_entity := EntityInstance.from_template(player_template)
	player = player_entity
	entity_instances[player_entity.entity_id] = player_entity
	var configured_location_id := str(DataManager.get_config_value("game.starting_location", ""))
	current_location_id = configured_location_id if not configured_location_id.is_empty() else player_entity.location_id
	player_entity.location_id = current_location_id
	player_entity.discover_location(current_location_id)
	var discovered_locations_value: Variant = DataManager.get_config_value("game.starting_discovered_locations", [])
	if discovered_locations_value is Array:
		var discovered_locations: Array = discovered_locations_value
		for location_id_value in discovered_locations:
			var discovered_location_id := str(location_id_value)
			if discovered_location_id.is_empty() or not DataManager.has_location(discovered_location_id):
				continue
			player_entity.discover_location(discovered_location_id)
	_instantiate_world_entities(player_entity.template_id)
	_sync_timekeeper()
	GameEvents.game_started.emit()


## Resets all runtime state (called before loading a save).
func reset() -> void:
	player = null
	entity_instances.clear()
	current_location_id = ""
	current_tick = 0
	current_day = 1
	active_quests.clear()
	active_tasks.clear()
	completed_quests.clear()
	completed_task_templates.clear()
	unlocked_achievements.clear()
	flags.clear()
	achievement_stats.clear()
	ScriptHookService.reset_world_gen_state()
	_sync_timekeeper()


func _instantiate_world_entities(player_template_id: String) -> void:
	for entity_id_value in DataManager.entities.keys():
		var entity_id := str(entity_id_value)
		# Skip the player template and any template already instantiated.
		# World entities are singletons keyed by their template id.  We check
		# both the DataManager key *and* entity_instances to handle spawned
		# entities whose runtime id was changed by ActionDispatcher.
		if entity_id.is_empty() or entity_id == player_template_id:
			continue
		if entity_instances.has(entity_id):
			continue
		# Also guard against duplicate instances when a previous spawn_entity
		# action already created an instance from this template under a
		# different runtime id.
		var already_instantiated := false
		for existing_entity_data in entity_instances.values():
			var existing_entity := existing_entity_data as EntityInstance
			if existing_entity != null and existing_entity.template_id == entity_id:
				already_instantiated = true
				break
		if already_instantiated:
			continue
		var entity_template := DataManager.get_entity(entity_id)
		if entity_template.is_empty():
			continue
		var entity := EntityInstance.from_template(entity_template)
		entity_instances[entity.entity_id] = entity


# ---------------------------------------------------------------------------
# Location
# ---------------------------------------------------------------------------


func get_entity_instances_at_location(location_id: String) -> Array[EntityInstance]:
	var results: Array[EntityInstance] = []
	for entity_data in entity_instances.values():
		var entity := entity_data as EntityInstance
		if entity != null and entity.location_id == location_id and entity.entity_id != "player":
			results.append(entity)
	return results


## Moves the player to a new location and emits location_changed.
## travel_ticks is optional so callers can charge time for routed travel
## without forcing teleports or scripted relocations to consume time.
func travel_to(location_id: String, travel_ticks: int = 0) -> void:
	if location_id.is_empty():
		return
	var old_id := current_location_id
	if old_id == location_id:
		return
	if travel_ticks > 0:
		TimeKeeper.advance_ticks(travel_ticks)
	var player_entity := player as EntityInstance
	var old_template := DataManager.get_location(old_id)
	var new_template := DataManager.get_location(location_id)
	current_location_id = location_id
	var was_discovered := false
	if player_entity != null:
		was_discovered = player_entity.has_discovered_location(location_id)
		player_entity.location_id = location_id
		player_entity.discover_location(location_id)
	if not old_template.is_empty():
		ScriptHookService.invoke_template_hook(old_template, "on_location_exit", [old_template.duplicate(true)])
	if not new_template.is_empty():
		ScriptHookService.invoke_template_hook(new_template, "on_location_enter", [new_template.duplicate(true)])
	GameEvents.location_changed.emit(old_id, current_location_id)
	ScriptHookService.invoke_world_event_narration("location_changed", [old_id, current_location_id])
	if not was_discovered:
		track_achievement_stat("locations_discovered", 1.0)


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
	GameEvents.flag_changed.emit("global", flag_key, value)


func get_flag(flag_key: String, default_value: Variant = null) -> Variant:
	return flags.get(flag_key, default_value)


func has_flag(flag_key: String) -> bool:
	return flags.has(flag_key)


func track_achievement_stat(stat_name: String, delta: float) -> void:
	if stat_name.is_empty() or delta == 0.0:
		return
	var current_value := float(achievement_stats.get(stat_name, 0.0))
	achievement_stats[stat_name] = current_value + delta
	_check_achievement_unlocks(stat_name)


func unlock_achievement(achievement_id: String) -> bool:
	if achievement_id.is_empty() or achievement_id in unlocked_achievements:
		return false
	unlocked_achievements.append(achievement_id)
	var achievement := AchievementRegistry.get_achievement(achievement_id)
	var unlock_vfx := ""
	var unlock_sound := ""
	if not achievement.is_empty():
		unlock_vfx = str(achievement.get("unlock_vfx", ""))
		unlock_sound = str(achievement.get("unlock_sound", ""))
	GameEvents.achievement_unlocked.emit(achievement_id, unlock_vfx)
	_trigger_achievement_unlock_vfx(unlock_vfx)
	if not unlock_sound.is_empty():
		AudioManager.play_sfx(unlock_sound)
	return true


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
	for entity_id_value in entity_instances.keys():
		var entity_id := str(entity_id_value)
		var entity_data: Variant = entity_instances.get(entity_id, null)
		var entity := entity_data as EntityInstance
		if entity == null:
			continue
		entities_payload[entity_id] = entity.to_dict()

	return {
		"player_id": "" if player == null else player.entity_id,
		"entity_instances": entities_payload,
		"current_location_id": current_location_id,
		"current_tick": current_tick,
		"current_day": current_day,
		"active_quests": active_quests.duplicate(true),
		"active_tasks": active_tasks.duplicate(true),
		"completed_quests": completed_quests.duplicate(),
		"completed_task_templates": completed_task_templates.duplicate(),
		"unlocked_achievements": unlocked_achievements.duplicate(),
		"flags": flags.duplicate(true),
		"achievement_stats": achievement_stats.duplicate(true),
	}


## Restores state from a deserialized Dictionary.
func from_dict(data: Dictionary) -> void:
	reset()
	current_location_id = str(data.get("current_location_id", ""))
	current_tick = int(data.get("current_tick", 0))
	current_day = int(data.get("current_day", 1))
	var active_quests_data: Variant = data.get("active_quests", {})
	if active_quests_data is Dictionary:
		active_quests = active_quests_data.duplicate(true)
	var active_tasks_data: Variant = data.get("active_tasks", {})
	if active_tasks_data is Dictionary:
		active_tasks = active_tasks_data.duplicate(true)
	completed_quests = _to_string_array(data.get("completed_quests", []))
	completed_task_templates = _to_string_array(data.get("completed_task_templates", []))
	unlocked_achievements = _to_string_array(data.get("unlocked_achievements", []))
	var flags_data: Variant = data.get("flags", {})
	if flags_data is Dictionary:
		flags = flags_data.duplicate(true)
	var achievement_stats_data: Variant = data.get("achievement_stats", {})
	if achievement_stats_data is Dictionary:
		achievement_stats = achievement_stats_data.duplicate(true)

	var entity_instances_data: Variant = data.get("entity_instances", {})
	if not entity_instances_data is Dictionary:
		return
	var entities_dict: Dictionary = entity_instances_data
	for entity_id in entities_dict.keys():
		var entity := EntityInstance.new()
		var entity_payload: Variant = entities_dict.get(entity_id, {})
		if not entity_payload is Dictionary:
			continue
		entity.from_dict(entity_payload)
		entity_instances[entity.entity_id] = entity

	var player_id := str(data.get("player_id", ""))
	if not player_id.is_empty() and entity_instances.has(player_id):
		player = entity_instances[player_id]
	_sync_timekeeper()


func get_entity_instance(entity_id: String) -> EntityInstance:
	if entity_id == "player" and player:
		return player as EntityInstance
	return entity_instances.get(entity_id, null) as EntityInstance


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


func validate_runtime_state() -> Array[String]:
	var issues: Array[String] = []
	var player_entity := player as EntityInstance
	if player_entity == null:
		issues.append("Runtime state is missing a player entity.")
	elif not entity_instances.has(player_entity.entity_id):
		issues.append("Player entity '%s' is not present in entity_instances." % player_entity.entity_id)

	if not current_location_id.is_empty() and DataManager.get_location(current_location_id).is_empty():
		issues.append("Current location '%s' no longer exists." % current_location_id)

	var seen_instance_ids: Dictionary = {}
	for entity_data in entity_instances.values():
		var entity := entity_data as EntityInstance
		if entity == null:
			continue
		_collect_entity_validation_issues(entity, issues, seen_instance_ids)

	for runtime_id_value in active_tasks.keys():
		var runtime_id := str(runtime_id_value)
		var task_data: Variant = active_tasks.get(runtime_id_value, {})
		if not task_data is Dictionary:
			continue
		var task_instance: Dictionary = task_data
		var template_id := str(task_instance.get("template_id", ""))
		if not template_id.is_empty() and TaskRegistry.get_task(template_id).is_empty():
			issues.append("Active task '%s' references missing template '%s'." % [runtime_id, template_id])
	return issues


func _check_achievement_unlocks(stat_name: String) -> void:
	var current_value := float(achievement_stats.get(stat_name, 0.0))
	var locked_achievements := AchievementRegistry.get_locked(unlocked_achievements)
	for achievement_data in locked_achievements:
		if not achievement_data is Dictionary:
			continue
		var achievement: Dictionary = achievement_data
		if str(achievement.get("stat_name", "")) != stat_name:
			continue
		var requirement := float(achievement.get("requirement", 0.0))
		if current_value < requirement:
			continue
		var achievement_id := str(achievement.get("achievement_id", ""))
		if achievement_id.is_empty():
			continue
		unlock_achievement(achievement_id)


func _trigger_achievement_unlock_vfx(_unlock_vfx: String) -> void:
	# Reserved for future achievement VFX infrastructure.
	return


func _to_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		result.append(str(value))
	return result


func _collect_entity_validation_issues(entity: EntityInstance, issues: Array[String], seen_instance_ids: Dictionary) -> void:
	if not entity.template_id.is_empty() and DataManager.get_entity(entity.template_id).is_empty():
		issues.append("Entity '%s' references missing template '%s'." % [entity.entity_id, entity.template_id])
	if not entity.location_id.is_empty() and DataManager.get_location(entity.location_id).is_empty():
		issues.append("Entity '%s' references missing location '%s'." % [entity.entity_id, entity.location_id])
	StatManager.clamp_all_to_capacity(entity)
	for part_data in entity.inventory:
		var inventory_part := part_data as PartInstance
		if inventory_part == null:
			continue
		_validate_part_reference(entity.entity_id, inventory_part, issues, seen_instance_ids)
	for slot_value in entity.equipped.keys():
		var slot := str(slot_value)
		var equipped_part := entity.get_equipped(slot)
		if equipped_part == null:
			continue
		_validate_part_reference(entity.entity_id, equipped_part, issues, seen_instance_ids)


func _validate_part_reference(entity_id: String, part: PartInstance, issues: Array[String], seen_instance_ids: Dictionary) -> void:
	if part.instance_id.is_empty():
		issues.append("Entity '%s' contains a part with no runtime instance_id." % entity_id)
	else:
		var existing_data: Variant = seen_instance_ids.get(part.instance_id, null)
		if existing_data is Dictionary:
			var existing: Dictionary = existing_data
			if str(existing.get("entity_id", "")) != entity_id or str(existing.get("template_id", "")) != part.template_id:
				issues.append("Duplicate part instance_id '%s' detected in runtime state." % part.instance_id)
		else:
			seen_instance_ids[part.instance_id] = {
				"entity_id": entity_id,
				"template_id": part.template_id,
			}
	if part.template_id.is_empty() or DataManager.get_part(part.template_id).is_empty():
		issues.append("Entity '%s' references missing part template '%s'." % [entity_id, part.template_id])


func _sync_timekeeper() -> void:
	if TimeKeeper != null and TimeKeeper.has_method("sync_from_game_state"):
		TimeKeeper.sync_from_game_state()
