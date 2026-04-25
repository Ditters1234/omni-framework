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
  "locked_message": "Sable's door is locked.",
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
    "has_part": "example:lockpick"
  }
]
```

## Locked message

Use `locked_message` to control the UI message when blocked.

```json
"locked_message": "The door is locked."
```

## Sable's room

The included replacement for:

```text
mods/example/traveling_merchant/data/locations.json
```

locks Sable's room unless this global flag is true:

```text
example:sable_house_open
```

By default that flag is not set, so the player cannot enter Sable's room.
