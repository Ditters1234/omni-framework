# Task Routines

`TaskRoutineRunner` starts existing task templates at configured in-game ticks. It is intended for simple daily routines such as wandering merchants, guards, couriers, or NPCs that move between locations on a predictable schedule.

The runner does **not** move entities directly. It starts `TaskRunner` tasks, usually `TRAVEL` tasks, and `TaskRunner` performs the movement when the task completes.

## Important Godot naming note

The autoload singleton is named:

```ini
TaskRoutineRunner="*res://systems/task_routine_runner.gd"
```

The script class is named:

```gdscript
class_name OmniTaskRoutineRunner
```

Do not rename the script class to `TaskRoutineRunner`; Godot will report:

```text
Class "TaskRoutineRunner" hides an autoload singleton.
```

## Travel duration

Routine JSON does **not** need hard-coded travel duration.

When an entry starts a `TRAVEL` task and no `duration` or `remaining_ticks` is supplied, `TaskRoutineRunner` resolves travel duration with:

```gdscript
LocationGraph.get_route_travel_cost(entity.location_id, target_location_id)
```

This is the same routed cost source used by the world map backend.

## Flow

```text
TimeKeeper tick
  -> TaskRoutineRunner checks configured routine entries
  -> TaskRoutineRunner starts a task
  -> TaskRunner counts down the task
  -> TaskRunner moves the entity when complete
```

## Config schema

Add `task_routines` to any loaded config JSON:

```json
{
  "task_routines": [
    {
      "routine_id": "base:merchant_daily_route",
      "entity_id": "base:wandering_merchant",
      "loop": "daily",
      "entries": [
        {
          "tick": 6,
          "task_template_id": "base:merchant_to_market"
        },
        {
          "tick": 12,
          "task_template_id": "base:merchant_to_warehouse"
        },
        {
          "tick": 18,
          "task_template_id": "base:merchant_go_home"
        }
      ]
    }
  ]
}
```

`loop` currently supports only:

```json
"daily"
```

## Entry fields

| Field | Required | Purpose |
|---|---:|---|
| `tick` / `at_tick` / `tick_into_day` | Yes | Tick within the current day when the task should start |
| `task_template_id` / `template_id` | Yes | Task template to start |
| `target` | No | Overrides the task template target |
| `duration` | No | Overrides routed travel cost |
| `remaining_ticks` | No | Alias for starting countdown value |
| `task_type` | No | Overrides task type; normally not needed |
| `reward` | No | Overrides reward payload |
| `complete_sound` | No | Overrides completion sound |
| `allow_duplicate` | No | Defaults to `true`; prevents global template collision from blocking different routine entries |

## Example merchant travel tasks

No `travel_cost` is needed here if the target is connected through `locations.json`.

```json
{
  "task_templates": [
    {
      "template_id": "base:merchant_to_market",
      "type": "TRAVEL",
      "target": "base:market_row",
      "repeatable": true,
      "reward": {}
    },
    {
      "template_id": "base:merchant_to_warehouse",
      "type": "TRAVEL",
      "target": "base:warehouse",
      "repeatable": true,
      "reward": {}
    },
    {
      "template_id": "base:merchant_go_home",
      "type": "TRAVEL",
      "target": "base:merchant_house",
      "repeatable": true,
      "reward": {}
    }
  ]
}
```

## Important behavior

Each routine entry starts at most once per in-game day. This prevents duplicate task creation if the current screen or a test calls evaluation more than once on the same tick.

## House lockout

To prevent the player from entering a private NPC location (such as a home), use `LocationAccessService` entry conditions on the location:

```json
{
  "location_id": "base:merchant_house",
  "display_name": "Merchant's Room",
  "locked_message": "The merchant's door is locked.",
  "entry_condition": {
    "type": "has_flag",
    "flag_id": "base:merchant_house_open",
    "value": true
  },
  "connections": {
    "base:market_row": 1
  }
}
```

Both the gameplay location travel buttons and the world map backend check `LocationAccessService` before allowing travel. See `docs/LOCATION_ACCESS.md` for full condition shapes.

The example mod at `mods/example/traveling_merchant/` demonstrates this pattern with Sable's locked room.
