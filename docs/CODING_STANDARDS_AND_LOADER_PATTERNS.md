# Omni-Framework Coding Standards And Loader Patterns

> **See also:** [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for the architecture and autoload layout, [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) for validation patterns, and [`MODDING_GUIDE.md`](MODDING_GUIDE.md) for the data contracts these loaders enforce.

## Purpose

Use this document when implementing the first real systems so they follow one pattern instead of drifting into one-off styles.

## General Coding Standards

- Keep template data immutable once loaded.
- Keep runtime mutation on instance classes and stateful systems.
- Prefer small, explicit methods over large multi-purpose loaders.
- Fail with clear errors at boundaries instead of carrying invalid data forward.
- Use names that match the documentation exactly where possible.

## GDScript Conventions

- File names: `snake_case.gd`
- Class names: `PascalCase`
- Signals: `snake_case`
- Constants: `UPPER_SNAKE_CASE`
- IDs: namespaced strings

## Loader Responsibility Pattern

Each loader/registry should own exactly four concerns:

1. Read and parse its file
2. Validate entries and patches
3. Merge valid data into its registry
4. Expose read/query helpers for the rest of the engine

Each loader should not:

- Mutate runtime game state
- Reach into unrelated registries directly when `DataManager` should coordinate
- Contain UI logic
- Perform save serialization

## Recommended Loader Shape

```gdscript
class_name PartsRegistry
extends RefCounted

func register_additions(mod_id: String, raw_data: Dictionary) -> void:
    pass

func apply_patches(mod_id: String, raw_data: Dictionary) -> void:
    pass

func get_by_id(part_id: String) -> Dictionary:
    return {}

func query(filters: Dictionary = {}) -> Array[Dictionary]:
    return []
```

## Loader Implementation Rules

- Separate parsing from validation.
- Separate validation from merge/application.
- Keep one private helper per major validation concern.
- Preserve enough source metadata internally to explain where each merged entry came from.

## Patch Pattern

For each registry, patch support should be intentional rather than ad hoc.

Recommended patch flow:

1. Confirm target exists
2. Validate operation names
3. Validate payload types
4. Apply patch to a copy or controlled mutable entry
5. Re-validate the resulting entry if needed

## Autoload Responsibility Pattern

Autoloads should act as orchestrators, not dumping grounds.

- `ModLoader`: discover, order, phase execution
- `DataManager`: own template registries and template queries
- `GameState`: own runtime state
- `SaveManager`: own persistence and migration
- `TimeKeeper`: own time advancement
- `UIRouter`: own navigation
- `AIManager`: own provider abstraction

If an autoload starts implementing unrelated business logic, it probably wants a system class under `systems/`.

## DataManager Pattern

`DataManager` should be the template access boundary.

- Other systems should not read raw mod files directly.
- Other systems should not mutate registry dictionaries in place.
- Query helpers should live here or in well-defined registry classes.
- Cross-registry validation should happen during loading, not deep in gameplay code.

## Runtime Instance Pattern

Runtime instance classes should wrap mutable state cleanly:

- Template reference by ID
- Instance-specific values
- Minimal derived state
- Clear serialization boundaries

Do not let runtime instance classes become copies of full template dictionaries plus random ad hoc fields.

## UI Backend Pattern

Backends should:

- Accept validated params
- Gather runtime/template data
- Build a view model
- Expose narrow actions

Screens should:

- Render the view model
- Own layout and presentation
- Avoid business logic and direct template queries

Components should:

- Accept already-prepared data
- Remain reusable
- Avoid calling autoloads directly

## Validation Pattern

Every major system should have a validation boundary:

- Mod manifests validate before load ordering
- JSON additions validate before merge
- Patches validate before apply
- Saves validate before and after migration
- AI structured output validates before use

## Error Handling Pattern

- Use precise messages
- Include IDs and field paths
- Distinguish content errors from engine errors
- Distinguish hard failures from warnings

Bad:

```text
Failed to load parts
```

Good:

```text
parts.json: parts[2].price.gold must be a number greater than or equal to 0
```

## Query Pattern

Start simple, but keep the interface consistent:

- `get_by_id(id)`
- `has(id)`
- `query(filters)`

Suggested early filter keys:

- `tags`
- `required_tags`
- `location_id`
- `faction_id`
- `backend_class`
- `ui_group`

## Testing Pattern

Once tests begin, cover three layers:

- Unit tests for validation and merge helpers
- Integration tests for two-phase loading and save/load
- Content tests for invariants across the whole data set

See `docs/DEBUGGING_AND_TESTING_GUIDELINES.md` for the concrete `imgui-godot` and GUT workflow expectations.

## Early Anti-Patterns To Avoid

- Letting one loader silently create missing defaults that another loader assumes were authored explicitly
- Passing large mutable dictionaries through events
- Letting screens query `DataManager` directly for all logic
- Mixing save migration logic into gameplay systems
- Making patch behavior inconsistent between registries

## Recommended First Implementation Order

1. Definitions validation and stat metadata support
2. Parts and entities loaders with full validation
3. DataManager query helpers
4. Backend contract registry
5. SaveManager versioning and migration scaffolding
6. Event logging and debug tooling
