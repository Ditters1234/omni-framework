
# Runtime Entity Presence

Entities shown at locations are derived from runtime state, not static JSON alone.

## How entity presence is resolved

The gameplay location surface merges three sources to determine which NPCs appear at a given location:

1. **`entities_present`** (static) — array in `locations.json`. Always shows these entities regardless of their runtime `location_id`. Useful for NPCs that should always be visible at a location.
2. **`DataManager.query_entities({"location_id": ...})`** (template) — entities whose authored template has a matching `location_id`.
3. **`GameState.entity_instances`** (runtime) — all runtime entity instances whose current `location_id` matches. This is the dynamic source — when a `TRAVEL` task completes and changes an entity's `location_id`, the entity moves.

Results are deduplicated. The player entity is always excluded.

## Key API

```gdscript
GameState.get_entity_instances_at_location(location_id)
```

Returns all runtime entity instances at the given location, excluding the player.

## For moving NPCs

NPCs that travel via task routines or `TRAVEL` tasks should **not** be listed in any location's `entities_present`. Set the entity's initial `location_id` in `entities.json` and let `TaskRunner` handle movement. The UI will automatically show the NPC at whichever location their runtime `location_id` points to.

## Implementation

See `ui/screens/gameplay_shell/gameplay_location_surface.gd` method `_get_present_entity_ids()` for the merge logic.
