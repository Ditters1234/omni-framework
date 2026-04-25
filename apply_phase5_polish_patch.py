#!/usr/bin/env python3
"""
Drop-in Phase 5 UI polish patch for omni-framework.
Run from the repository root:
    python apply_phase5_polish_patch.py

The patch edits existing Godot scripts in place and writes .bak backups once.
"""
from __future__ import annotations
from pathlib import Path
import re
import sys

ROOT = Path.cwd()


def read_rel(path: str) -> str:
    p = ROOT / path
    if not p.exists():
        raise FileNotFoundError(f"Missing expected file: {path}")
    return p.read_text(encoding="utf-8")


def write_rel(path: str, text: str) -> None:
    p = ROOT / path
    backup = p.with_suffix(p.suffix + ".phase5.bak")
    if not backup.exists():
        backup.write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
    p.write_text(text, encoding="utf-8")


def replace_func(text: str, func_name: str, replacement: str) -> str:
    """Replace a top-level GDScript function by indentation boundaries."""
    pattern = re.compile(rf"^(?:static\s+)?func\s+{re.escape(func_name)}\s*\(", re.M)
    m = pattern.search(text)
    if not m:
        raise RuntimeError(f"Could not find function {func_name}")
    start = m.start()
    next_m = re.search(r"\n(?=(?:static\s+)?func\s+\w+\s*\(|class_name\s+|const\s+|var\s+|@onready\s+|# -{5,})", text[start + 1:])
    end = start + 1 + next_m.start() if next_m else len(text)
    return text[:start] + replacement.rstrip() + "\n" + text[end:]
def insert_before(text: str, marker: str, insertion: str) -> str:
    """Insert helper before marker; append if local checkout has renamed/removed the marker."""
    if insertion.strip() in text:
        return text
    idx = text.find(marker)
    if idx < 0:
        return text.rstrip() + "\n\n" + insertion.rstrip() + "\n"
    return text[:idx] + insertion.rstrip() + "\n\n" + text[idx:]
def patch_stat_bar() -> None:
    path = "ui/components/stat_bar.gd"
    text = read_rel(path)
    if "var _breakdown_label: Label = null" not in text:
        text = text.replace("var _pending_view_model: Dictionary = {}\n", "var _pending_view_model: Dictionary = {}\nvar _breakdown_label: Label = null\n")
    replacement = r'''func _apply_view_model(view_model: Dictionary) -> void:
	var stat_id := str(view_model.get("stat_id", ""))
	var label := str(view_model.get("label", BACKEND_HELPERS.humanize_id(stat_id)))
	var value := float(view_model.get("value", 0.0))
	var max_value := float(view_model.get("max_value", 0.0))
	var color_token := str(view_model.get("color_token", "info"))
	var accent_color := _get_semantic_color(color_token, FALLBACK_INFO_COLOR)
	var breakdown_text := str(view_model.get("breakdown_text", "")).strip_edges()

	_label.text = label if not label.is_empty() else "Stat"
	_value_label.text = _build_value_text(value, max_value)
	_value_label.modulate = accent_color
	_apply_progress_theme(accent_color)

	if max_value > 0.0:
		_progress_bar.visible = true
		_progress_bar.max_value = max_value
		_progress_bar.value = clampf(value, 0.0, max_value)
	else:
		_progress_bar.visible = false

	_apply_breakdown_label(breakdown_text)
'''
    text = replace_func(text, "_apply_view_model", replacement)
    helper = r'''func _apply_breakdown_label(breakdown_text: String) -> void:
	if _breakdown_label == null:
		_breakdown_label = Label.new()
		_breakdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_breakdown_label.add_theme_font_size_override("font_size", 11)
		$MarginContainer/VBoxContainer.add_child(_breakdown_label)
	_breakdown_label.text = breakdown_text
	_breakdown_label.visible = not breakdown_text.is_empty()
'''
    text = insert_before(text, "func _build_value_text", helper)
    if "func _build_value_text" not in text:
        text += r'''

func _build_value_text(value: float, max_value: float) -> String:
	var value_text := _format_number(value)
	if max_value <= 0.0:
		return value_text
	return "%s / %s" % [value_text, _format_number(max_value)]
'''
    if "func _format_number" not in text:
        text += r'''

func _format_number(amount: float) -> String:
	if absf(amount - roundf(amount)) < 0.001:
		return str(int(roundf(amount)))
	return "%.2f" % amount
'''
    write_rel(path, text)


