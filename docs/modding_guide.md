# Omni-Framework Modding Guide

This guide is written against the current `main` branch layout and base content in the repository. It is meant to be a practical, drop-in replacement for `docs/modding_guide.md`.

## What Omni-Framework expects right now

Omni-Framework is a data-driven Godot 4.6 framework. The engine owns the runtime systems and UI shell; mods provide content through JSON and optional scripts.

A few rules matter immediately:

- The engine always requires a valid base pack at `mods/base/`.
- The base pack manifest must use `"id": "base"` and `"load_order": 0`.
- Mods load in **two phases**:
  1. additions
  2. patches
- Backend payloads are validated at load time through `BackendContractRegistry`.
- `game.starting_player_id` should point at a real entity id.
- `locations.connections` currently uses the object form `{ "location_id": travel_cost }`.
- In practice, **location screens** currently use `display_name`, while **entity interactions** currently use `label`.

---

## 1. Mod folder layout

Regular mods live under:

```text
mods/<author_id>/<mod_id>/
├── mod.json
├── data/
│   ├── definitions.json
│   ├── parts.json
│   ├── entities.json
│   ├── locations.json
│   ├── factions.json
│   ├── tasks.json
│   ├── quests.json
│   ├── recipes.json
│   ├── achievements.json
│   └── config.json
├── dialogue/
├── scripts/
└── assets/
```

The built-in base pack is the only exception. It lives directly at:

```text
mods/base/
```

---

## 2. Manifest format (`mod.json`)

Current required fields:

```json
{
  "id": "my_name:my_mod",
  "name": "My Cool Mod",
  "version": "1.0.0",
  "schema_version": 1,
  "load_order": 100,
  "enabled": true,
  "dependencies": ["base"]
}
```

### Required fields
- `id` — string, non-empty, unique
- `name` — string, non-empty
- `version` — string, non-empty
- `load_order` — integer

### Optional fields
- `schema_version` — integer
- `enabled` — boolean, defaults to `true`
- `dependencies` — array of mod ids

### Important behavior
- Duplicate mod ids are skipped.
- Missing dependencies cause a mod to be skipped.
- Dependency order is enforced even if `load_order` is lower.
- The base mod:
  - must be enabled
  - must use `id: "base"`
  - must use `load_order: 0`
  - cannot declare dependencies

---

## 3. ID conventions

Use namespaced ids everywhere for anything your mod owns:

```text
author_id:mod_id:object_name
```

Examples:

```text
my_name:my_mod:plasma_rifle
my_name:my_mod:street_doc
my_name:my_mod:back_alley
```

Recommended style:
- lowercase
- colon-separated namespace
- underscores for multi-word names inside a segment

Examples:
- `my_name:my_mod:energy_blade`
- `my_name:my_mod:repair_bench`

Do not use the `base:` namespace unless you are explicitly patching or referencing base content.

---

## 4. Load pipeline

The current loader does this:

### Phase 1: additions
Each mod's `data/` folder is scanned and additions are registered into `DataManager`.

### Phase 2: patches
Each mod's `data/` folder is scanned again and patches are applied after all additions are known.

That means:
- Mod B can patch content added by Mod A
- patches are safest for balance overrides and compatibility edits
- foundational content should load earlier
- compatibility/balance mods should usually load later

---

## 5. Supported data files

The current base pack uses these files:

- `definitions.json`
- `parts.json`
- `entities.json`
- `locations.json`
- `factions.json`
- `tasks.json`
- `quests.json`
- `recipes.json`
- `achievements.json`
- `config.json`

If a file is omitted in your mod, that system is simply untouched.

---

## 6. `definitions.json`

Use this file to declare recognized currencies and stat metadata.

### Current shape

```json
{
  "currencies": ["credits", "data_shards"],
  "stats": [
    {
      "id": "power",
      "kind": "flat",
      "default_value": 0,
      "ui_group": "combat"
    },
    {
      "id": "health",
      "kind": "resource",
      "paired_capacity_id": "health_max",
      "default_value": 100,
      "default_capacity_value": 100,
      "clamp_min": 0,
      "ui_group": "survival"
    },
    {
      "id": "health_max",
      "kind": "capacity",
      "paired_base_id": "health",
      "default_value": 100,
      "clamp_min": 0,
      "ui_group": "survival"
    }
  ]
}
```

