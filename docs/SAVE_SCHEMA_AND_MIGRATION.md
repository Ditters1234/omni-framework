# Omni-Framework Save Schema And Migration

> **See also:** [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for the runtime/save split, [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) for save data validation rules, and [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) for testing save load/migration code.

This document defines the persistence contract for Omni-Framework save data. It complements the runtime/save split already described in `PROJECT_STRUCTURE.md`.

## Core Rule

Template content uses plain JSON dictionaries loaded from mods. Save data uses `A2J` for lossless runtime serialization.

- Do not use `A2J` for template files.
- Do not use plain template parsing rules for runtime save payloads.

## Save Design Goals

- Human-readable files where practical
- Stable forward migration path
- Minimal coupling to template implementation details
- Lossless round-trip for runtime objects
- Clear separation between template IDs and runtime instance state

## Save File Shape

Recommended top-level structure:

```json
{
  "save_schema_version": 1,
  "engine_version": "0.1.0",
  "created_at": "2026-04-16T20:30:00Z",
  "updated_at": "2026-04-16T22:14:00Z",
  "slot_metadata": {
    "display_name": "Day 4 Safehouse",
    "playtime_seconds": 5420,
    "day": 4,
    "tick": 132
  },
  "game_state": {
    "...": "A2J serialized runtime state"
  }
}
```

## Required Top-Level Fields

- `save_schema_version`
- `engine_version`
- `created_at`
- `updated_at`
- `slot_metadata`
- `game_state`

Compatibility note:

- Legacy saves that still contain `game_state` but are missing some metadata fields may be backfilled during migration.
- A save with no `game_state` payload is always invalid.

## Slot Metadata Purpose

`slot_metadata` exists so save-slot UI does not need to deserialize the entire runtime state just to show:

- Save label
- Last played time
- Day/tick
- Playtime
- Optional screenshot or location preview later

## What Belongs In Save Data

- Runtime entity instances
- Runtime part instances
- Inventory and assembly state
- Quest progress
- Task progress
- Achievement runtime progress
- Player location
- World discovery state
- Flags and counters
- Current time state

## What Does Not Belong In Save Data

- Full template dictionaries from mods
- Redundant static content that can be resolved from IDs
- Secrets or API keys
- Editor-only debug history unless explicitly enabled for development

## Template Reference Strategy

Whenever possible, save runtime state by reference:

- Save `template_id`, not the full part template
- Save `entity_id` plus runtime overrides, not the original entity template dictionary
- Save location IDs, faction IDs, and quest IDs rather than duplicating authored data

This keeps saves smaller and lets template migrations happen independently from runtime serialization.

## Versioning Rules

- Every save file must contain `save_schema_version`.
- Schema versions are monotonic integers.
- Breaking save-shape changes must increment the version.
- Non-breaking additive fields may stay within the same version if loading remains deterministic.

## Migration Rules

Migrations should be explicit functions:

```gdscript
func migrate_v1_to_v2(raw_save: Dictionary) -> Dictionary:
    return raw_save
```

Rules:

- Migrate one version step at a time.
- Validate after each migration step.
- Never mutate the original raw dictionary in hidden ways without documenting it.
- Log the migration path applied.
- If a migration cannot run safely, fail with a clear message instead of partially loading.

## Validation Order

Recommended load order:

1. Read raw file
2. Validate required top-level save fields
3. Check `save_schema_version`
4. Run migrations until current
5. Validate migrated payload
6. Deserialize `game_state` with `A2J`
7. Re-run runtime sanity checks

Current implementation note:

- The runtime sanity pass should also resynchronize any derived clock state such as `TimeKeeper`'s tick-within-day accumulator after `GameState` is restored, and normalize `current_day` from `current_tick` if the saved values disagree.
- Save operations should also normalize persisted time state before writing so slot metadata and `game_state` do not preserve a stale `current_day/current_tick` mismatch.

## Runtime Sanity Checks After Load

After deserialization, verify:

- Current location still exists
- Entity and part template references still exist
- Resource stats are clamped to capacities
- Active quests still reference known quest definitions
- Active tasks still reference known task templates
- Inventories do not contain impossible duplicate instance IDs
- Any derived runtime counters that mirror saved state are recomputed instead of trusted blindly

## Handling Missing Template References

Mods can be removed or changed after a save was created. Decide early how to handle that.

Recommended policy:

- Missing critical templates that block deserialization: hard load failure
- Missing optional presentation assets: recover with fallback
- Missing mod content referenced by save state: fail with a clear "missing dependency mod" message unless a migrator explicitly handles it
- Failed loads should roll back to the previous live `GameState` snapshot instead of clearing the session
- Runtime validation should run before save as well as af