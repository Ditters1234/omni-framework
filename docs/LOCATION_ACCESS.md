# Location Access

`LocationAccessService` provides shared checks for whether the player can enter a location.

It is used by:

- gameplay location travel buttons
- world map backend travel

## Location fields

```json
{
  "location_id": "example:merchant_house",
  "display_name": "Sable's Locked Room",
  "locked_message": "Sable's door is locked. Customers are not allowed inside.",
  "entry_condition": {
    "type": "has_flag",
    "flag_id": "example:sable_house_open",
    "value": true
  }
}
```

## Supported condition shapes

### `entry_condition`

A single `ConditionEvaluator` dictionary. It must pass.

```json
"entry_condition": {
  "type": "has_flag",
  "flag_id": "example:door_open",
  "value": true
}
```

### `entry_conditions`

An array of `ConditionEvaluator` dictionaries. Uses OR logic. At least one must pass.

```json
"entry_conditions": [
  {
    "type": "has_flag",
    "flag_id": "example:has_key",
    "value": true
  },
  {
    "type": "stat_check",
    "stat": "power",
    "op": ">=",
    "value": 10
  }
]
```

All condition types from `ConditionEvaluator` work here — `has_flag`, `stat_check`, `has_item_tag`, `has_part`, `has_currency`, `reputation_threshold`, `quest_complete`, plus compound `AND`/`OR`/`NOT` blocks. See the modding guide §12 for the full condition reference.

## Locked message

Use `locked_message` to control the UI message when blocked.

```json
"locked_message": "The door is locked."
```

Defaults to `"You cannot enter this location right now."` if omitted.

## Unlocking at runtime

Use the `set_flag` action from a quest reward, task completion, dialogue branch, or any `ActionDispatcher`-compatible context:

```json
{
  "type": "set_flag",
  "flag_id": "example:sable_house_open",
  "value": true
}
```

## Example mod

The included example mod at `mods/example/traveling_merchant/` uses location access to lock Sable's private room behind the `example:sable_house_open` flag. By default that flag is not set, so the player cannot enter.