### Notes
- `currencies` is a flat array of recognized currency ids.
- `stats` is currently object-based, not just string-based.
- Resource/capacity pairs should be declared together.
- Use:
  - `kind: "flat"`
  - `kind: "resource"`
  - `kind: "capacity"`

### Recommended rule
If you create a resource stat like `energy`, also create `energy_max`.

---

## 7. `parts.json`

Parts are the core content building blocks. They can represent equipment, modules, upgrades, anatomy parts, ship parts, or any attachable component.

### Current addition format

```json
{
  "parts": [
    {
      "id": "my_name:my_mod:plasma_rifle",
      "display_name": "Plasma Rifle",
      "description": "A high-energy longarm built for modular combat loadouts.",
      "tags": ["weapon", "ranged", "energy"],
      "price": {
        "credits": 250
      },
      "stats": {
        "power": 4
      },
      "equippable": true,
      "provides_sockets": [
        {
          "id": "mod_slot",
          "accepted_tags": ["weapon_mod"],
          "label": "Mod Slot"
        }
      ],
      "customizable": true,
      "custom_field_labels": ["Callsign"],
      "custom_fields": [
        {
          "id": "finish_color",
          "label": "Finish Color",
          "type": "color_name",
          "default_value": "red",
          "options": ["red", "blue", "black"]
        }
      ],
      "script_path": "res://mods/my_name/my_mod/scripts/plasma_rifle.gd"
    }
  ]
}
```

### Common fields
- `id`
- `display_name`
- `description`
- `tags`
- `required_tags`
- `price`
- `stats`
- `equippable`
- `provides_sockets`
- `customizable`
- `custom_field_labels`
- `custom_fields`
- `sprite`
- `ui_color`
- `equip_sound`
- `script_path`

`sprite` can point directly at imported image assets such as `.png` files inside your mod's `assets/` folder.

`required_tags` lists tags that must be present on other currently equipped parts for this part to remain equipped. If a required provider is removed, the engine automatically unequips dependent parts and returns them to inventory. For example, arms can require `torso`, hands can require `arms`, and an implant can require `head`.

`custom_fields` declares instance-level values a part can carry. Each field should have an `id`, `label`, `type`, and optional `default_value` / `options`. Runtime instances store actual values in `custom_values`, either from the template defaults or from an entity inventory entry:

```json
{
  "instance_id": "player_head_001",
  "template_id": "base:human_head",
  "custom_values": {
    "eye_color": "green",
    "hair_color": "black"
  }
}
```

### Socket shape

```json
{
  "id": "mod_slot",
  "accepted_tags": ["weapon_mod"],
  "label": "Mod Slot"
}
```

### Current patch format

```json
{
  "patches": [
    {
      "target": "base:test_weapon",
      "add_tags": ["energy"],
      "set_stats": {
        "power": 5
      },
      "set": {
        "description": "Updated by my mod."
      }
    }
  ]
}
```

Use patches for:
- `add_tags`
- `remove_tags`
- `add_required_tags`
- `add_sockets`
- `remove_socket_ids`
- `set_stats`
- `set`

---

## 8. `entities.json`

Entities are the live actors and containers in the game. Players, NPCs, shops, companion units, vehicles, and even abstract holders can all be entities.

### Current addition format

```json
{
  "entities": [
    {
      "entity_id": "my_name:my_mod:street_doc",
      "display_name": "Street Doc",
      "description": "A black-market technician with limited stock.",
      "location_id": "my_name:my_mod:back_alley",
      "currencies": {
        "credits": 1200
      },
      "stats": {
        "charisma": 3,
        "health": 100,
        "health_max": 100
      },
      "flags": {
        "met_player": false
      },
      "inventory": [
        {
          "instance_id": "street_doc_implant_001",
          "template_id": "my_name:my_mod:optic_implant",
          "condition": 1.0
        }
      ],
      "interactions": [
        {
          "tab_id": "street_doc_trade",
          "label": "Trade",
          "backend_class": "ExchangeBackend",
          "source_inventory": "entity:my_name:my_mod:street_doc",
          "destination_inventory": "player",
          "currency_id": "credits"
        }
      ]
    }
  ]
}
```

