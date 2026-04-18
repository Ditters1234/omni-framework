# Omni-Framework Documentation

This folder is the canonical reference for Omni-Framework. The main docs below are the single source of truth for the architecture direction, modding rules, and implementation guardrails.

## Start Here

| File | Purpose |
|---|---|
| `docs/PROJECT_STRUCTURE.md` | Engine architecture, target folder layout, autoload responsibilities, UI architecture, and cross-system guardrails |
| `docs/UI_IMPLEMENTATION_PLAN.md` | UI rollout plan: backend catalog, engine-owned screens, component library, and phased implementation priorities |
| `docs/modding_guide.md` | The modder-facing contract: data schemas, patching rules, backend requirements, config keys, and safe extension patterns |
| `docs/STAT_SYSTEM_IMPLEMENTATION.md` | Canonical stat-pair rules, clamping behavior, validation requirements, and implementation patterns |
| `docs/SCHEMA_AND_LINT_SPEC.md` | Load-time validation rules, per-system schema expectations, patch validation, and content lint severity guidance |
| `docs/GAME_EVENTS_TAXONOMY.md` | Event naming, domain grouping, payload design, and long-term signal-bus stability rules |
| `docs/SAVE_SCHEMA_AND_MIGRATION.md` | Save-file shape, versioning, migration order, and post-load sanity expectations |
| `docs/CODING_STANDARDS_AND_LOADER_PATTERNS.md` | GDScript implementation habits, loader/autoload boundaries, and early anti-patterns to avoid |
| `docs/DEBUGGING_AND_TESTING_GUIDELINES.md` | How to use `imgui-godot` and GUT for runtime inspection, automated coverage, and content invariants |

## Reading Order

1. Read `PROJECT_STRUCTURE.md` to understand the engine's target architecture and implementation priorities.
2. Read `UI_IMPLEMENTATION_PLAN.md` before expanding the routed UI surface, adding a backend, or introducing engine-owned screens.
3. Read `CODING_STANDARDS_AND_LOADER_PATTERNS.md` before building the first loaders, registries, or autoload orchestration.
4. Read `SCHEMA_AND_LINT_SPEC.md` before implementing validation or patch application.
5. Read `modding_guide.md` when authoring JSON, patches, assets, or script hooks.
6. Read `STAT_SYSTEM_IMPLEMENTATION.md` before changing stat math, stat schema, or any system that touches resource pools.
7. Read `GAME_EVENTS_TAXONOMY.md` before expanding `GameEvents`.
8. Read `SAVE_SCHEMA_AND_MIGRATION.md` before building persistence or migration logic.
9. Read `DEBUGGING_AND_TESTING_GUIDELINES.md` before building debug overlays or test coverage.

## Current Documentation Policy

- `PROJECT_STRUCTURE.md` describes the target architecture and explicitly calls out where hardening work is still planned.
- `UI_IMPLEMENTATION_PLAN.md` is the source of truth for the backend catalog, engine-owned screen catalog, component rollout, and UI build order.
- `modding_guide.md` documents the contracts modders are expected to satisfy, even when enforcement is still being implemented in code.
- `STAT_SYSTEM_IMPLEMENTATION.md` is the source of truth for stat invariants and validation rules.
- `SCHEMA_AND_LINT_SPEC.md` is the source of truth for content validation behavior.
- `GAME_EVENTS_TAXONOMY.md` is the source of truth for signal naming and event grouping.
- `SAVE_SCHEMA_AND_MIGRATION.md` is the source of truth for persistence versioning and migration.
- `CODING_STANDARDS_AND_LOADER_PATTERNS.md` is the source of truth for early implementation patterns.
- `DEBUGGING_AND_TESTING_GUIDELINES.md` is the source of truth for dev-only debug tooling and automated testing expectations.

## Architecture Priorities

The current documentation set assumes these priorities going forward:

- Schema validation for every template file at load time.
- A hard split between engine-owned routed screens and moddable backend-driven screens.
- Explicit contracts between JSON screen definitions, backend classes, and UI rendering.
- A `JSON -> Backend -> ViewModel -> UI` flow so screens stay reusable and dumb.
- Query, debug, and migration tooling as first-class engine systems rather than ad hoc helpers.
- Strict invariants around stats, IDs, references, and AI-generated content.