def patch_backend_helpers() -> None:
    path = "ui/screens/backends/backend_helpers.gd"
    text = read_rel(path)
    # Add breakdown text to both stat-line builders without changing their call contracts.
    text = text.replace('''\t	return {
\t\t\t"stat_id": stat_id,
\t\t\t"label": humanize_id(stat_id),
\t\t\t"value": float(entity.stats.get(stat_id, 0.0)),
\t\t\t"max_value": float(entity.stats.get(capacity_id, 0.0)),
\t\t\t"color_token": color_token,
\t\t}''', '''\t\treturn {
\t\t\t"stat_id": stat_id,
\t\t\t"label": humanize_id(stat_id),
\t\t\t"value": float(entity.stats.get(stat_id, 0.0)),
\t\t\t"max_value": float(entity.stats.get(capacity_id, 0.0)),
\t\t\t"color_token": color_token,
\t\t\t"breakdown_text": "Resource stat • current / capacity",
\t\t}''')
    text = text.replace('''\treturn {
\t\t"stat_id": stat_id,
\t\t"label": humanize_id(stat_id),
\t\t"value": float(entity.stats.get(stat_id, 0.0)),
\t\t"color_token": color_token,
\t}''', '''\treturn {
\t\t"stat_id": stat_id,
\t\t"label": humanize_id(stat_id),
\t\t"value": float(entity.stats.get(stat_id, 0.0)),
\t\t"color_token": color_token,
\t\t"breakdown_text": "Base stat",
\t}''')
    text = text.replace('''\t\treturn {
\t\t\t"stat_id": stat_id,
\t\t\t"label": humanize_id(stat_id),
\t\t\t"value": value,
\t\t\t"max_value": _read_float(effective_stats.get(capacity_id, 0.0)),
\t\t\t"color_token": color_token,
\t\t}''', '''\t\treturn {
\t\t\t"stat_id": stat_id,
\t\t\t"label": humanize_id(stat_id),
\t\t\t"value": value,
\t\t\t"max_value": _read_float(effective_stats.get(capacity_id, 0.0)),
\t\t\t"color_token": color_token,
\t\t\t"breakdown_text": "Effective resource • includes equipped parts and modifiers",
\t\t}''')
    text = text.replace('''\treturn {
\t\t"stat_id": stat_id,
\t\t"label": humanize_id(stat_id),
\t\t"value": value,
\t\t"color_token": color_token,
\t}''', '''\treturn {
\t\t"stat_id": stat_id,
\t\t"label": humanize_id(stat_id),
\t\t"value": value,
\t\t"color_token": color_token,
\t\t"breakdown_text": "Effective stat • includes equipped parts and modifiers",
\t}''')
    # Better quest objective labels, stage index, and rewards metadata.
    replacement = r'''static func build_quest_card_view_model(quest_template: Dictionary, stage_index: int = 0, completed: bool = false) -> Dictionary:
	var quest_id := str(quest_template.get("quest_id", ""))
	var objectives: Array[Dictionary] = []
	var current_stage_text := "Completed" if completed else ""
	var stage_label := ""
	var stages_value: Variant = quest_template.get("stages", [])
	if stages_value is Array:
		var stages: Array = stages_value
		var resolved_stage_index := stage_index
		if completed and stages.size() > 0:
			resolved_stage_index = clampi(resolved_stage_index, 0, stages.size() - 1)
		if resolved_stage_index >= 0 and resolved_stage_index < stages.size():
			stage_label = "Stage %s of %s" % [str(resolved_stage_index + 1), str(stages.size())]
			var current_stage_value: Variant = stages[resolved_stage_index]
			if current_stage_value is Dictionary:
				var current_stage: Dictionary = current_stage_value
				var stage_title := str(current_stage.get("title", ""))
				var stage_description := str(current_stage.get("description", ""))
				if not completed:
					current_stage_text = stage_title if not stage_title.is_empty() else stage_description
				var objective_values: Variant = current_stage.get("objectives", [])
				if objective_values is Array:
					var raw_objectives: Array = objective_values
					for objective_value in raw_objectives:
						if not objective_value is Dictionary:
							continue
						var objective: Dictionary = objective_value
						var objective_label := _format_objective_label(objective)
						objectives.append({
							"label": objective_label,
							"satisfied": completed or ConditionEvaluator.evaluate(objective),
						})
	if objectives.is_empty() and completed:
		objectives.append({
			"label": "Quest complete.",
			"satisfied": true,
		})
	elif objectives.is_empty():
		objectives.append({
			"label": "Advance the current quest stage.",
			"satisfied": false,
		})
	return {
		"quest_id": quest_id,
		"display_name": str(quest_template.get("display_name", quest_template.get("title", humanize_id(quest_id)))),
		"current_stage": current_stage_text if not current_stage_text.is_empty() else ("Completed" if completed else stage_label),
		"stage_label": stage_label,
		"objectives": objectives,
		"rewards": _duplicate_dictionary(quest_template.get("reward", {})),
		"flavor_text": str(quest_template.get("description", "")),
	}
'''
    text = replace_func(text, "build_quest_card_view_model", replacement)
    helper = r'''static func _format_objective_label(objective: Dictionary) -> String:
	var explicit := str(objective.get("description", objective.get("label", ""))).strip_edges()
	if not explicit.is_empty():
		return explicit
	var objective_type := str(objective.get("type", "objective"))
	var target := str(objective.get("target", objective.get("target_id", objective.get("entity_id", objective.get("location_id", "")))))
	var amount_text := ""
	for amount_key in ["count", "amount", "required", "value"]:
		if objective.has(amount_key):
			amount_text = str(objective.get(amount_key))
			break
	var parts: Array[String] = [humanize_id(objective_type)]
	if not target.is_empty():
		parts.append(humanize_id(target))
	if not amount_text.is_empty():
		parts.append("x%s" % amount_text)
	return " ".join(parts)
'''
    text = insert_before(text, "static func _build_task_objective_label", helper)
    write_rel(path, text)