### Important current details
- Entity ids use `entity_id`
- New games instantiate authored non-player entities into runtime state, so location presence and entity interactions can resolve live entity inventories/stats
- Inventory holds **instances**, not just template ids
- Interactions currently use **`label`**
- `target_entity_id: "player"` is accepted by several backends as a convenience alias
- Full ids like `base:player` are still safest in authored data outside backend convenience fields

### Inventory instance shape

```json
{
  "instance_id": "unique_copy_id",
  "template_id": "my_name:my_mod:plasma_rifle",
  "condition": 1.0
}
```

### Useful entity fields
- `currencies`
- `stats`
- `flags`
- `reputation`
- `discovered_locations`
- `provides_sockets`
- `inventory`
- `assembly_socket_map`
- `assembly_instance_ids`
- `owned_entity_ids`
- `interactions`
- `portrait`
- `portrait_id`
- `sprite`

Entity-facing UI such as `EntityPortrait` can render optional portrait/emblem art from `portrait`, `portrait_id`, or `sprite` when those fields are present.

### Current patch example

```json
{
  "patches": [
    {
      "target": "base:test_vendor",
      "add_inventory": [
        {
          "instance_id": "my_name:my_mod:vendor_stock_001",
          "template_id": "my_name:my_mod:plasma_rifle",
          "condition": 1.0
        }
      ],
      "add_interactions": [
        {
          "tab_id": "vendor_sheet",
          "label": "Inspect",
          "backend_class": "EntitySheetBackend",
          "target_entity_id": "base:test_vendor"
        }
      ],
      "set": {
        "display_name": "Quartermaster Theta+"
      }
    }
  ]
}
```

---

## 9. `locations.json`

Locations are graph nodes plus UI entry points.

### Current addition format

```json
{
  "locations": [
    {
      "location_id": "my_name:my_mod:back_alley",
      "display_name": "Back Alley",
      "description": "A cramped maintenance corridor lit by dying signage.",
      "connections": {
        "base:test_hub": 2
      },
      "screens": [
        {
          "tab_id": "back_alley_sheet",
          "display_name": "Player Sheet",
          "description": "Review current stats and loadout.",
          "backend_class": "EntitySheetBackend",
          "target_entity_id": "player"
        }
      ],
      "entities_present": [
        "my_name:my_mod:street_doc"
      ]
    }
  ]
}
```

### Important current details
- Location ids use `location_id`
- Connections currently use the object form:
  ```json
  { "base:test_hub": 2 }
  ```
- Location screens currently use **`display_name`**, not `label`
- `entities_present` is rendered by the gameplay location surface. Each listed entity can expose its own `interactions` buttons.

### Current patch example

```json
{
  "patches": [
    {
      "target": "base:test_hub",
      "add_connections": {
        "my_name:my_mod:back_alley": 2
      },
      "add_screens": [
        {
          "tab_id": "alley_access",
          "display_name": "Visit Back Alley",
          "description": "Open the alley services.",
          "backend_class": "EntitySheetBackend",
          "target_entity_id": "player"
        }
      ]
    }
  ]
}
```

---

## 10. `factions.json`

Factions group entities, territory, tasks, and reputation thresholds.

### Current addition format

```json
{
  "factions": [
    {
      "faction_id": "my_name:my_mod:night_clinic",
      "display_name": "Night Clinic",
      "description": "Independent med-techs operating outside official channels.",
      "faction_color": "#6dd3ff",
      "territory": ["my_name:my_mod:back_alley"],
      "roster": ["my_name:my_mod:street_doc"],
      "reputation_thresholds": {
        "allied": 100,
        "friendly": 25,
        "neutral": 0,
        "hostile": -25
      },
      "quest_pool": ["my_name:my_mod:delivery_run"]
    }
  ]
}
```

Useful optional faction art fields:
- `emblem_path`
- `emblem_id`
- `icon_id`
- `portrait_id`

Faction-facing UI such as `FactionBadge` resolves emblem art from those fields when provided.

---

## 11. `tasks.json`

Tasks are time-based operations.

### Current addition format

```json
{
  "task_templates": [
    {
      "template_id": "my_name:my_mod:delivery_run",
      "type": "DELIVER",
      "target": "my_name:my_mod:back_alley",
      "travel_cost": 2,
      "reward": {
        "credits": 80,
        "reputation": {
          "my_name:my_mod:night_clinic": 10
        }
      },
      "description": "Deliver parts to the clinic.",
      "difficulty": 1,
      "repeatable": true
    }
  ]
}
```

