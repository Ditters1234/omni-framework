extends GutTest

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")


func before_each() -> void:
	BACKEND_CONTRACT_REGISTRY.clear()


func test_validate_payload_reports_missing_required_fields_and_bad_types() -> void:
	BACKEND_CONTRACT_REGISTRY.register("TestBackend", {
		"required": ["target_id"],
		"field_types": {
			"target_id": TYPE_STRING,
			"flags": TYPE_ARRAY,
		},
		"array_element_types": {
			"flags": TYPE_STRING,
		},
	})

	var issues := BACKEND_CONTRACT_REGISTRY.validate_payload("TestBackend", {
		"target_id": 7,
		"flags": ["ok", 1],
	}, "screens[0]")

	assert_eq(issues.size(), 2)
	assert_true(_issues_contain(issues, "screens[0].target_id"))
	assert_true(_issues_contain(issues, "screens[0].flags[1]"))


func test_validate_payload_rejects_unknown_backend_class() -> void:
	var issues := BACKEND_CONTRACT_REGISTRY.validate_payload("MissingBackend", {}, "screens[1]")

	assert_eq(issues.size(), 1)
	assert_true(_issues_contain(issues, "Unknown backend_class 'MissingBackend'"))


func _issues_contain(issues: Array[Dictionary], expected_fragment: String) -> bool:
	for issue in issues:
		if str(issue.get("message", "")).contains(expected_fragment) or str(issue.get("field_path", "")).contains(expected_fragment):
			return true
	return false
