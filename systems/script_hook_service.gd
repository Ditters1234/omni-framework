## ScriptHookService -- Shared runtime helper for invoking template hooks.
## Systems call this with template dictionaries so hook lookup stays centralized.
extends RefCounted

class_name ScriptHookService

const APP_SETTINGS := preload("res://core/app_settings.gd")
const WORLD_GEN_HOOK_NARRATION := "narration"
const WORLD_GEN_HOOK_TASK_FLAVOR := "task_flavor"
const WORLD_GEN_HOOK_LORE := "lore"

static var _task_flavor_cache: Dictionary = {}
static var _pending_task_flavors: Dictionary = {}
static var _entity_lore_cache: Dictionary = {}
static var _pending_entity_lore: Dictionary = {}
static var _part_lore_cache: Dictionary = {}
static var _pending_part_lore: Dictionary = {}


static func invoke_template_hook(template: Dictionary, method_name: String, args: Array = []) -> void:
	if template.is_empty() or method_name.is_empty():
		return
	var script_path := _extract_script_path(template)
	if script_path.is_empty():
		return
	var hook := ModLoader.get_script_hook(script_path)
	if hook == null or not hook.has_method(method_name):
		return
	hook.callv(method_name, args)


static func invoke_part_tick_hooks(tick: int) -> void:
	var entity_ids: Array[String] = []
	for entity_id_value in GameState.entity_instances.keys():
		var entity_id := str(entity_id_value)
		if entity_id.is_empty():
			continue
		entity_ids.append(entity_id)
	entity_ids.sort()
	for entity_id in entity_ids:
		var entity := GameState.get_entity_instance(entity_id)
		if entity == null:
			continue
		var carried_parts := _collect_carried_parts(entity)
		if carried_parts.is_empty():
			continue
		var entity_payload := entity.to_dict()
		for part in carried_parts:
			if part == null:
				continue
			var template := part.get_template()
			if template.is_empty():
				continue
			invoke_template_hook(template, "on_tick", [entity_payload.duplicate(true), part.to_dict(), tick])


static func invoke_world_event_narration(signal_name: String, args: Array = []) -> void:
	if signal_name.is_empty() or not _can_run_world_gen("narration_enabled"):
		return
	var hook := _get_global_hook(WORLD_GEN_HOOK_NARRATION)
	if hook == null or not hook.has_method("queue_event_narration_generation"):
		return
	hook.callv("queue_event_narration_generation", [signal_name, args.duplicate(true)])


static func request_task_flavor(task_template: Dictionary, context: Dictionary = {}) -> String:
	var template_id := str(task_template.get("template_id", "")).strip_edges()
	if template_id.is_empty():
		return ""
	if _task_flavor_cache.has(template_id):
		return str(_task_flavor_cache.get(template_id, ""))
	if _pending_task_flavors.has(template_id) or not _can_run_world_gen("task_flavor_enabled"):
		return ""
	var hook := _get_global_hook(WORLD_GEN_HOOK_TASK_FLAVOR)
	if hook == null or not hook.has_method("queue_task_flavor_generation"):
		return ""
	_pending_task_flavors[template_id] = true
	hook.callv("queue_task_flavor_generation", [task_template.duplicate(true), context.duplicate(true)])
	return ""


static func store_task_flavor(template_id: String, flavor_text: String) -> void:
	var normalized_template_id := template_id.strip_edges()
	var normalized_flavor_text := flavor_text.strip_edges()
	if normalized_template_id.is_empty():
		return
	_pending_task_flavors.erase(normalized_template_id)
	if normalized_flavor_text.is_empty():
		return
	_task_flavor_cache[normalized_template_id] = normalized_flavor_text
	if GameEvents == null:
		return
	if GameEvents.has_method("emit_dynamic"):
		GameEvents.emit_dynamic("event_narrated", ["task_flavor", normalized_template_id, normalized_flavor_text])
		return
	GameEvents.event_narrated.emit("task_flavor", normalized_template_id, normalized_flavor_text)


static func request_entity_lore(entity_template: Dictionary, context: Dictionary = {}) -> String:
	var template_id := str(entity_template.get("entity_id", "")).strip_edges()
	if template_id.is_empty():
		return ""
	if _entity_lore_cache.has(template_id):
		return str(_entity_lore_cache.get(template_id, ""))
	if _pending_entity_lore.has(template_id) or not _can_run_world_gen("lore_enabled"):
		return ""
	var hook := _get_global_hook(WORLD_GEN_HOOK_LORE)
	if hook == null or not hook.has_method("queue_entity_lore_generation"):
		return ""
	_pending_entity_lore[template_id] = true
	hook.callv("queue_entity_lore_generation", [entity_template.duplicate(true), context.duplicate(true)])
	return ""