### Current task types referenced in the existing guide
- `BUILD`
- `FIGHT`
- `DELIVER`
- `TRAVEL`
- `SURVIVE`
- `WAIT`
- `CRAFT`

Use:
- `travel_cost` for travel-based tasks
- `duration` for pure timed waits/crafting
- `reward` for currencies, reputation, and other rewards

---

## 11.5 `recipes.json`

Recipes are inventory-driven crafting templates loaded by `RecipeRegistry` into `DataManager.recipes`.

### Current addition format

```json
{
  "recipes": [
    {
      "recipe_id": "my_name:my_mod:iron_grip",
      "display_name": "Iron Grip",
      "description": "Turns salvage into a usable arm mod.",
      "output_template_id": "my_name:my_mod:iron_grip_part",
      "output_count": 1,
      "inputs": [
        { "template_id": "my_name:my_mod:salvage_chip", "count": 2 }
      ],
      "required_stations": ["my_name:my_mod:workbench"],
      "required_stats": { "power": 1 },
      "required_flags": [],
      "craft_time_ticks": 0,
      "discovery": "always",
      "tags": ["arm_mod"]
    }
  ],
  "patches": []
}
```

`CraftingBackend` requires `station_id`; optional `recipe_tags` and `recipe_ids` filter visible recipes. The backend rechecks those filters, station requirements, and discovery state when craft is confirmed, so a recipe that is not visible from the current station cannot be crafted by stale UI state. Instant recipes produce output immediately. Recipes with `craft_time_ticks > 0` consume inputs immediately and start the generic `base:recipe_craft` timed task, which grants the output when completed.

Supported discovery modes are `always`, `learned_on_flag`, and `auto_on_ingredient_owned`.

`required_stations`, `required_flags`, and `tags` must contain non-empty strings. `required_stats` values must be numeric so stat gates fail validation instead of becoming implicit zero-value requirements.

---

## 12. `quests.json`

Quests are progression/state-tracking structures.

### Current addition format

```json
{
  "quests": [
    {
      "quest_id": "my_name:my_mod:clinic_intro",
      "display_name": "First Visit",
      "description": "Reach the clinic and gear up.",
      "stages": [
        {
          "description": "Obtain any weapon.",
          "objectives": [
            {
              "type": "has_item_tag",
              "tag": "weapon",
              "count": 1
            }
          ]
        },
        {
          "description": "Reach the alley clinic.",
          "objectives": [
            {
              "type": "reach_location",
              "location_id": "my_name:my_mod:back_alley"
            }
          ]
        }
      ],
      "reward": {
        "credits": 150
      },
      "repeatable": false
    }
  ]
}
```

### Objective types confirmed by current base content and guide
- `has_item_tag`
- `reach_location`

---

## 13. `achievements.json`

Achievements track milestone stats.

### Current addition format

```json
{
  "achievements": [
    {
      "achievement_id": "my_name:my_mod:first_implant",
      "display_name": "Augmented",
      "description": "Install your first implant.",
      "stat_name": "items_bought",
      "requirement": 1
    }
  ]
}
```

Common fields:
- `achievement_id`
- `display_name`
- `description`
- `stat_name`
- `requirement`
- `icon`
- `unlock_sound`
- `unlock_vfx`
- `hidden`

---

## 14. `config.json`

`config.json` is deep-merged into the current config.

### Current base pack example areas
- `game`
- `ui`
- `stats`

### Example

```json
{
  "game": {
    "title": "My Total Conversion",
    "tagline": "A new world built on Omni-Framework.",
    "starting_player_id": "base:player",
    "starting_location": "my_name:my_mod:back_alley",
    "starting_money": {
      "credits": 300
    }
  },
  "ui": {
    "strings": {
      "base_pack_label": "My conversion loaded"
    }
  },
  "stats": {
    "groups": {
      "combat": ["power"],
      "social": ["charisma"]
    }
  }
}
```

### Important current notes
- `game.starting_player_id` is required and must point at a valid entity id
- `game.starting_location` should be a valid location id when provided
- `game.starting_discovered_locations` must be an array of valid location ids when provided; include any connected locations that should be available in the first travel view
- `starting_money` uses the currencies you declared in `definitions.json`
- `game.ticks_per_day` and `game.ticks_per_hour` must be positive integers when provided
- `ui.time_advance_buttons` must be an array of labels ending in `tick(s)`, `hour(s)`, or `day(s)` when provided, such as `"1 hour"` or `"1 day"`
- The current base content also defines `game.new_game_flow`, which means the startup flow can be configured through data instead of hardcoding it all in scripts

