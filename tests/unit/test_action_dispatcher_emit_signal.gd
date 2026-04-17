extends GutTest


func test_emit_signal_forwards_args_positionally() -> void:
	watch_signals(GameEvents)

	ActionDispatcher.dispatch({
		"type": "emit_signal",
		"signal_name": "notification_requested",
		"args": ["Hello world", OmniConstants.NOTIFICATION_LEVEL_WARN]
	})

	assert_signal_emitted(GameEvents, "notification_requested")
	assert_eq(
		get_signal_parameters(GameEvents, "notification_requested"),
		["Hello world", OmniConstants.NOTIFICATION_LEVEL_WARN]
	)
