# Omni-Framework Debugging And Testing Guidelines

This document defines how Omni-Framework should use its development-time debugging and testing tools as implementation grows.

The two core tools are:

- the built-in dev overlay at `ui/debug/dev_debug_overlay.gd` for always-available runtime inspection
- `imgui-godot` for richer future debug tooling where an immediate-mode workflow helps
- GUT for automated tests in `tests/`

These are not optional "nice to have" extras. They are part of how the engine stays debuggable as the data model, mod pipeline, and runtime systems get more complex.

## Goals

- Make invalid state visible quickly
- Reduce time spent reproducing data-driven bugs
- Keep core systems covered by automated tests
- Give developers one consistent way to inspect the engine at runtime

## Tool Roles

### Runtime Overlay

Use the built-in dev overlay for:

- Boot/load summaries
- Registry counts
- Runtime state inspection
- Event stream inspection
- Save/load result snapshots

The current implementation is intentionally lightweight and ships as standard Godot UI so it remains easy to keep alive while the platform architecture is still moving.

### `imgui-godot`

Use `imgui-godot` for:

- Runtime state inspection
- Mod/load/patch diagnostics
- Event stream inspection
- AI/debug output review
- Rapid iteration panels during development

Do not use `imgui-godot` for:

- Shipping player-facing UI
- Permanent gameplay interactions
- Replacing real validation or tests

### GUT

Use GUT for:

- Unit tests of pure logic and helpers
- Integration tests of loading, saving, and pipeline behavior
- Content invariant tests against the assembled data set

Do not use GUT for:

- Manual-only visual verification
- Runtime debugging that belongs in ImGui panels
- Testing editor plugin behavior unless there is a strong reason

## Debug Overlay Principles

The debug layer should help answer these questions fast:

- What mods loaded, in what order, and with what warnings?
- What templates and patches are active right now?
- What does `GameState` currently contain?
- What events are firing?
- What view model did a backend build?
- What save/load or migration step just failed?

## Recommended Debug Panels

Whether a panel lives in the built-in overlay or a future ImGui tool, the initial debug surface should grow around a few stable panels.

### Boot / Mods

Show:

- Discovered mods
- Resolved load order
- Manifest validation errors
- Phase 1 / phase 2 timing
- Patch failures and warnings

### Data Registries

Show:

- Counts for parts, entities, locations, factions, quests, tasks, achievements
- Lookup by ID
- Source mod/file when available
- Selected entry JSON preview

### Game State

Show:

- Player entity state
- Current location
- Tick/day
- Active quests/tasks
- Flags
- Entity inventories and currencies

### Events

Show:

- Recent `GameEvents` history
- Filter by domain
- Filter by entity ID / quest ID / task ID
- Warning/error highlighting

Implementation note:

- Prefer one canonical event history owned by `GameEvents` itself. Debug panels should read that shared history instead of building separate partial logs.

### UI / Backend

Show:

- Current screen stack
- Current backend params
- Latest built view model
- UI refresh or binding failures

### Save / Load

Show:

- Current save schema version
- Last loaded slot metadata
- Migration path used
- Post-load sanity check failures
- Tick/day resync state after load

### AI

Show:

- Current provider
- Availability state
- Last request/response metadata
- Validation errors on structured AI output

## Debug Overlay Rules

- The overlay must never be required for gameplay.
- Debug panels should tolerate missing systems and partial boot states.
- Panels should read state safely and avoid mutating gameplay by accident.
- Any destructive debug action should be clearly labeled and gated.
- Prefer read-only inspection first; add mutation tools only when they save real development time.

## Debug Build Behavior

Recommended early policy:

- Debug overlays should be available only in development/debug contexts.
- Release builds should not depend on `imgui-godot`.
- If a runtime debug toggle exists, default it off.

## Logging Guidelines

Use logs and overlays together:

- Logs are the durable record
- The runtime overlay is the fast live inspector

Prefer logging:

- Load failures
- Validation warnings/errors
- Save/load failures
- AI provider failures
- Patch application failures

Avoid noisy logs for every routine state change unless they are also filterable in the overlay.

## Testing Pyramid

Omni-Framework should lean on three levels of tests.

### Unit Tests

Fast, isolated tests for:

- Stat math and clamping
- Condition evaluation
- Deep merge helpers
- Patch helper logic
- Manifest validation
- Query filters
- AI provider config selection

### Integration Tests

Cross-system tests for:

- Two-phase mod loading
- Definitions/stat metadata consumption
- Save/load round trips
- Save/load time resynchronization
- Quest/task lifecycle wiring
- Action dispatch against GameState
- Event emission on key transitions

### Content Tests

Whole-data-set checks for:

- Unknown references
- Broken stat pairs
- Invalid backend contracts
- Missing asset paths where required
- Broken location graph links
- Duplicate IDs
- Unknown stat/currency usage in content
- Unmapped `backend_class` values in location/entity screens

## Test Folder Conventions

Recommended layout:

```text
tests/
├── unit/
├── integration/
└── content/
```

Naming guidance:

- `test_<system>_<behavior>.gd`
- Keep one subject area per file when practical
- Prefer explicit test names over generic "works" names

Examples:

- `test_stat_manager_clamping.gd`
- `test_mod_loader_phase_order.gd`
- `test_content_location_references.gd`

## When A Change Requires Tests

Add or update tests when you change:

- Schema validation rules
- Patch behavior
- Save format or migration logic
- Stat math or defaults
- Event contracts
- Query/filter behavior
- Any bug that previously escaped into runtime

## Minimum Test Expectations By System

### ModLoader / DataManager

- Manifest validation
- Base mod required
- Correct load ordering
- Phase 1 before phase 2
- Patch target resolution

### Stat System

- Resource/capacity pairing
- Clamping after capacity changes
- Flat stat behavior
- Unknown stat rejection

### SaveManager

- Slot metadata read without full deserialize
- Save round trip
- Migration from previous schema version
- Missing template references fail clearly
- Invalid runtime state is rejected before writing a save
- Failed loads restore the prior live session instead of wiping it
- Save/load success and failure signals are covered by regression tests

### GameEvents

- Key transitions emit the documented signal
- Payload shape matches expectations

### UI Backends

- Required backend contract fields enforced
- View-model building does not mutate template data

## Good Testing Habits Early

- Prefer deterministic data fixtures
- Keep mod-loading fixtures small and purpose-built
- Write regression tests when a bug is found
- Test behavior, not private implementation details
- Put content invariants in automated tests before the content surface grows

## Anti-Patterns To Avoid

- Relying only on manual runtime checks
- Building a huge debug overlay before the first useful panel exists
- Writing tests that depend on unrelated content files
- Letting debug-only helpers leak into shipping gameplay logic
- Treating a passing smoke boot as enough coverage for data-driven systems

## Recommended First Steps

1. Add a minimal ImGui debug root/panel architecture for boot, mods, and GameState.
2. Add GUT tests for stat metadata parsing, ModLoader happy path, and save round trip.
3. Add content invariant tests for IDs, references, and stat pairing.
4. Keep every future loader and runtime system accountable to one debug panel and one test surface.

## Current Baseline

- `F3` toggles the current developer overlay in debug builds.
- The current overlay focuses on boot status, registry counts, GameState, and recent high-value events.
- GUT is configured through `res://.gutconfig.json`.
- The current automated baseline lives under `res://tests/` and covers stat metadata, entity stat clamping, signal forwarding, save/load flow, and base-content invariants.
