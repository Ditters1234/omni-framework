<p>
  <img src="../icon.svg" alt="Omni-Framework Icon" width="100" style="vertical-align: middle; margin-right: 15px;">
  <span style="font-size: 2.5em; font-weight: bold; vertical-align: middle;">Omni-Framework Documentation</span>
</p>

Omni-Framework is a data-driven, genre-agnostic game engine built on Godot 4.

This folder is the documentation home for Omni-Framework. Keep docs here as current references; completed rollout plans and historical audits should be removed or folded into canonical references.

## Documents

| File | Purpose |
|---|---|
| [`SYSTEM_CATALOG.md`](SYSTEM_CATALOG.md) | **Start here.** Complete inventory of all systems, subsystems, relationships, and links to relevant documentation. |
| [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) | Current repository structure, implemented folders, autoloads, systems, and documentation-scope guidance |
| [`TASK_ROUTINES.md`](TASK_ROUTINES.md) | Daily task routine runner for scheduled NPC/entity movement through `TaskRunner` and `LocationGraph` route costs |
| [`LOCATION_ACCESS.md`](LOCATION_ACCESS.md) | Location entry gating with `entry_condition`, `entry_conditions`, and `locked_message` through `LocationAccessService` |
| [`RUNTIME_ENTITY_PRESENCE.md`](RUNTIME_ENTITY_PRESENCE.md) | How the gameplay surface resolves which entities appear at a location from static, template, and runtime sources |
| [`modding_guide.md`](modding_guide.md) | The modder-facing contract: data schemas, patching rules, backend requirements, config keys, and safe extension patterns |
| [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) | Canonical stat-pair rules, clamping behavior, validation requirements, and implementation patterns |
| [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) | Load-time validation rules, per-system schema expectations, patch validation, and content lint severity guidance |
| [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md) | Event naming, domain grouping, payload design, and long-term signal-bus stability rules |
| [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md) | Save-file shape, versioning, migration order, and post-load sanity expectations |
| [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) | GDScript implementation habits, loader/autoload boundaries, and early anti-patterns to avoid |
| [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) | How to use `imgui-godot` and GUT for runtime inspection, automated coverage, and content invariants |

## Reading Order

0. **Start here:** Read [`SYSTEM_CATALOG.md`](SYSTEM_CATALOG.md) for a high-level map of all systems and quick links to detailed docs.
1. Read [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) to understand the current repository layout before making structural changes.
2. Read [`TASK_ROUTINES.md`](TASK_ROUTINES.md) before adding scheduled NPC/entity movement.
3. Read [`LOCATION_ACCESS.md`](LOCATION_ACCESS.md) before gating locations behind conditions.
4. Read [`SYSTEM_CATALOG.md`](SYSTEM_CATALOG.md) and [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) before expanding the routed UI surface, adding a backend, or introducing engine-owned screens.
5. Read [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) before building the first loaders, registries, or autoload orchestration.
6. Read [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) before implementing validation or patch application.
7. Read [`modding_guide.md`](modding_guide.md) when authoring JSON, patches, assets, or script hooks.
8. Read [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) before changing stat math, stat schema, or any system that touches resource pools.
9. Read [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md) before expanding `GameEvents`.
10. Read [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md) before building persistence or migration logic.
11. Read [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) before building debug overlays or test coverage.

## Current Documentation Policy

Each doc below has an explicit scope. Prefer `SYSTEM_CATALOG.md` for discovery and `PROJECT_STRUCTURE.md` for what exists today.

- [`SYSTEM_CATALOG.md`](SYSTEM_CATALOG.md) — complete inventory of all systems, subsystems, and their relationships; entry point for system discovery.
- [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) - current repo snapshot and implementation structure.
- [`TASK_ROUTINES.md`](TASK_ROUTINES.md) — implemented daily task routine runner for scheduled entity movement.
- [`LOCATION_ACCESS.md`](LOCATION_ACCESS.md) — implemented location entry gating through `LocationAccessService`.
- [`RUNTIME_ENTITY_PRESENCE.md`](RUNTIME_ENTITY_PRESENCE.md) — how entity presence at locations is resolved from static, template, and runtime sources.
- [`modding_guide.md`](modding_guide.md) — the contracts modders must satisfy, even where enforcement is still being implemented.
- [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) — stat invariants and validation rules.
- [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) — content validation behavior.
- [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md) — signal naming and event grouping.
- [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md) — persistence versioning and migration.
- [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) — early implementation patterns.
- [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) — dev-only debug tooling and automated testing expectations.

## Contributing to Omni-Framework

When making changes to the engine or base game:

1. **Code changes** must follow [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md)
2. **Data changes** must satisfy [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md)
3. **Tests** should cover your changes — run the test suite before submitting
4. **Documentation** must be updated if you change architecture or contracts
5. **Backwards compatibility** is expected — use migration patterns from [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md)
