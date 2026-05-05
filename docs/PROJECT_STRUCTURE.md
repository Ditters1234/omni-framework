# Omni-Framework — Project Structure

This document is a **current-structure reference** for the repository. It is intentionally grounded in the visible repository layout rather than mixing present implementation with future-state planning.

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

Additional root-level project files currently include `project.godot`, `.gutconfig.json`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `icon.svg`, and `default_bus_layout.tres`. The tracked `.tmp_empty_project/` folder is a dev-only scratch Godot project, not part of the runtime architecture. Editor/runtime cache folders such as `.godot/` may also appear locally but are not source structure. Ad hoc debug or probe scripts should not live at `res://`; convert useful checks into GUT tests under `tests/`, or keep throwaway local scripts outside the project tree.

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
- **`SaveManager`** — Currently registers `EntityInstance` and `PartInstance` with A2J. Any new first-class runtime object that participates in save/load must also be registered here.

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
├── ai/
│   └── providers/
│       ├── anthropic_provider.gd
│       ├── nobodywho_provider.gd
│       └── openai_provider.gd
├── loaders/
│   ├── achievement_registry.gd
│   ├── config_loader.gd
│   ├── definition_loader.gd
│   ├── encounter_registry.gd
│   ├── entity_registry.gd
│   ├── faction_registry.gd
│   ├── location_graph.gd
│   ├── parts_registry.gd
│   ├── quest_registry.gd
│   ├── recipe_registry.gd
│   └── task_registry.gd
├── action_dispatcher.gd
├── assembly_commit_service.gd
├── backend_contract_registry.gd
├── condition_evaluator.gd
├── encounter_runtime.gd
├── location_access_service.gd
├── quest_tracker.gd
├── reward_service.gd
├── script_hook_loader.gd
├── script_hook_service.gd
├── stat_manager.gd
├── task_routine_runner.gd
├── task_runner.gd
└── transaction_service.gd
```

`systems/loaders/` also includes `ai_persona_registry.gd`, `ai_template_registry.gd`, and `encounter_registry.gd`, which load `ai_personas.json`, `ai_templates.json`, and `encounters.json` into `DataManager`.
`systems/encounter_runtime.gd` provides encounter condition context, weighted opponent action selection, encounter-local stat clamping, and JSON-native effect delta math.
`systems/ai/` now also includes `ai_chat_service.gd`, a non-autoload helper that assembles persona-aware prompts, keeps bounded conversation history, and validates AI replies ahead of the dialogue-layer UI work.
`systems/ai/` also now includes `bt_action_ai_query.gd` and `bt_condition_ai_check.gd`, two LimboAI custom tasks for AI-driven behavior-tree decisions, plus `bt_ai_utils.gd`, the shared prompt-token and response-parser helper those tasks use.
`script_hook_service.gd` now also owns the Phase 6 world-generation bridge: it resolves config-declared global AI hook paths, caches generated task flavor text, and dispatches event narration requests after quest, travel, and day-advance events are recorded.

All of the following service scripts are fully implemented and should not be omitted from any architecture reference:

- `assembly_commit_service.gd`
- `backend_contract_registry.gd`
- `location_access_service.gd`
- `reward_service.gd`
- `script_hook_service.gd`
- `task_routine_runner.gd`
- `transaction_service.gd`

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
- **16 backend-driven screens** (Phase 4 + Phase 5 complete, Phase 6 crafting complete, Phase 7 world map initial pass, encounter v1 complete, owned-entity assignment initial pass): `AssemblyEditorBackend`, `ExchangeBackend`, `ListBackend`, `ChallengeBackend`, `TaskProviderBackend`, `CatalogListBackend`, `CraftingBackend`, `DialogueBackend`, `EncounterBackend`, `EntitySheetBackend`, `OwnedEntitiesBackend`, `ActiveQuestLogBackend`, `FactionReputationBackend`, `AchievementListBackend`, `EventLogBackend`, `WorldMapBackend`
- `DialogueBackend` now supports authored `.dialogue` trees plus optional `ai_mode` handoff (`hybrid` / `freeform`) using `systems/ai/ai_chat_service.gd` and `GameEvents.ai_token_received`
- `EncounterBackend` runs data-authored, turn-based encounters from `encounters.json`, using real entity stat mutations plus encounter-local meters, outcome rewards/actions, and optional presentation-only AI flavor for action log entries.
- `EntitySheetBackend` powers the character menu, including stats, equipment, quests, reputation, progress, activity, a searchable/filterable inventory browser, data-authored usable inventory items, discard actions for loose inventory, and equipment handoff.
- `OwnedEntitiesBackend` powers owner/companion management: it lists `owned_entity_ids`, shows current location and active task state, can send an entity to a known location through a `TRAVEL` task, can recall it to the owner, and can hand off to entity inspection, equipment management, or contract assignment.
- `ui/screens/backends/` also includes the world map implementation trio: `world_map_backend.gd`, `world_map_graph.gd`, and `world_map_screen.gd`
- Dialogue, encounter, world map, and settings screens use responsive container layouts so backend-driven screens remain usable in narrow/mobile-sized viewports.
- A full shared component library: all components listed under `ui/components/` are implemented with `render(view_model: Dictionary)` contracts
- Debug overlay at `ui/debug/dev_debug_overlay.gd`
- Theme system: `omni_theme.tres` + `theme_applier.gd`

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

Two distinct doc types exist in this repo:

1. **Current-reference docs** — should match what is implemented now.
2. **Planning docs** — should describe target architecture and future rollout.

### Rules for current-reference docs

- Prefer observed repository structure over roadmap language
- Clearly mark any unimplemented item as planned or proposed
- Avoid describing future folders/files as if they already exist
- Include newly added service files once they land in the repo

### Confirmed Mismatches From Earlier Versions (Resolved)

- Documents the actual clone target indirectly by matching the real repo owner/name
- Updates the autoload list to match the visible repository listing
- Updates the systems section to include all visible service files
- Updates the UI section to include `main.gd`, `ui_route_catalog.gd`, and all Phase 4/5 backends
- Notes `UIRouter` requires a `CanvasLayer` specifically
- Notes `game.starting_player_id` is strictly required with no runtime fallback
- Notes `A2J` registration requirement for new runtime classes
- Reflects `ticks_per_hour` as an implemented config key used by `gameplay_shell_presenter.gd`
