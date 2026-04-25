# Traveling Merchant Mod

Adds **Sable the Peddler**, a simple NPC merchant who moves on a daily schedule:

| Tick | Action |
|---:|---|
| 6 | Travels from `example:merchant_house` to `base:market_row` |
| 12 | Travels to `base:warehouse` |
| 18 | Travels home to `example:merchant_house` |

## Requires

This mod expects your project to include the `TaskRoutineRunner` system from the earlier drop-in zip.

Specifically, the project needs:

```ini
TaskRoutineRunner="*res://systems/task_routine_runner.gd"
```

and `systems/task_routine_runner.gd`.

## Install

Copy the included `mods/example/traveling_merchant/` folder into your project at:

```text
res://mods/example/traveling_merchant/
```

Then run the project.

## What it adds

- New entity:
  - `example:traveling_merchant`
- New private location:
  - `example:merchant_house`
- New travel task templates:
  - `example:sable_to_market`
  - `example:sable_to_warehouse`
  - `example:sable_go_home`
- New daily routine:
  - `example:sable_daily_route`

## Notes

Travel duration is not hard-coded in the routine. `TaskRoutineRunner` resolves it from `LocationGraph.get_route_travel_cost(...)`.

Sable's house is connected to Market Row so route cost can be calculated. The current mod does not yet prevent the player from entering the house; that needs a travel-gate/condition system.
