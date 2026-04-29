extends GutTest

const DEV_DEBUG_OVERLAY := preload("res://ui/debug/dev_debug_overlay.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

var _overlay: CanvasLayer = null


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture()
	_overlay = DEV_DEBUG_OVERLAY.new()
	get_tree().root.add_child(_overlay)
	await get_tree().process_frame


func after_each() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	await get_tree().process_frame


func test_overlay_exposes_filters_and_refresh_state() -> void:
	assert_not_null(_overlay)
	if _overlay == null:
		return

	_overlay.call("_set_overlay_visible", true)
	_overlay.call("_refresh_all_tabs")
	var snapshot_value: Variant = _overlay.call("get_debug_snapshot")
	assert_true(snapshot_value is Dictionary)
	var snapshot: Dictionary = snapshot_value
	assert_true(bool(snapshot.get("visible", false)))
	assert_true(bool(snapshot.get("auto_refresh_enabled", false)))
	assert_eq(str(snapshot.get("event_domain_filter", "")), "")
	assert_eq(str(snapshot.get("event_search", "")), "")
	assert_eq(str(snapshot.get("entity_search", "")), "")
	assert_gt(int(snapshot.get("last_refreshed_msec", 0)), 0)


func test_overlay_filters_can_be_changed_without_runtime_errors() -> void:
	assert_not_null(_overlay)
	if _overlay == null:
		return

	_overlay.call("_set_overlay_visible", true)
	var event_search := _overlay.find_child("EventSearchField", true, false) as LineEdit
	var entity_search := _overlay.find_child("EntitySearchField", true, false) as LineEdit
	var domain_filter := _overlay.find_child("EventDomainFilter", true, false) as OptionButton
	assert_not_null(event_search)
	assert_not_null(entity_search)
	assert_not_null(domain_filter)
	if event_search == null or entity_search == null or domain_filter == null:
		return

	event_search.text = "tick"
	entity_search.text = "player"
	domain_filter.select(4)
	_overlay.call("_refresh_all_tabs")

	var snapshot_value: Variant = _overlay.call("get_debug_snapshot")
	assert_true(snapshot_value is Dictionary)
	var snapshot: Dictionary = snapshot_value
	assert_eq(str(snapshot.get("event_domain_filter", "")), "time")
	assert_eq(str(snapshot.get("event_search", "")), "tick")
	assert_eq(str(snapshot.get("entity_search", "")), "player")
