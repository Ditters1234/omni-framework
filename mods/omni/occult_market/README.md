# Occult Market

This addon adds a small High Street component vendor and recipe chain.

## What This Teaches

- `data/entities.json`: exact vendor inventory with `ExchangeBackend` interactions.
- `data/parts.json`: ritual components, study cards, and consumable support items.
- `data/recipes.json`: always-known and learned-on-flag crafting recipes.
- `data/activities.json`: an activity that unlocks a recipe through the `learn_recipe` action.
- `data/locations.json`: patching a base location with addon screens.

## Buying

Nix stocks exact inventory items in `entities.json`. The added High Street exchange screen buys from `entity:omni:occult_market:shopkeeper_nix`, so players purchase the vendor's actual component instances rather than an infinite catalog template.

## Crafting

The Market Workbench screen filters recipes tagged `occult_market`. `omni:occult_market:bind_market_chalk` is visible immediately and turns addon components into base ritual chalk. `omni:occult_market:assemble_circle_kit` is hidden until the player learns it.

## Unlocking

The Market Recipe Card item can be used from inventory, and the Read Market Recipe Card activity can be completed on High Street. Both teach the circle-kit recipe with normal data-authored actions.

## Assets

This addon includes local placeholder sprites and sounds under `assets/`. They are copied from current Vanguard base placeholders while final market art and audio are still in progress.
