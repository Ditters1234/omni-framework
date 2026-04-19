extends GutTest

const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")


func test_runtime_screen_registry_paths_exist_for_every_engine_owned_screen() -> void:
	var runtime_registry := UI_ROUTE_CATALOG.get_runtime_screen_registry()

	assert_eq(
		str(runtime_registry.get(UI_ROUTE_CATALOG.SCREEN_CHARACTER_CREATOR, "")),
		UI_ROUTE_CATALOG.ASSEMBLY_EDITOR_SCENE
	)

	for screen_id_value in runtime_registry.keys():
		var screen_id := str(screen_id_value)
		var scene_path := str(runtime_registry.get(screen_id_value, ""))
		assert_true(UI_ROUTE_CATALOG.has_known_screen_id(screen_id))
		assert_false(scene_path.is_empty())
		assert_true(ResourceLoader.exists(scene_path))


func test_backend_screen_ids_map_to_known_routes() -> void:
	var backend_classes := [
		"AssemblyEditorBackend",
		"ExchangeBackend",
		"ListBackend",
		"ChallengeBackend",
		"TaskProviderBackend",
		"CatalogListBackend",
		"DialogueBackend",
		"EntitySheetBackend",
	]

	for backend_class in backend_classes:
		assert_true(UI_ROUTE_CATALOG.has_backend_class(backend_class))
		var screen_id := UI_ROUTE_CATALOG.get_screen_id_for_backend(backend_class)
		assert_true(UI_ROUTE_CATALOG.has_known_screen_id(screen_id))
