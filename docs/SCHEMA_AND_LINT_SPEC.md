# Omni-Framework Schema And Content Lint Spec

> **See also:** [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for architecture context, [`modding_guide.md`](modding_guide.md) for the data contracts modders must satisfy, [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) for stat field rules, and [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) for validation implementation patterns.

This document defines the minimum validation and linting behavior expected from the Omni-Framework data pipeline. It is the implementation companion to the architecture guardrails in `PROJECT_STRUCTURE.md` and the data contracts in `modding_guide.md`.

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
- `custom_fields[].id` must be unique within the part.
- `consume_on_use`, when present, must be a bool.
- `use_actions`, when present, must be an array of normal `ActionDispatcher` action objects. `use_action_payload` may be used as a single-action object.
- `use_label`, when present, should be a non-empty string used by the character menu's item action button.
- `script_path` must point to a script under the owning mod.

### Entities

- Required: `entity_id`, `display_name`
- `location_id` must exist if present.
- `stats` keys must exist in definitions.
- Resource stats should not initialize above their paired capacity.
- `inventory[].template_id` must reference a known part.
- `inventory[].custom_values` keys should match that part's `custom_fields[].id` values when the template declares custom fields.
- `assembly_socket_map` instance IDs must exist in inventory or assembly state.
- `interactions[].backend_class` must exist in the backend contract registry.

### Locations

- Required: `location_id`, `display_name`
- `connections` targets must exist.
- Self-links are warnings unless explicitly allowed later.
- Circular graphs are allowed only if graph traversal code supports them safely.
- `screens[].backend_class` must validate against backend contracts.
- `entry_condition` must be a valid `ConditionEvaluator` dictionary when present.
- `entry_conditions` must be an array of valid `ConditionEvaluator` dictionaries when present.
- `locked_message` must be a non-empty string when present. Lint warning if `entry_condition` or `entry_conditions` is present but `locked_message` is absent.

### Config

- `game.starting_player_id` is required and must reference a known entity.
- `game.starting_location` must reference a known location when present.
- `game.starting_discovered_locations` must be an array of known location ids when present.
- `game.ticks_per_day` and `game.ticks_per_hour` must be positive integers when present.
- `ui.time_advance_buttons` must be an array of labels ending in `tick(s)`, `hour(s)`, or `day(s)` when present.
- `task_routines` must be an array of routine objects when present. Each routine must declare `entity_id` and `entries`. Each entry must declare a tick field (`tick`, `at_tick`, or `tick_into_day`) and a task template field (`task_template_id` or `template_id`). Referenced entity ids and task template ids must exist.

### Factions

- Required: `faction_id`, `display_name`
- `territory`, `roster`, and `quest_pool` references must exist. `quest_pool` entries reference `quests.json` quest/contract ids, not `tasks.json` task template ids.
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

### Encounters

- Required: `encounter_id`, `participants`, `actions`, `resolution`
- `participants.player` and `participants.opponent` must be objects in v1. Their `entity_id` values must be `"player"` or reference known entity templates, either as raw ids or `entity:<id>`.
- `actions.player` and `actions.opponent` must be arrays of action objects with non-empty `action_id` values.
- Action IDs must be unique per role.
- `cost`, `on_success`, and `on_failure` must be arrays when present.
- Effect entries must be objects with a supported `effect`: `modify_stat`, `modify_encounter_stat`, `set_encounter_stat`, `set_flag`, `log`, `resolve`, `apply_tag`, or `remove_tag`.
- `modify_stat` must reference a known real stat; encounter-stat effects must reference declared encounter-local stats.
- `resolve` must reference a declared outcome.
- `apply_tag` and `remove_tag` must declare a non-empty `tag` or `tag_id`.
- `resolution.outcomes` must be an array of objects with unique, non-empty `outcome_id` values.
- Outcome `action_payload` must be an object when present and follows normal `ActionDispatcher` payload validation.
- `max_rounds_outcome` and `cancel_outcome` must reference declared outcomes when present.
- Encounter-local stats may share names with real stats, but this should stay intentional because the runtime keeps them in a separate context namespace.
- `opponent_strategy` must be an object when present. The only supported production kind is `weighted_random`; advanced strategy kinds are reserved for later work.
- Optional AI encounter log flavor uses `ai.encounter_log_flavor_enabled` plus the `base:encounter_log_flavor` AI template. This text is presentation-only and must not affect encounter mechanics. When AI flavor is active, authored log text is retained as fallback and only displayed if generation fails; requests use `AIManager`'s global queue to avoid provider concurrency failures. While one or more encounter log rows are waiting on AI text, player actions are disabled until the pending line resolves or falls back.

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

Backend contract validation applies only to JSON-authored screens and interactions that carry a `backend_class`. Engine-owned routes such as `main_menu`, `settings`, `save_slot_list`, `pause_menu`, `credits`, and `gameplay_shell` are registered in code and should be covered by router smoke tests instead of content schema validation.

Current implementation note: `BackendContractRegistry` is now a real engine system. Built-in contracts are registered at the start of `ModLoader.load_all_mods()`, and `DataManager.validate_loaded_content()` checks location screens and entity interactions against the registry before the boot sequence succeeds.

Minimum required contracts:

- `AssemblyEditorBackend`: no required fields; optional params are type-checked at load time
- `ExchangeBackend`: `source_inventory`, `destination_inventory`, `currency_id`
- `TaskProviderBackend`: `faction_id`
- `DialogueBackend`: `dialogue_resource`
- `ChallengeBackend`: `required_stat`, `required_value`
- `CatalogListBackend`: `data_source`, `action_payload`
- `EncounterBackend`: `encounter_id`
- `EntitySheetBackend`: no required fields; optional params are type-checked at load time
- `ActiveQuestLogBackend`: no required fields; optional params are type-checked at load time
- `FactionReputationBackend`: no required fields; optional params are type-checked at load time
- `AchievementListBackend`: no required fields; optional params are type-checked at load time
- `EventLogBackend`: no required fields; optional params are type-checked at load time
- `WorldMapBackend`: no required fields; optional params are type-checked at load time

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
- Screens with labels but no descriptions where the UI expects tooltip
- Entities listed in `entities_present` that also have task routines targeting other locations (likely causes duplicate presence)
- Locations with `entry_condition` or `entry_conditions` but missing `locked_message`
- Task routine entries with tick values outside `0` to `ticks_per_day - 1`
