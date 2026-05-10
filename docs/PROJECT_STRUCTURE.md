# Omni-Framework — Project Structure

This document is a **current-structure reference** for the repository. It is intentionally grounded in the visible repository layout and implemented behavior.

## What the Repository Clearly Contains

At the top level, the repo currently includes:

```text
res://
├── addons/
├── autoloads/
├── core/
├── docs/
├── mods/
├── systems/
├── tests/
└── ui/
```

Additional root-level project files currently include `project.godot`, `.gutconfig.json`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `icon.svg`, and `default_bus_layout.tres`. Editor/runtime cache folders such as `.godot/` may appear locally but are not source structure. Ad hoc debug, probe, temp, or backup files should not live at `res://`; convert useful checks into GUT tests under `tests/`, or keep throwaway local scripts outside the project tree.

## Autoloads

The `autoloads/` folder currently contains these manager scripts:

```text
autoloads/
├── ai_manager.gd
├── audio_manager.gd
├── data_manager.gd
├── game_events.gd
├── game_state.gd
├── mod_loader.gd
├── save_manager.gd
├── time_keeper.gd
└── ui_router.gd
```

`project.godot` also declares addon-provided autoloads (`DialogueManager` and `ImGuiRoot`) and the system-level autoload `TaskRoutineRunner` (from `systems/task_routine_runner.gd`). The list above is the engine-owned `autoloads/` script folder specifically, not the full autoload table from the project settings.

### Autoload Contracts

- **`UIRouter`** — Requires a `CanvasLayer` container. `UIRouter.initialize()` will error if passed anything other than a `CanvasLayer`. Do not describe this as a generic screen container.
- **`GameState`** — `new_game()` requires `game.starting_player_id` to be explicitly set in config. There is no runtime fallback to `base:player`; missing or empty config causes boot to abort with a warning.
- **`GameState`** — Stores `activity_history` as saved runtime state. Activity history records starts, completions, completion counts by display day, and the last activity outcome by `activity_id`.
- **`SaveManager`** — Uses save schema v2 and currently registers `EntityInstance` and `PartInstance` with A2J. Any new first-class runtime object that participates in save/load must also be registered here.

### What this implies

The project is organized around a classic Godot singleton model with dedicated autoloads for:

- AI provider routing
- audio playback
- template/data access
- event dispatch
- mutable runtime state
- mod discovery/loading
- persistence
- time progression
- screen routing/navigation

## Systems

The `systems/` folder currently contains both direct service scripts and subfolders:

Notable current contents:
- `systems/ai/ai_chat_service.gd`, `bt_action_ai_query.gd`, `bt_condition_ai_check.gd`, and `bt_ai_utils.gd`, plus the provider scripts under `systems/ai/providers/`
- `systems/loaders/ai_persona_registry.gd` and `ai_template_registry.gd` alongside the rest of the JSON registries

```text
systems/
|-- ai/
|   |-- providers/
|   |   |-- anthropic_provider.gd
|   |   |-- nobodywho_provider.gd
|   |   `-- openai_provider.gd
|   |-- ai_chat_service.gd
|   |-- bt_action_ai_query.gd
|   |-- bt_ai_utils.gd
|   `-- bt_condition_ai_check.gd
|-- loaders/
|   |-- achievement_registry.gd
|   |-- activity_registry.gd
|   |-- ai_persona_registry.gd
|   |-- ai_template_registry.gd
|   |-- config_loader.gd
|   |-- definition_loader.gd
|   |-- encounter_registry.gd
|   |-- entity_registry.gd
|   |-- faction_registry.gd
|   |-- location_graph.gd
|   |-- parts_registry.gd
|   |-- quest_registry.gd
|   |-- recipe_registry.gd
|   |-- status_effect_registry.gd
|   `-- task_registry.gd
|-- action_dispatcher.gd
|-- assembly_commit_service.gd
|-- activity_service.gd
|-- activity_schedule_service.gd
|-- backend_contract_registry.gd
|-- condition_evaluator.gd
|-- encounter_runtime.gd
|-- entity_lifecycle_runner.gd
|-- location_access_service.gd
|-- location_presence_service.gd
|-- quest_tracker.gd
|-- reward_service.gd
|-- script_hook_loader.gd
|-- script_hook_service.gd
|-- stat_manager.gd
|-- status_effect_runner.gd
|-- task_activity_summary.gd
|-- task_routine_runner.gd
|-- task_runner.gd
|-- time_model.gd
|-- transaction_service.gd
`-- weighted_choice_service.gd
```