def patch_quest_card() -> None:
    path = "ui/components/quest_card.gd"
    text = read_rel(path)
    replacement = r'''func _format_stage_label(current_stage_value: Variant) -> String:
	var extra := ""
	if _pending_view_model.has("stage_label"):
		extra = str(_pending_view_model.get("stage_label", "")).strip_edges()
	if current_stage_value is Dictionary:
		var current_stage: Dictionary = current_stage_value
		var title := str(current_stage.get("title", current_stage.get("description", "")))
		if not title.is_empty():
			return "Current Stage: %s%s" % [title, " • %s" % extra if not extra.is_empty() else ""]
	if current_stage_value == null:
		return extra
	var current_stage_text := str(current_stage_value)
	if current_stage_text.is_empty():
		return extra
	return "Current Stage: %s%s" % [current_stage_text, " • %s" % extra if not extra.is_empty() else ""]
'''
    text = replace_func(text, "_format_stage_label", replacement)
    write_rel(path, text)


def patch_faction_badge_and_backend() -> None:
    path = "ui/components/faction_badge.gd"
    text = read_rel(path)
    text = text.replace('''\tvar accent_color := _resolve_color(view_model.get("color", null))''', '''\tvar accent_color := _resolve_color(view_model.get("color", view_model.get("color_token", null)))''')
    # Prefer tier color when a generic secondary color is supplied.
    helper = r'''func _tier_color_token(reputation_tier: String) -> String:
	match reputation_tier:
		"Allied":
			return "positive"
		"Friendly":
			return "primary"
		"Hostile":
			return "danger"
		"Unfriendly":
			return "warning"
		_:
			return "secondary"
'''
    text = insert_before(text, "func _apply_emblem", helper)
    text = text.replace('''\tvar accent_color := _resolve_color(view_model.get("color", view_model.get("color_token", null)))''', '''\tvar color_value: Variant = view_model.get("color", view_model.get("color_token", null))
	if color_value == null or str(color_value) == "secondary":
		color_value = _tier_color_token(reputation_tier)
	var accent_color := _resolve_color(color_value)''')
    write_rel(path, text)

    path = "ui/screens/backends/faction_reputation_backend.gd"
    text = read_rel(path)
    replacement = r'''func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var entity := BACKEND_HELPERS.resolve_entity_lookup(_get_string_param(_params, "target_entity_id", "player"))
	var faction_ids := _resolve_faction_ids(entity)
	for faction_id in faction_ids:
		var faction := DataManager.get_faction(faction_id)
		if faction.is_empty():
			continue
		var rep_value := 0.0 if entity == null else entity.get_reputation(faction_id)
		var badge := BACKEND_HELPERS.build_faction_badge_view_model(entity, faction_id)
		badge["color_token"] = _tier_color_token(str(badge.get("reputation_tier", "Neutral")))
		rows.append({
			"faction_id": faction_id,
			"display_name": str(faction.get("display_name", BACKEND_HELPERS.humanize_id(faction_id))),
			"description": str(faction.get("description", "")),
			"territory_summary": _build_territory_summary(faction),
			"standing_summary": _build_standing_summary(rep_value),
			"badge": badge,
		})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)
	return rows
'''
    text = replace_func(text, "_build_rows", replacement)
    helper = r'''func _build_standing_summary(value: float) -> String:
	var next_text := ""
	if value < -75.0:
		next_text = "%s to leave Hostile" % _format_reputation_number(-75.0 - value)
	elif value < -25.0:
		next_text = "%s to Neutral" % _format_reputation_number(-25.0 - value)
	elif value < 25.0:
		next_text = "%s to Friendly" % _format_reputation_number(25.0 - value)
	elif value < 75.0:
		next_text = "%s to Allied" % _format_reputation_number(75.0 - value)
	else:
		next_text = "Maximum tier reached"
	return "Standing: %s • %s" % [_format_reputation_number(value), next_text]


func _tier_color_token(tier: String) -> String:
	match tier:
		"Allied":
			return "positive"
		"Friendly":
			return "primary"
		"Hostile":
			return "danger"
		"Unfriendly":
			return "warning"
		_:
			return "secondary"


func _format_reputation_number(value: float) -> String:
	if absf(value - roundf(value)) < 0.001:
		return "%+d" % int(roundf(value))
	return "%+.1f" % value


'''
    text = insert_before(text, "func _build_territory_summary", helper)
    write_rel(path, text)


