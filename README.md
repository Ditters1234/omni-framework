# Omni-Framework

A single-player, data-driven, genre-agnostic game engine built on **Godot 4.6** using **GDScript**.

The engine provides systems; JSON provides content. The same runtime is intended to support very different games by swapping mod data instead of rewriting engine code.

## Current Repository Snapshot

This repository currently contains these top-level areas:

- `autoloads/` — global singleton services registered in Godot
- `core/` — shared runtime classes and low-level utilities
- `docs/` — architecture and implementation notes
- `mods/` — mod content, including the required `base` mod
- `systems/` — engine services such as stats, tasks, rewards, transactions, contracts, hooks, AI providers, and loaders
- `tests/` — automated test coverage
- `ui/` — routed screens, shared UI components, theme resources, and debug UI
- `addons/` — third-party plugins and integrations

## Quick Start

1. Clone the repository:

```bash
git clone https://github.com/Ditters1234/omni-framework.git
cd omni-framework
```

2. Open the project in **Godot 4.6**.
3. Let Godot import the project assets and addons.
4. Run the project from the editor.

## Architecture Notes

The current repo structure shows these implemented high-level pieces:

- **Autoload-driven boot flow** with dedicated managers for AI, audio, data, events, save/load, time, routing, game state, and mod loading.
- **System layer** that includes action dispatching, stat evaluation, quest tracking, task running, rewards, transactions, script hook services, assembly commit support, backend contract registration, and loader/provider subfolders.
- **UI layer** with `main.tscn`, `main.gd`, `ui_route_catalog.gd`, plus `components/`, `debug/`, `screens/`, and `theme/` folders.
- **12 backend-driven screens** fully implemented (Phase 4 + Phase 5): Assembly Editor, Exchange, List, Challenge, Task Provider, Catalog List, Dialogue, Entity Sheet, Active Quest Log, Faction Reputation, Achievement List, and Event Log.
- **Mod-first content layout** under `mods/`, with the engine expecting a base mod to exist.

## Documentation

Start with `docs/README.md` for the full documentation map.

- `docs/SYSTEM_CATALOG.md` — **start here** for a complete inventory of all systems and quick links
- `docs/PROJECT_STRUCTURE.md` - current code-facing structure and implementation snapshot

Other docs in `docs/` describe domain contracts, implementation guardrails, or planned work. Treat their stated scope as authoritative for that area, and prefer `PROJECT_STRUCTURE.md` when you need to know what exists in the repository today.

## Testing

The repository includes a `tests/` folder and a `.gutconfig.json`, indicating GUT-based automated tests are part of the workflow.

Run tests headlessly:

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gexit
```

For a focused run:

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gexit -gselect=test_entity_instance_stats
```

## Notes on Scope

This README is intentionally conservative. It avoids claiming that a subsystem is fully complete unless that subsystem is clearly represented by the current repository structure.