static func request_part_lore(part_template: Dictionary, context: Dictionary = {}) -> String:
	var template_id := str(part_template.get("id", "")).strip_edges()
	if template_id.is_empty():
		return ""
	if _part_lore_cache.has(template_id):
		return str(_part_lore_cache.get(template_id, ""))
	if _pending_part_lore.has(template_id) or not _can_run_world_gen("lore_enabled"):
		return ""
	var hook := _get_global_hook(WORLD_GEN_HOOK_LORE)
	if hook == null or not hook.has_method("queue_part_lore_generation"):
		return ""
	_pending_part_lore[template_id] = true
	hook.callv("queue_part_lore_generation", [part_template.duplicate(true), context.duplicate(true)])
	return ""


static func store_entity_lore(template_id: String, lore_text: String) -> void:
	var normalized_template_id := template_id.strip_edges()
	var normalized_lore_text := lore_text.strip_edges()
	if normalized_template_id.is_empty():
		return
	_pending_entity_lore.erase(normalized_template_id)
	if normalized_lore_text.is_empty():
		return
	_entity_lore_cache[normalized_template_id] = normalized_lore_text
	if GameEvents == null:
		return
	if GameEvents.has_method("emit_dynamic"):
		GameEvents.emit_dynamic("event_narrated", ["entity_lore", normalized_template_id, normalized_lore_text])
		return
	GameEvents.event_narrated.emit("entity_lore", normalized_template_id, normalized_lore_text)


static func store_part_lore(template_id: String, lore_text: String) -> void:
	var normalized_template_id := template_id.strip_edges()
	var normalized_lore_text := lore_text.strip_edges()
	if normalized_template_id.is_empty():
		return
	_pending_part_lore.erase(normalized_template_id)
	if normalized_lore_text.is_empty():
		return
	_part_lore_cache[normalized_template_id] = normalized_lore_text
	if GameEvents == null:
		return
	if GameEvents.has_method("emit_dynamic"):
		GameEvents.emit_dynamic("event_narrated", ["part_lore", normalized_template_id, normalized_lore_text])
		return
	GameEvents.event_narrated.emit("part_lore", normalized_template_id, normalized_lore_text)


static func reset_world_gen_state() -> void:
	_task_flavor_cache.clear()
	_pending_task_flavors.clear()
	_entity_lore_cache.clear()
	_pending_entity_lore.clear()
	_part_lore_cache.clear()
	_pending_part_lore.clear()


static func _extract_script_path(template: Dictionary) -> String:
	return str(template.get("script_path", template.get("script_hook", "")))


static func _get_global_hook(hook_id: String) -> ScriptHook:
	var hook_path := _get_global_hook_path(hook_id)
	if hook_path.is_empty():
		return null
	return ModLoader.get_script_hook(hook_path)


static func _get_global_hook_path(hook_id: String) -> String:
	return str(DataManager.get_config_value("ai.world_gen_hooks.%s" % hook_id, "")).strip_edges()


static func _can_run_world_gen(config_flag: String) -> bool:
	if not AIManager.is_available():
		return false
	var ai_settings := APP_SETTINGS.get_ai_settings(APP_SETTINGS.load_settings())
	if not bool(ai_settings.get(APP_SETTINGS.AI_ENABLE_WORLD_GEN, false)):
		return false
	return bool(DataManager.get_config_value("ai.%s" % config_flag, true))


static func _collect_carried_parts(entity: EntityInstance) -> Array[PartInstance]:
	var parts: Array[PartInstance] = []
	var seen_instance_ids: Dictionary = {}
	if entity == null:
		return parts
	for part_value in entity.inventory:
		var inventory_part := part_value as PartInstance
		_append_unique_part(parts, seen_instance_ids, inventory_part)
	var slot_ids: Array = entity.equipped.keys()
	slot_ids.sort()
	for slot_id_value in slot_ids:
		var slot_id := str(slot_id_value)
		_append_unique_part(parts, seen_instance_ids, entity.get_equipped(slot_id))
	return parts


static func _append_unique_part(parts: Array[PartInstance], seen_instance_ids: Dictionary, part: PartInstance) -> void:
	if part == null:
		return
	var instance_id := part.instance_id
	if not instance_id.is_empty() and seen_instance_ids.has(instance_id):
		return
	if not instance_id.is_empty():
		seen_instance_ids[instance_id] = true
	parts.append(part)