---

## 15. Backends currently registered by the loader

The current loader registers these backend classes:

- `AssemblyEditorBackend`
- `ExchangeBackend`
- `ListBackend`
- `ChallengeBackend`
- `TaskProviderBackend`
- `CatalogListBackend`
- `DialogueBackend`
- `EntitySheetBackend`
- `ActiveQuestLogBackend`
- `FactionReputationBackend`
- `AchievementListBackend`
- `EventLogBackend`
- `WorldMapBackend`

If you reference an unknown `backend_class`, load validation will fail.

### Confirmed required params

#### `ExchangeBackend`
Required:
- `source_inventory`
- `destination_inventory`
- `currency_id`

Example:
```json
{
  "tab_id": "street_doc_trade",
  "label": "Trade",
  "backend_class": "ExchangeBackend",
  "source_inventory": "entity:my_name:my_mod:street_doc",
  "destination_inventory": "player",
  "currency_id": "credits"
}
```

#### `TaskProviderBackend`
Required:
- `faction_id`

#### `DialogueBackend`
Required:
- `dialogue_resource`

#### `ChallengeBackend`
Required:
- `required_stat`
- `required_value`

#### `CatalogListBackend`
Required in practical use:
- `data_source`
- `action_payload`

Useful optional fields:
- `currency_id`
- `price_modifier`
- `transaction_sound`
- `buyer_entity_id`

#### `WorldMapBackend`
No required params. Common useful optional fields:
- `screen_title`
- `screen_description`
- `cancel_label`
- `empty_label`
- `show_travel_costs`
- `discovered_only`

The map reads `locations.json` through `LocationGraph.get_all_locations()`. A location may optionally provide `map_position` as `{ "x": 0.5, "y": 0.5 }` or `[0.5, 0.5]` using normalized graph coordinates. If omitted, the screen places nodes in a deterministic circular layout. Node tint comes from a location's `faction_id` when present, or from the first faction whose `territory` includes that location. The runtime screen also provides route lines, mouse-wheel zoom, drag panning, fit/current centering controls, and radial/horizontal/vertical orientation modes. Traveling from the map consumes the cheapest routed total `travel_cost` in ticks; unreachable destinations are rejected instead of free-teleporting.

#### `AssemblyEditorBackend`
No required params, but common useful ones are:
- `target_entity_id`
- `budget_entity_id`
- `budget_currency_id`
- `payment_recipient_id`
- `option_source_entity_id`
- `option_tags`
- `option_template_ids`
- `screen_title`
- `screen_description`
- `screen_summary`
- `confirm_label`
- `cancel_label`
- `next_screen_id`
- `cancel_screen_id`
- `reset_game_state_on_cancel`
- `allow_confirm_without_changes`

`option_source_entity_id` changes the option list from a template catalog to exact inventory part instances. When the source entity resolves to the same runtime entity as `target_entity_id` (for example `player` building from their own inventory), applying a part moves that owned instance into the slot and does not spend currency. When the source is a different entity, pair it with `payment_recipient_id` for a vendor-style install; the source instance is removed, the exact instance is equipped on the target, and currency is transferred during the same staged commit.

### Two important authored-data distinctions

#### Entity interaction shape
Entity interactions use:
```json
{
  "tab_id": "vendor_trade",
  "label": "Trade",
  "backend_class": "ExchangeBackend"
}
```

#### Location screen shape
Location screens use:
```json
{
  "tab_id": "hub_sheet",
  "display_name": "Player Sheet",
  "backend_class": "EntitySheetBackend"
}
```

That mismatch is easy to miss and is one of the biggest practical gotchas in the current data.

---

## 16. Dialogue

Current entity interactions can launch `DialogueBackend` with a Dialogue Manager resource.
When a `DialogueBackend` interaction is rendered from an entity's `interactions` list, the gameplay location surface uses that entity as `speaker_entity_id` unless the interaction explicitly supplies another speaker.

Example:

```json
{
  "tab_id": "theta_talk",
  "label": "Talk",
  "backend_class": "DialogueBackend",
  "dialogue_resource": "res://mods/my_name/my_mod/dialogue/my_npc.dialogue",
  "dialogue_start": "start"
}
```

Recommended folder:

```text
mods/<author>/<mod>/dialogue/
```

---

## 17. Script hooks

Optional custom behavior can be attached with `script_path`.

Example on a part:

```json
{
  "id": "my_name:my_mod:plasma_rifle",
  "display_name": "Plasma Rifle",
  "description": "A rifle with a custom hook.",
  "tags": ["weapon"],
  "price": { "credits": 200 },
  "equippable": true,
  "script_path": "res://mods/my_name/my_mod/scripts/plasma_rifle.gd"
}
```

Base hook class:
```gdscript
extends ScriptHook
```

Hook methods currently exposed by the base class include:
- `on_equip`
- `on_unequip`
- `on_tick`
- `on_quest_start`
- `on_quest_complete`
- `on_quest_fail`
- `on_location_enter`
- `on_location_exit`
- `on_task_start`
- `on_task_complete`

There is also a helper:
- `generate_ai_async(prompt, context = {})`

Use script hooks sparingly. Prefer JSON first.

---

## 18. Common mistakes to avoid

### 1. Using the wrong screen label field
- location screens: `display_name`
- entity interactions: `label`

### 2. Using old connection shapes
Use:
```json
"connections": {
  "base:test_hub": 1
}
```

Not older list-based or split forms.

### 3. Forgetting full ids in references
When pointing at content, use actual ids:
- `base:player`
- `base:test_hub`
- `my_name:my_mod:street_doc`

### 4. Missing required backend params
`backend_class` is validated. Missing fields fail early.

### 5. Forgetting dependencies
If your mod patches another mod, declare that mod in `dependencies`.

### 6. Reusing instance ids
Entity inventory entries are instances. Each copy needs its own `instance_id`.

### 7. Treating base content as special in format
The base pack is special in location, but not in validation. Its data still has to pass the same rules.

---

## 19. Minimal working example mod

### `mod.json`
```json
{
  "id": "my_name:starter_plus",
  "name": "Starter Plus",
  "version": "1.0.0",
  "schema_version": 1,
  "load_order": 100,
  "enabled": true,
  "dependencies": ["base"]
}
```

### `data/parts.json`
```json
{
  "parts": [
    {
      "id": "my_name:starter_plus:training_blade",
      "display_name": "Training Blade",
      "description": "A simple starter weapon.",
      "tags": ["weapon", "melee"],
      "price": {
        "credits": 45
      },
      "stats": {
        "power": 2
      },
      "equippable": true
    }
  ]
}
```

### `data/entities.json`
```json
{
  "patches": [
    {
      "target": "base:test_vendor",
      "add_inventory": [
        {
          "instance_id": "starter_plus_vendor_blade_001",
          "template_id": "my_name:starter_plus:training_blade",
          "condition": 1.0
        }
      ]
    }
  ]
}
```

That is enough to add one new sellable item into the existing base vendor flow.

---

## 20. Practical workflow for authors

1. Start from a tiny mod.
2. Add only one system at a time.
3. Prefer additions first.
4. Add patches only when needed.
5. Test with base content still enabled.
6. Keep ids namespaced and references explicit.
7. When a backend fails, check the payload shape first.

---

## 21. Recommended next docs to check in this repo

For deeper implementation detail, also review:
- `docs/PROJECT_STRUCTURE.md`
- `docs/SCHEMA_AND_LINT_SPEC.md`
- `docs/STAT_SYSTEM_IMPLEMENTATION.md`

If your mod needs custom behavior, also inspect:
- `core/script_hook.gd`
- backend scripts under `ui/screens/backends/`
- loader logic in `autoloads/mod_loader.gd`

---

## 22. Final sanity checklist

Before shipping a mod, verify:

- `mod.json` has a unique `id`
- dependencies are declared
- all ids are namespaced
- `starting_player_id` references a real entity
- `starting_discovered_locations` contains only valid location ids if present
- `connections` use object form
- entity interactions use `label`
- location screens use `display_name`
- every inventory instance id is unique
- every referenced part/entity/location/faction/task/quest actually exists
- every backend payload includes its required fields

If those pass, your mod is aligned with the current repo much more closely than the older guide.
