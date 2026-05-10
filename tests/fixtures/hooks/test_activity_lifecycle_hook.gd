extends ScriptHook

const BUCKET := "test_activity_hooks"


func on_activity_start(activity: Dictionary, context: Dictionary) -> void:
	GameState.set_runtime_state(BUCKET, "started_activity_id", str(activity.get("activity_id", "")))
	GameState.set_runtime_state(BUCKET, "start_context_entity_id", str(context.get("entity_id", "")))


func on_activity_complete(activity: Dictionary, result: Dictionary) -> void:
	GameState.set_runtime_state(BUCKET, "completed_activity_id", str(activity.get("activity_id", "")))
	GameState.set_runtime_state(BUCKET, "completion_result_success", bool(result.get("success", false)))


func on_activity_fail(activity: Dictionary, result: Dictionary) -> void:
	GameState.set_runtime_state(BUCKET, "failed_activity_id", str(activity.get("activity_id", "")))
	GameState.set_runtime_state(BUCKET, "failure_code", str(result.get("failure_code", "")))
