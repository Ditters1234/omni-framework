extends "res://ui/screens/backends/backend_base.gd"

class_name OmniAchievementListBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

var _params: Dictionary = {}


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("AchievementListBackend", {
		"required": [],
		"optional": [
			"screen_title",
			"screen_description",
			"cancel_label",
			"empty_label",
			"show_locked",
			"show_unlocked",
		],
		"field_types": {
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"show_locked": TYPE_BOOL,
			"show_unlocked": TYPE_BOOL,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


func build_view_model() -> Dictionary:
	var rows := _build_rows()
	var empty_label := _get_string_param(_params, "empty_label", "No achievements are available.")
	return {
		"title": _get_string_param(_params, "screen_title", "Achievements"),
		"description": _get_string_param(_params, "screen_description", "Review achievement unlocks and progress."),
		"rows": rows,
		"status_text": empty_label if rows.is_empty() else "%s achievements listed." % str(rows.size()),
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"empty_label": empty_label,
	}


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var show_locked := _get_bool_param(_params, "show_locked", true)
	var show_unlocked := _get_bool_param(_params, "show_unlocked", true)
	if not AchievementRegistry:
		return rows
	var achievements_value: Variant = AchievementRegistry.get_all()
	if not achievements_value is Array:
		return rows
	var achievements: Array = achievements_value
	for achievement_value in achievements:
		if not achievement_value is Dictionary:
			continue
		var achievement: Dictionary = achievement_value
		var achievement_id := str(achievement.get("achievement_id", ""))
		if achievement_id.is_empty():
			continue
		var unlocked := achievement_id in GameState.unlocked_achievements
		if unlocked and not show_unlocked:
			continue
		if not unlocked and not show_locked:
			continue
		rows.append(_build_row(achievement, achievement_id, unlocked))
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		var a_unlocked := bool(a.get("unlocked", false))
		var b_unlocked := bool(b.get("unlocked", false))
		if a_unlocked != b_unlocked:
			return a_unlocked and not b_unlocked
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)
	return rows


func _build_row(achievement: Dictionary, achievement_id: String, unlocked: bool) -> Dictionary:
	var stat_name := str(achievement.get("stat_name", ""))
	var requirement := _read_float(achievement.get("requirement", 0.0))
	var progress := 0.0
	var source_type := "static"
	if not stat_name.is_empty():
		progress = _read_float(GameState.achievement_stats.get(stat_name, 0.0))
		source_type = "stat_threshold"
	return {
		"achievement_id": achievement_id,
		"display_name": str(achievement.get("display_name", achievement.get("title", BACKEND_HELPERS.humanize_id(achievement_id)))),
		"description": str(achievement.get("description", "")),
		"unlocked": unlocked,
		"status": "Unlocked" if unlocked else "Locked",
		"source_type": source_type,
		"stat_name": stat_name,
		"progress": progress,
		"requirement": requirement,
		"progress_text": _build_progress_text(stat_name, progress, requirement, unlocked),
	}


func _build_progress_text(stat_name: String, progress: float, requirement: float, unlocked: bool) -> String:
	if unlocked:
		return "Unlocked"
	if stat_name.is_empty() or requirement <= 0.0:
		return "Locked"
	return "%s: %s / %s" % [
		BACKEND_HELPERS.humanize_id(stat_name),
		_format_number(progress),
		_format_number(requirement),
	]


func _read_float(value: Variant) -> float:
	if value is int or value is float:
		return float(value)
	return 0.0


func _format_number(amount: float) -> String:
	if absf(amount - roundf(amount)) < 0.001:
		return str(int(roundf(amount)))
	return "%.2f" % amount