def patch_faction_screen() -> None:
    path = "ui/screens/backends/faction_reputation_screen.gd"
    text = read_rel(path)
    text = text.replace('''\tvar territory_summary := str(row.get("territory_summary", ""))
\tif not territory_summary.is_empty():
\t\tparts.append(territory_summary)''', '''\tvar standing_summary := str(row.get("standing_summary", ""))
\tif not standing_summary.is_empty():
\t\tparts.append(standing_summary)
\tvar territory_summary := str(row.get("territory_summary", ""))
\tif not territory_summary.is_empty():
\t\tparts.append(territory_summary)''')
    write_rel(path, text)


def patch_event_log_backend() -> None:
    path = "ui/screens/backends/event_log_backend.gd"
    text = read_rel(path)
    replacement = r'''func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var history := GameEvents.get_event_history(
		_read_limit(),
		_get_string_param(_params, "domain", ""),
		_get_string_param(_params, "signal_name", "")
	)
	for event_value in history:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var signal_name := str(event.get("signal_name", ""))
		rows.append({
			"sequence": int(event.get("sequence", 0)),
			"signal_name": signal_name,
			"domain": str(event.get("domain", "")),
			"timestamp": _format_timestamp(str(event.get("timestamp", ""))),
			"title": _build_event_title(signal_name, event.get("args", [])),
			"args_text": _format_args(event.get("args", [])),
			"narration_text": str(event.get("narration", "")),
			"deprecated": bool(event.get("deprecated", false)),
		})
	rows.append_array(_build_game_state_event_rows())
	if _get_bool_param(_params, "newest_first", true):
		rows.reverse()
	return rows
'''
    text = replace_func(text, "_build_rows", replacement)
    helper = r'''func _build_game_state_event_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if GameState == null:
		return rows
	var history: Array = GameState.event_history
	var limit := _read_limit()
	var start_index := 0 if limit <= 0 else maxi(history.size() - limit, 0)
	for index in range(start_index, history.size()):
		var event_value: Variant = history[index]
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var event_type := str(event.get("event_type", "runtime_event"))
		var payload: Dictionary = {}
		if event.get("payload", {}) is Dictionary:
			payload = (event.get("payload", {}) as Dictionary).duplicate(true)
		rows.append({
			"sequence": index + 1,
			"signal_name": event_type,
			"domain": "runtime",
			"timestamp": "Day %s • Tick %s" % [str(event.get("day", 1)), str(event.get("tick", 0))],
			"title": BACKEND_HELPERS.humanize_id(event_type) if BACKEND_HELPERS != null else event_type,
			"args_text": _format_arg_value(payload),
			"narration_text": str(payload.get("description", payload.get("message", ""))),
			"deprecated": false,
		})
	return rows


func _build_event_title(signal_name: String, args_value: Variant) -> String:
	var args: Array = []
	if args_value is Array:
		args = args_value
	match signal_name:
		"location_changed":
			return "Location changed: %s → %s" % [_arg_at(args, 0), _arg_at(args, 1)]
		"quest_started":
			return "Quest started: %s" % _arg_at(args, 0)
		"quest_stage_advanced":
			return "Quest advanced: %s stage %s" % [_arg_at(args, 0), _arg_at(args, 1)]
		"quest_completed":
			return "Quest completed: %s" % _arg_at(args, 0)
		"quest_failed":
			return "Quest failed: %s" % _arg_at(args, 0)
		"achievement_unlocked":
			return "Achievement unlocked: %s" % _arg_at(args, 0)
		"entity_reputation_changed":
			return "Reputation changed: %s / %s (%s → %s)" % [_arg_at(args, 0), _arg_at(args, 1), _arg_at(args, 2), _arg_at(args, 3)]
		"entity_currency_changed":
			return "Currency changed: %s %s (%s → %s)" % [_arg_at(args, 0), _arg_at(args, 1), _arg_at(args, 2), _arg_at(args, 3)]
		"part_acquired":
			return "Part acquired: %s" % _arg_at(args, 1)
		"part_equipped":
			return "Part equipped: %s → %s" % [_arg_at(args, 1), _arg_at(args, 2)]
		_:
			return signal_name.capitalize().replace("_", " ")


func _format_timestamp(timestamp: String) -> String:
	var trimmed := timestamp.strip_edges()
	if trimmed.is_empty():
		return ""
	return trimmed.replace("T", " ").replace("Z", " UTC")


func _arg_at(args: Array, index: int) -> String:
	if index < 0 or index >= args.size():
		return "?"
	return _format_arg_value(args[index])


'''
    if 'const BACKEND_HELPERS' not in text:
        text = text.replace('const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")\n', 'const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")\nconst BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")\n')
    text = insert_before(text, "func _format_args", helper)
    write_rel(path, text)


