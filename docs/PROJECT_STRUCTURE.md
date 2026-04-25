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

Additional root-level project files currently include `project.godot`, `.gutconfig.json`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `icon.svg`, and `default_bus_layout.tres`. Ad hoc debug or probe scripts should not live at `res://`; convert useful checks into GUT tests under `tests/`, or keep throwaway local scripts outside the project tree.

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
├── quest_tracker.gd
├── reward_service.gd
├── script_hook_loader.gd
├── script_hook_service.gd
├── stat_manager.gd
├── task_runner.gd
└── transaction_service.gd
```

`systems/loaders/` also includes `ai_persona_registry.gd`, which loads `ai_personas.json` persona templates into `DataManager`.

All of the following service scripts are fully implemented and should not be omitted from any architecture reference:

- `assembly_commit_service.gd`
- `backend_contract_registry.gd`
- `reward_service.gd`
- `script_hook_service.gd`
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
│   │   ├── entity_sheet_backend.gd
│   │   ├── entity_sheet_screen.gd / .tscn
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

- A root entry scene (`main.tscn`) and accompanying controller (`main.gd`)
- A route catalog (`ui_route_catalog.gd`) — the shared catalog for `backend_class → screen_id` mapping and the runtime `screen_id → scene_path` registry
- **14 backend-driven screens** (Phase 4 + Phase 5 complete, Phase 6 crafting complete, Phase 7 world map initial pass): `AssemblyEditorBackend`, `ExchangeBackend`, `ListBackend`, `ChallengeBackend`, `TaskProviderBackend`, `CatalogListBackend`, `CraftingBackend`, `DialogueBackend`, `EntitySheetBackend`, `ActiveQuestLogBackend`, `FactionReputationBackend`, `AchievementListBackend`, `EventLogBackend`, `WorldMapBackend`
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
