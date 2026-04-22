# Omni-Framework — Project Structure

This document is a **current-structure replacement** for the repository's broader architecture note. It is intentionally grounded in the visible repository layout rather than mixing present implementation with future-state planning.

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

Additional root-level project files currently include `project.godot`, `.gutconfig.json`, `README.md`, `AGENTS.md`, and `CLAUDE.md`.

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
├── loaders/
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

### Notable differences from broader planning docs

Compared with the more aspirational architecture descriptions, the current repo clearly includes several implemented service scripts that deserve first-class mention:

- `assembly_commit_service.gd`
- `backend_contract_registry.gd`
- `reward_service.gd`
- `script_hook_service.gd`
- `transaction_service.gd`

Any structure doc that omits those files now understates the current implementation.

## UI

The `ui/` folder currently contains:

```text
ui/
├── components/
├── debug/
├── screens/
├── theme/
├── main.gd
├── main.tscn
└── ui_route_catalog.gd
```

### What this implies

The UI layer is not just a collection of scenes. It already includes:

- a root entry scene (`main.tscn`)
- an accompanying root controller script (`main.gd`)
- a route catalog (`ui_route_catalog.gd`)
- separated folders for reusable widgets, debug tooling, routed screens, and theming

Any doc that describes the UI tree but leaves out `main.gd` or `ui_route_catalog.gd` is no longer fully aligned with the codebase.

## Core

The repository contains a top-level `core/` folder, confirming that shared runtime classes/utilities are separated from autoloads and systems. This replacement doc does **not** enumerate files inside `core/` unless they are directly verified in a visible repository listing.

That is intentional: structure docs should not imply file-level certainty when only folder-level certainty has been confirmed.

## Mods

The repository contains a top-level `mods/` folder, and the public README states that `mods/base/` is required for boot. That aligns with the engine's mod-first design and should remain part of the documented contract.

## Tests

The repository contains a top-level `tests/` folder and a `.gutconfig.json` file. That strongly indicates GUT-based test coverage is part of the project baseline and should be documented as such.

## Documentation Guidance

For this repo, there are really two different doc types:

1. **Code-facing docs** — should match what is implemented now.
2. **Planning docs** — should describe target architecture and future rollout.

The original structure document tries to do both. That is useful for internal planning, but it becomes misleading as a reference when readers want to know what is already in the repo today.

### Recommended rule going forward

When a document is meant to be a **current reference**, it should:

- prefer observed repository structure over roadmap language
- clearly mark any unimplemented item as planned
- avoid describing future folders/files as if they already exist
- include newly added service files once they land in the repo

## Confirmed Mismatches This Replacement Fixes

This replacement corrects or tightens the following mismatches:

- documents the actual clone target indirectly by matching the real repo owner/name
- updates the autoload list to match the visible repository listing
- updates the systems section to include visible service files omitted by broader planning text
- updates the UI section to include `main.gd` and `ui_route_catalog.gd`
- removes file-level certainty for folders that were not directly verified in the visible listing
- separates present-state documentation from future-state planning language

## Suggested Split for Long-Term Maintainability

If you want cleaner docs long term, split the original broad structure doc into:

- `docs/PROJECT_STRUCTURE.md` — current repo snapshot only
- `docs/ARCHITECTURE_ROADMAP.md` — future target structure and phased design goals

That prevents the same document from trying to be both a map of today and a promise about tomorrow.