def patch_event_log_screen() -> None:
    path = "ui/screens/backends/event_log_screen.gd"
    text = read_rel(path)
    replacement = r'''func _build_row_text(row: Dictionary) -> String:
	var args_text := str(row.get("args_text", ""))
	var title := str(row.get("title", ""))
	if title.is_empty():
		title = "%s/%s" % [str(row.get("domain", "")), str(row.get("signal_name", ""))]
	var lines: Array[String] = [
		"#%s %s" % [str(row.get("sequence", 0)), title],
		"%s • %s/%s" % [str(row.get("timestamp", "")), str(row.get("domain", "")), str(row.get("signal_name", ""))],
	]
	if not args_text.is_empty() and args_text != "{}":
		lines.append(args_text)
	var narration_text := str(row.get("narration_text", "")).strip_edges()
	if not narration_text.is_empty():
		lines.append("Narration: %s" % narration_text)
	return "\n".join(lines)
'''
    text = replace_func(text, "_build_row_text", replacement)
    write_rel(path, text)


def patch_achievement_backend() -> None:
    path = "ui/screens/backends/achievement_list_backend.gd"
    text = read_rel(path)
    replacement = r'''func build_view_model() -> Dictionary:
	var rows := _build_rows()
	var empty_label := _get_string_param(_params, "empty_label", "No achievements are available.")
	var unlocked_count := 0
	for row in rows:
		if bool(row.get("unlocked", false)):
			unlocked_count += 1
	return {
		"title": _get_string_param(_params, "screen_title", "Achievements"),
		"description": _get_string_param(_params, "screen_description", "Review achievement unlocks and progress."),
		"rows": rows,
		"status_text": empty_label if rows.is_empty() else "%s unlocked / %s visible achievements." % [str(unlocked_count), str(rows.size())],
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"empty_label": empty_label,
	}
'''
    text = replace_func(text, "build_view_model", replacement)
    replacement2 = r'''func _build_progress_text(stat_name: String, progress: float, requirement: float, unlocked: bool) -> String:
	if unlocked:
		return "Unlocked"
	if stat_name.is_empty() or requirement <= 0.0:
		return "Locked — hidden trigger or manual unlock"
	var pct := clampf(progress / requirement, 0.0, 1.0) * 100.0
	return "%s: %s / %s (%s%%)" % [
		BACKEND_HELPERS.humanize_id(stat_name),
		_format_number(progress),
		_format_number(requirement),
		_format_number(pct),
	]
'''
    text = replace_func(text, "_build_progress_text", replacement2)
    write_rel(path, text)


