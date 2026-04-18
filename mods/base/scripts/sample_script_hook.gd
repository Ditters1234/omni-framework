extends ScriptHook


## Minimal base-mod hook used as a reference fixture for modders and tests.
func on_location_enter(location_template: Dictionary) -> void:
	var location_id := str(location_template.get("location_id", ""))
	if location_id.is_empty():
		return
	GameState.set_flag("base_sample_hook_last_location", location_id)
