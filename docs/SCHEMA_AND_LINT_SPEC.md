# Omni-Framework Schema And Content Lint Spec

This document defines the minimum validation and linting behavior expected from the Omni-Framework data pipeline. It is the implementation companion to the architecture guardrails in `docs/PROJECT_STRUCTURE.md` and the data contracts in `docs/modding_guide.md`.

## Purpose

The loader pipeline should reject malformed content early, explain failures clearly, and prevent invalid data from leaking into runtime systems.

Validation has three layers:

1. **Schema validation**: required fields, field types, enum values, allowed keys.
2. **Reference validation**: IDs, dependencies, paths, paired fields, and cross-file references.
3. **Content linting**: warnings for risky or inconsistent authoring that may still be technically loadable.

## Validation Philosophy

- Fail fast for schema violations and broken references.
- Prefer exact field-path errors over generic "load failed" messages.
- Validation applies to base content and mods equally.
- Patches are validated both structurally and against the merged target they modify.
- The validator should be deterministic and produce the same result for the same load order.

## Error Reporting Format

Each validation issue should report:

- `severity`: `error` or `warning`
- `system`: `definitions`, `parts`, `entities`, `locations`, `factions`, `quests`, `tasks`, `achievements`, `config`, `save`
- `mod_id`: owning mod
- `file_path`: source file
- `entry_id`: content ID when applicable
- `field_path`: precise path such as `parts[3].stats.health_max`
- `message`: human-readable explanation
- `suggestion`: optional remediation hint

Example:

```text
[error] [parts] [my_mod] res://mods/me/my_mod/data/parts.json
entry_id=my_mod:plasma_blade
field_path=parts[4].stats.power_rating
Unknown stat id `power_rating`. Define it in definitions.json or rename the key.
```

## Severity Rules

### Errors

Errors block the mod or boot sequence for the affected content:

- Missing required field
- Unknown field where the schema is closed
- Wrong primitive type
- Invalid enum value
- Broken ID reference
- Unknown stat or currency
- Invalid stat pair metadata
- Unknown `backend_class`
- Patch target missing after phase one
- Invalid save schema version with no migrator

### Warnings

Warnings do not block loading, but should be surfaced in logs and debug tools:

- Optional field present but unusual
- Asset path exists in a deprecated location
- Empty arrays or objects that are technically valid but probably accidental
- Unused config keys in permissive config subtrees
- Redundant patch operations that do nothing
- Stats hidden from UI but included in visible stat groups

## Definitions Schema

`definitions.json` is foundational and should be validated first.

Required top-level keys:

- `currencies`: array of unique strings
- `stats`: array of stat-definition objects

### Currency Rules

- Currency IDs must be unique strings.
- Currency IDs should be lowercase snake case or namespaced IDs if globally shared across mods.
- Empty strings are invalid.

### Stat Definition Rules

Each stat object must contain:

- `id`: unique string
- `kind`: `flat`, `resource`, or `capacity`

Optional fields:

- `paired_capacity_id`
- `paired_base_id`
- `default_value`
- `default_capacity_value`
- `clamp_min`
- `ui_group`
- `hidden`

Rules:

- `kind=flat`: must not declare paired IDs.
- `kind=resource`: must declare `paired_capacity_id`.
- `kind=capacity`: must declare `paired_base_id`.
- Capacity stats should use the `_max` suffix.
- Resource stats should not use the `_max` suffix.
- Pairing must be reciprocal.
- Duplicate stat IDs are errors.

## Per-System Validation Rules

### Parts

- Required: `id`, `display_name`, `description`, `tags`
- `id` must be unique and namespaced.
- `stats` keys must exist in definitions.
- `price` currencies must exist in definitions.
- `provides_sockets[].id` must be unique within the part.
- `script_path` must point to a script under the owning mod.

### Entities

