## ConditionEvaluator — Evaluates JSON condition blocks against game state.
## Used by quests, tasks, challenges, and shop unlock requirements.
##
## Condition block format (all fields optional, ANDed together):
## {
##   "stat_check": { "stat": "strength", "op": ">=", "value": 10 },
##   "has_flag": "completed_tutorial",
##   "has_part": "base:lockpick",
##   "has_currency": { "key": "gold", "amount": 50 },
##   "quest_complete": "base:the_first_hunt",
##   "location": "base:town_square"
## }
extends RefCounted

class_name ConditionEvaluator


## Evaluates a condition dictionary against the current GameState.
## Returns true only if ALL conditions in the block are satisfied.
static func evaluate(conditions: Dictionary) -> bool:
	if conditions.is_empty():
		return true

	if conditions.has("stat_check"):
		if not _check_stat(conditions["stat_check"]):
			return false

	if conditions.has("has_flag"):
		if not GameState.has_flag(str(conditions["has_flag"])):
			return false

	if conditions.has("has_part"):
		if not _check_has_part(str(conditions["has_part"])):
			return false

	if conditions.has("has_currency"):
		if not _check_currency(conditions["has_currency"]):
			return false

	if conditions.has("quest_complete"):
		if not str(conditions["quest_complete"]) in GameState.completed_quests:
			return false

	if conditions.has("location"):
		if GameState.current_location_id != str(conditions["location"]):
			return false

	return true


## Evaluates an array of condition blocks (OR logic — any one passing = true).
static func evaluate_any(condition_list: Array) -> bool:
	for cond in condition_list:
		if evaluate(cond):
			return true
	return false


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _check_stat(stat_check: Dictionary) -> bool:
	var player: EntityInstance = GameState.player
	if player == null:
		return false
	var stat_key := str(stat_check.get("stat", ""))
	var op := str(stat_check.get("op", ">="))
	var required := float(stat_check.get("value", 0))
	var actual: float = player.effective_stat(stat_key)
	match op:
		">=": return actual >= required
		">":  return actual > required
		"<=": return actual <= required
		"<":  return actual < required
		"==": return actual == required
		"!=": return actual != required
	return false


static func _check_has_part(part_id: String) -> bool:
	var player: EntityInstance = GameState.player
	if player == null:
		return false
	for part: PartInstance in player.inventory:
		if part.template_id == part_id:
			return true
	return false


static func _check_currency(currency_check: Dictionary) -> bool:
	var key := str(currency_check.get("key", ""))
	var amount := float(currency_check.get("amount", 0))
	return GameState.has_currency(key, amount)