def patch_game_state_events() -> None:
    path = "autoloads/game_state.gd"
    text = read_rel(path)
    # Record interesting runtime events at the source so the event log has meaningful player-facing rows.
    text = text.replace('''\tGameEvents.game_started.emit()''', '''\trecord_event("game_started", {"description": "New game started at %s." % current_location_id})
\tGameEvents.game_started.emit()''')
    text = text.replace('''\tGameEvents.location_changed.emit(old_id, current_location_id)''', '''\trecord_event("location_changed", {"from": old_id, "to": current_location_id, "description": "Travelled from %s to %s." % [old_id, current_location_id]})
\tGameEvents.location_changed.emit(old_id, current_location_id)''')
    text = text.replace('''\tGameEvents.achievement_unlocked.emit(achievement_id, unlock_vfx)''', '''\trecord_event("achievement_unlocked", {"achievement_id": achievement_id, "description": "Achievement unlocked: %s" % achievement_id})
\tGameEvents.achievement_unlocked.emit(achievement_id, unlock_vfx)''')
    text = text.replace('''\tGameEvents.emit_dynamic("faction_reputation_changed", [faction_id, value])''', '''\trecord_event("faction_reputation_changed", {"faction_id": faction_id, "value": value, "description": "Faction reputation changed: %s %+0.1f" % [faction_id, value]})
\tGameEvents.emit_dynamic("faction_reputation_changed", [faction_id, value])''')
    write_rel(path, text)


def main() -> int:
    patches = [
        patch_stat_bar,
        patch_backend_helpers,
        patch_quest_card,
        patch_faction_badge_and_backend,
        patch_faction_screen,
        patch_event_log_backend,
        patch_event_log_screen,
        patch_achievement_backend,
        patch_game_state_events,
    ]
    for patch in patches:
        patch()
        print(f"applied {patch.__name__}")
    print("Phase 5 polish patch applied. Backups use .phase5.bak suffix.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
