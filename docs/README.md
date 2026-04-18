<div style="display: flex; align-items: center; gap: 20px;">
  <img src="../icon.svg" alt="Omni-Framework Icon" width="100"/>
  <h1>Omni-Framework Documentation</h1>
</div>

Omni-Framework is a data-driven, genre-agnostic game engine built on Godot 4.

This folder is the canonical reference for Omni-Framework. The main docs below are the single source of truth for the architecture direction, modding rules, and implementation guardrails.

## Documents

| File | Purpose |
|---|---|
| [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) | Engine architecture, target folder layout, autoload responsibilities, UI architecture, and cross-system guardrails |
| [`UI_IMPLEMENTATION_PLAN.md`](UI_IMPLEMENTATION_PLAN.md) | UI rollout plan: backend catalog, engine-owned screens, component library, and phased implementation priorities |
| [`modding_guide.md`](modding_guide.md) | The modder-facing contract: data schemas, patching rules, backend requirements, config keys, and safe extension patterns |
| [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) | Canonical stat-pair rules, clamping behavior, validation requirements, and implementation patterns |
| [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) | Load-time validation rules, per-system schema expectations, patch validation, and content lint severity guidance |
| [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md) | Event naming, domain grouping, payload design, and long-term signal-bus stability rules |
| [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md) | Save-file shape, versioning, migration order, and post-load sanity expectations |
| [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) | GDScript implementation habits, loader/autoload boundaries, and early anti-patterns to avoid |
| [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) | How to use `imgui-godot` and GUT for runtime inspection, automated coverage, and content invariants |

## Reading Order

1. Read [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) to understand the engine's target architecture and implementation priorities.
2. Read [`UI_IMPLEMENTATION_PLAN.md`](UI_IMPLEMENTATION_PLAN.md) before expanding the routed UI surface, adding a backend, or introducing engine-owned screens.
3. Read [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) before building the first loaders, registries, or autoload orchestration.
4. Read [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) before implementing validation or patch application.
5. Read [`modding_guide.md`](modding_guide.md) when authoring JSON, patches, assets, or script hooks.
6. Read [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) before changing stat math, stat schema, or any system that touches resource pools.
7. Read [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md) before expanding `GameEvents`.
8. Read [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md) before building persistence or migration logic.
9. Read [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) before building debug overlays or test coverage.

## Current Documentation Policy

Each doc below is the source of truth for its domain:

- [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) — target architecture; explicitly calls out where hardening is still planned.
- [`UI_IMPLEMENTATION_PLAN.md`](UI_IMPLEMENTATION_PLAN.md) — backend catalog, engine-owned screen catalog, component rollout, and UI build order.
- [`modding_guide.md`](modding_guide.md) — the contracts modders must satisfy, even where enforcement is still being implemented.
- [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) — stat invariants and validation rules.
- [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) — content validation behavior.
- [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md) — signal naming and event grouping.
- [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md) — persistence versioning and migration.
- [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) — early implementation patterns.
- [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) — dev-only debug tooling and automated testing expectations.

## Architecture Priorities

The current documentation set assumes these 