extends ScriptHook


func on_tick(_entity: Dictionary, _instance: Dictionary, tick: int) -> void:
	var current_count := int(GameState.get_flag("test_tick_hook_call_count", 0))
	GameState.set_flag("test_tick_hook_call_count", current_count + 1)
	GameState.set_flag("test_tick_hook_last_tick", tick)