- Required: `entity_id`, `display_name`
- `location_id` must exist if present.
- `stats` keys must exist in definitions.
- Resource stats should not initialize above their paired capacity.
- `inventory[].template_id` must reference a known part.
- `assembly_socket_map` instance IDs must exist in inventory or assembly state.
- `interactions[].backend_class` must exist in the backend contract registry.

### Locations

- Required: `location_id`, `display_name`
- `connections` targets must exist.
- Self-links are warnings unless explicitly allowed later.
- Circular graphs are allowed only if graph traversal code supports them safely.
- `screens[].backend_class` must validate against backend contracts.

### Factions

- Required: `faction_id`, `display_name`
- `territory`, `roster`, and `quest_pool` references must exist.
- Reputation threshold values should be numeric and monotonic if ordered tiers are expected.

### Quests

- Required: `quest_id`, `display_name`, `stages`
- Each stage must define valid objectives.
- Objective references must exist.
- Reward currencies and items must validate.

### Tasks

- Required: `template_id`, `type`
- `type` must be a known enum.
- `target` must exist when the task type requires it.
- Reward references and currencies must validate.

### Achievements

- Required: `achievement_id`, `display_name`, `stat_name`, `requirement`
- `stat_name` should point at a tracked runtime metric defined by the achievement system.

### Config

- Validate known subtrees strictly: `game`, `balance`, `ui`, `stats`, `ai`
- Unknown keys inside strict subtrees should warn or error depending on maturity of the schema.
- Config should remain more permissive than gameplay template files, but not unbounded.

## Backend Contract Validation

Each `backend_class` should have a contract definition with:

- Required fields
- Optional fields
- Allowed field types
- Reference validation rules

Backend contract validation applies only to JSON-authored screens and interactions that carry a `backend_class`. Engine-owned routes such as `main_menu`, `settings`, `save_slot_list`, `pause_menu`, `credits`, `gameplay_shell`, and `location_view` are registered in code and should be covered by router smoke tests instead of content schema validation.

Current implementation note: `BackendContractRegistry` is now a real engine system. Built-in contracts are registered at the start of `ModLoader.load_all_mods()`, and `DataManager.validate_loaded_content()` checks location screens and entity interactions against the registry before the boot sequence succeeds.

Minimum required contracts:

- `AssemblyEditorBackend`: no required fields; optional params are type-checked at load time
- `ExchangeBackend`: `source_inventory`, `destination_inventory`, `currency_id`
- `TaskProviderBackend`: `faction_id`
- `DialogueBackend`: `dialogue_resource`
- `ChallengeBackend`: `required_stat`, `required_value`
- `CatalogListBackend`: `data_source`, `action_payload`

## Patch Validation

Patches must validate in two passes:

1. Patch object schema validation.
2. Semantic validation against the target entry after additions have loaded.

Rules:

- Every patch must include `target`.
- The target must exist by phase two.
- `set_*` operations must validate the same way the underlying field validates in normal additions.
- Array mutation helpers (`add_*`, `remove_*`, `modify_*`) should reject type mismatches.
- Unknown patch operations are errors.

## Lint Rules Worth Adding Early

These should start as warnings even if they do not block loading:

- IDs that are not namespaced outside the base mod
- Parts with no price and no explicit `unsellable` rule
- Locations with no path back to the rest of the graph
- Screens with labels but no descriptions where the UI expects tooltips
- Resources with default current values that do not match default capacities
- Stats assigned to UI groups that are never displayed
- Mods overriding another mod's stat metadata without a declared dependency

## Save Validation Boundary

Template validation and save validation are related but separate.

- Template validation checks authored content.
- Save validation checks runtime persistence payloads.
- Save migration should happen before strict save validation finalizes.

## Minimum Tooling Target

At minimum, Omni-Framework should eventually expose:

- A boot-time validator
- A standalone content lint command for development
- A debug panel listing current warnings and errors
- A way to trace each merged entry back to its source mod and file