The loader scripts above load JSON templates into `DataManager`, including `activities.json`, `ai_personas.json`, `ai_templates.json`, `encounters.json`, and `status_effects.json`.
`systems/encounter_runtime.gd` provides encounter condition context, weighted opponent action selection, encounter-local stat clamping, and JSON-native effect delta math.
`systems/status_effect_runner.gd` advances data-authored timed status effects stored in `GameState.active_status_effects`, applying stat modifiers and evaluating optional apply/tick/expire conditions before dispatching lifecycle actions.
`systems/entity_lifecycle_runner.gd` evaluates config-authored lifecycle rules for live entities, setting state flags and dispatching normal actions when authored conditions enter or exit.
`systems/location_presence_service.gd` resolves gameplay location presence rows and empty-loot visibility from location templates, entity templates, and runtime entity instances, keeping that model assembly out of the shell surface UI.
`systems/task_activity_summary.gd` formats active and queued task instances into shared entity activity summaries for owned-entity management and gameplay location presence rows.
`systems/time_model.gd` is a stateless helper for interpreting configured game time, weekdays, months, display dates, and formatted time strings. It reads `GameState.current_tick` and `calendar.*` config but never advances time.
`systems/activity_schedule_service.gd` is a stateless helper for evaluating activity schedule rules and expanding deterministic upcoming slots. It reads activity templates and `TimeModel` projections but never executes activities or mutates runtime state.
`systems/activity_service.gd` coordinates data-authored activity availability, board rows, execution, repeat/cooldown checks, location policy, lifecycle events, history writes, action dispatch, time advancement, and script hooks. It delegates gameplay mutation to existing runtime services.
`systems/weighted_choice_service.gd` filters condition-gated weighted entries and picks one using `RandomNumberGenerator`; activity outcomes use it for completion branches.
`systems/ai/` includes `ai_chat_service.gd`, a non-autoload helper that assembles persona-aware prompts, keeps bounded conversation history, and validates AI replies for dialogue UI.
`systems/ai/` includes `bt_action_ai_query.gd` and `bt_condition_ai_check.gd`, two LimboAI custom tasks for AI-driven behavior-tree decisions, plus `bt_ai_utils.gd`, the shared prompt-token and response-parser helper those tasks use.
`script_hook_service.gd` owns the world-generation hook bridge: it resolves config-declared global AI hook paths, caches generated task flavor text, and dispatches event narration requests after quest, travel, and day-advance events are recorded.

## UI

The `ui/` folder currently contains:

```text
ui/
├── components/
│   ├── assembly_slot_row.gd / .tscn
│   ├── currency_display.gd / .tscn
│   ├── currency_summary_panel.gd / .tscn
│   ├── entity_portrait.gd / .tscn
│   ├── faction_badge.gd / .tscn
│   ├── notification_popup.gd / .tscn
│   ├── part_card.gd / .tscn
│   ├── part_detail_panel.gd / .tscn
│   ├── quest_card.gd / .tscn
│   ├── recipe_card.gd / .tscn
│   ├── stat_bar.gd / .tscn
│   ├── stat_delta_sheet.gd / .tscn
│   ├── stat_sheet.gd / .tscn
│   └── tab_panel.gd / .tscn
├── debug/
│   └── dev_debug_overlay.gd
├── screens/
│   ├── backends/
│   │   ├── achievement_list_backend.gd
│   │   ├── achievement_list_screen.gd / .tscn
│   │   ├── active_quest_log_backend.gd
│   │   ├── active_quest_log_screen.gd / .tscn
│   │   ├── assembly_editor_backend.gd
│   │   ├── assembly_editor_config.gd
│   │   ├── assembly_editor_option_provider.gd
│   │   ├── assembly_editor_screen.gd / .tscn
│   │   ├── backend_base.gd
│   │   ├── backend_helpers.gd
│   │   ├── backend_navigation_helper.gd
│   │   ├── catalog_list_backend.gd
│   │   ├── catalog_list_screen.gd / .tscn
│   │   ├── challenge_backend.gd
│   │   ├── challenge_screen.gd / .tscn
│   │   ├── crafting_backend.gd
│   │   ├── crafting_screen.gd / .tscn
│   │   ├── dialogue_backend.gd
│   │   ├── dialogue_screen.gd / .tscn
│   │   ├── encounter_backend.gd
│   │   ├── encounter_screen.gd / .tscn
│   │   ├── entity_sheet_backend.gd
│   │   ├── entity_sheet_screen.gd / .tscn
│   │   ├── loot_backend.gd
│   │   ├── loot_screen.gd / .tscn
│   │   ├── owned_entities_backend.gd
│   │   ├── owned_entities_screen.gd / .tscn
│   │   ├── event_log_backend.gd
│   │   ├── event_log_screen.gd / .tscn
│   │   ├── exchange_backend.gd
│   │   ├── exchange_screen.gd / .tscn
│   │   ├── faction_reputation_backend.gd
│   │   ├── faction_reputation_screen.gd / .tscn
│   │   ├── list_backend.gd
│   │   ├── list_screen.gd / .tscn
│   │   ├── task_provider_backend.gd
│   │   └── task_provider_screen.gd / .tscn
│   ├── credits/
│   ├── gameplay_shell/
│   │   ├── gameplay_location_action_service.gd
│   │   ├── gameplay_location_surface.gd / .tscn
│   │   ├── gameplay_shell_presenter.gd
│   │   └── gameplay_shell_screen.gd / .tscn
│   ├── main_menu/
│   ├── pause_menu/
│   ├── save_slot_list/
│   └── settings/
├── theme/
│   ├── omni_theme.tres
│   └── theme_applier.gd
├── main.gd
├── main.tscn
└── ui_route_catalog.gd
```

### What this implies

The UI layer includes:

- A root entry scene at `ui/main.tscn` and accompanying controller (`main.gd`)
- A route catalog (`ui_route_catalog.gd`) — the shared catalog for `backend_class → screen_id` mapping and the runtime `screen_id → scene_path` registry
- **18 backend-driven screens:** `AssemblyEditorBackend`, `ExchangeBackend`, `ListBackend`, `ChallengeBackend`, `TaskProviderBackend`, `CatalogListBackend`, `CraftingBackend`, `DialogueBackend`, `EncounterBackend`, `EntitySheetBackend`, `OwnedEntitiesBackend`, `LootBackend`, `RewardReviewBackend`, `ActiveQuestLogBackend`, `FactionReputationBackend`, `AchievementListBackend`, `EventLogBackend`, `WorldMapBackend`
- `DialogueBackend` supports authored `.dialogue` trees plus optional `ai_mode` handoff (`hybrid` / `freeform`) using `systems/ai/ai_chat_service.gd` and `GameEvents.ai_token_received`
- `EncounterBackend` runs data-authored, turn-based encounters from `encounters.json`, using real entity stat mutations plus encounter-local meters, outcome rewards/actions, and optional presentation-only AI flavor for action log entries.
- `EntitySheetBackend` powers the character menu, including stats, active status effects, equipment, quests, reputation, progress, activity, a searchable/filterable inventory browser, data-authored usable inventory items, direct equip from data-derived socket/tag compatibility, discard actions for loose inventory, per-instance favorite/lock controls, and equipment handoff. Character-menu screens stay presentation-only; inventory use/equip/discard/flag operations are mediated by the backend so gameplay mutation remains scoped to backend/helper systems.
- `OwnedEntitiesBackend` powers owner/companion management: it lists validated `owned_entity_ids`, supports generic roster search/filter/sort controls with data-configured stat previews, shows current location and shared activity summaries for active/queued work, can reorder/cancel the selected entity's runtime task queue, can send an entity to a known location through a `TRAVEL` task, can recall it to the owner, and can hand off to entity inspection, equipment management, or contract assignment. Contract assignment can accept a quest and auto-dispatch the owned entity through assignee reach-location objectives as the quest advances. Owned entity task completion surfaces a UI notification for the player owner.
- `LootBackend` powers entity-backed loot/container review. Containers, caches, and loot piles remain normal entities with inventory and currency balances; the backend transfers selected loose part instances or all available contents to a destination entity, closes by default when depleted, and gameplay location surfaces hide empty loot entries unless data opts out.
- `RewardReviewBackend` powers reward history review from `GameState.event_history`, showing quest and encounter completion reward summaries without coupling the UI to a specific reward schema.
- Rest/recovery loops use existing entities, tasks, actions, status effects, and location/entity interactions rather than a separate world-object layer. Data-authored time buttons can start task templates before advancing time, task completion actions can apply recovery, repair, charging, fatigue removal, or other effects through `ActionDispatcher`, and location screens can expose clinic/repair/rest affordances through normal backend payloads.
- Gameplay location presence is resolved by `LocationPresenceService`; the shell-owned surface renders the resulting rows and buttons rather than querying runtime entity state directly.
- Gameplay location actions route through `gameplay_location_action_service.gd`; the surface delegates shell opens and travel mutation to that service instead of calling `UIRouter` or `GameState.travel_to()` directly.
- Backend-screen navigation is centralized in `backend_navigation_helper.gd`. Backend screens should route `push`, `replace_all`, `pop`, gameplay-shell surface opens/closes, and backend action dispatch through that helper rather than calling `UIRouter` directly.
- `ui/screens/backends/` also includes the world map implementation trio: `world_map_backend.gd`, `world_map_graph.gd`, and `world_map_screen.gd`
- Dialogue, encounter, world map, and settings screens use responsive container layouts so backend-driven screens remain usable in narrow/mobile-sized viewports.
- A full shared component library: all components listed under `ui/components/` are implemented with `render(view_model: Dictionary)` contracts
- Debug overlay at `ui/debug/dev_debug_overlay.gd`
- Theme system: `omni_theme.tres` + `theme_applier.gd`

### Current Scope Boundaries

These are intentional current constraints, not missing foundation work:

- **World objects** are represented as normal entities. Containers, terminals, doors, harvest nodes, loot piles, switches, and traps use the entity + interaction/backend/action model.
- **Inventory stack splitting** is not a runtime feature. Current inventory uses distinct `PartInstance` objects grouped for display.
- **Owned-entity bulk operations and priority presets** are not implemented. Current queue controls cover single-entity assignment, reorder, recall, and cancellation without fixed job categories.
- **Save repair flows** are not implemented. Current diagnostics are intentionally explicit about why a slot cannot load.
- **AI chat history** is session-scoped. Persisting freeform conversation history would require a first-class save schema and A2J registration.

## Core

`core/` contains shared runtime classes separated from autoloads and systems:

```text
core/
├── app_settings.gd
├── assembly_session.gd
├── constants.gd
├── entity_instance.gd
├── part_instance.gd
└── script_hook.gd
```

## Mods

`mods/` contains all game content. `mods/base/` is required for boot. The base mod:

- must use `"id": "base"` in `mod.json`
- must use `"load_order": 0`
- must NOT declare `"dependencies"` — the loader treats this as a fatal error
- lives directly at `mods/base/`, not under an author subfolder

User/community mods live under `mods/<author_id>/<mod_id>/`.

## Tests

`tests/` contains GUT-based test coverage, organized into `unit/`, `integration/`, and `content/` subfolders. `.gutconfig.json` at the project root controls headless test runner discovery.

Engine-owned tests should prefer stable fixture data from `tests/helpers/test_fixture_world.gd` instead of asserting against `mods/base/` content directly. Reserve `tests/content/` for checks that intentionally validate the shipped base mod data and assets.

Tests are dev-only and must be excluded from release export presets.

## Documentation Guidance

Docs in this repo should be current references focused on implemented behavior and visible repository structure.

- Prefer observed repository structure over intent statements
- Describe non-goals as current constraints, not planned features
- Avoid describing absent folders/files as if they already exist
- Include service files that are present in the repo
