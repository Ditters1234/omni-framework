
# Runtime Entity Presence

Entities shown in locations are now derived from runtime state, not static JSON.

## Behavior

- Uses GameState.entity_instances
- Filters by entity.location_id
- Excludes player
- Supports dynamic movement (wandering NPCs)

## Implementation

Use:
GameState.get_entity_instances_at_location(location_id)

UI should rely on this instead of only `entities_present`.
