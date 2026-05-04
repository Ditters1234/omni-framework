# Omni-Framework Modding Guide

This guide is written against the current `main` branch layout and base content in the repository.

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
│   ├── encounters.json
│   ├── achievements.json
│   └── config.json
├── dialogue/
├── scripts/
└── assets/
```

AI-aware mods can also add `data/ai_personas.json` and `data/ai_templates.json` to the same folder.

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
- `encounters.json`
- `achievements.json`
- `ai_personas.json`
- `ai_templates.json`
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
- `custom_field_labels`
- `custom_fields`
- `sprite`
- `equip_sound`
- `script_path`

`sprite` can point directly at imported image assets such as `.png` files inside your mod's `assets/` folder.

`equip_sound` can point at a one-shot audio resource such as a `.wav` or `.ogg`. When a committed assembly change equips that part into a slot, the engine plays that sound through `AudioManager.play_sfx()`.

`required_tags` lists tags that must be present on other currently equipped parts for this part to remain equipped. If a required provider is removed, the engine automatically unequips dependent parts and returns them to inventory. For example, arms can require `torso`, hands can require `arms`, and an implant can require `head`.

`custom_fields` declares instance-level values a part can carry. Each field should have an `id`, `label`, `type`, and optional `default_value` / `options`. Runtime instances store actual values in `custom_values`, either from the template defaults or from an entity inventory entry:

```json
{
  "instance_id": "player_head_001",
  "template_id": "base:human_head_male",
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
          "template_id": "my_name:my_mod:optic_implant"
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
  "template_id": "my_name:my_mod:plasma_rifle"
}
```

Inventory entries may also include `custom_values` to override template-declared custom field defaults:

### Useful entity fields
- `currencies`
- `stats`
- `flags`
- `ai_persona_id`
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

`owned_entity_ids` now round-trips through `EntityInstance` runtime/save serialization even though the base UI does not currently render a dedicated ownership view.

`ai_persona_id` is optional. When present, it must reference a valid persona from `ai_personas.json`. On its own it does not turn on AI dialogue yet; it only binds authored persona data to the entity for AI-aware systems to consume.

### Current patch example

```json
{
  "patches": [
    {
      "target": "base:test_vendor",
      "add_inventory": [
        {
          "instance_id": "my_name:my_mod:vendor_stock_001",
          "template_id": "my_name:my_mod:plasma_rifle"
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

## 8.1 `ai_personas.json`

AI personas are authored prompt-shaping templates loaded by `AIPersonaRegistry` into `DataManager.ai_personas`.

### Current addition format

```json
{
  "ai_personas": [
    {
      "persona_id": "my_name:my_mod:street_doc_persona",
      "display_name": "Street Doc",
      "system_prompt_template": "You are {display_name}, {description}. Stay focused on clinic work and local rumors.",
      "personality_traits": ["practical", "guarded"],
      "speech_style": "Short, clinical answers with occasional sarcasm.",
      "knowledge_scope": ["implants", "black_market", "clinic"],
      "forbidden_topics": ["supplier_names"],
      "response_constraints": {
        "max_sentences": 3,
        "tone": "conversational",
        "always_in_character": true
      },
      "fallback_lines": [
        "Not discussing that.",
        "Ask me about the work, not the rumors."
      ],
      "tags": ["merchant", "doctor"]
    }
  ]
}
```

### Important current details
- Persona ids use `persona_id`
- `persona_id`, `display_name`, and `system_prompt_template` are required
- `personality_traits`, `knowledge_scope`, `forbidden_topics`, `fallback_lines`, and `tags` must be arrays of non-empty strings when present
- `response_constraints` must be an object when present
- `response_constraints.max_sentences` must be a positive integer when present
- `response_constraints.tone` must be a non-empty string when present
- `response_constraints.always_in_character` must be a bool when present
- Entities bind to personas through `entities.json` via `ai_persona_id`

### Prompt template tokens

`system_prompt_template` can currently reference these runtime tokens:
- `{display_name}`
- `{description}`
- `{location_name}`
- `{faction_name}`
- `{reputation_tier}`
- `{player_name}`
- `{player_stats}`
- `{time_of_day}`
- `{active_quests}`
- `{knowledge_block}`

Unknown tokens are left in place and logged as warnings, so it is worth keeping templates small and explicit while iterating.

### Authoring tips

- Use `system_prompt_template` for the NPC's job, role, and baseline framing, not for long prose.
- Use `personality_traits` for stable identity words like `guarded`, `clinical`, or `reckless`.
- Use `speech_style` for sentence rhythm and voice. This is the best place to say things like "short sarcastic answers" or "measured formal speech."
- Keep `knowledge_scope` narrow. It is there to anchor what the NPC should know about, not to dump the whole setting into the prompt.
- Set `response_constraints.max_sentences` aggressively. Shorter answers are cheaper, more stable, and easier to fit beside authored dialogue.
- Use `forbidden_topics` for things the character should deflect, not for broad safety policy.

### Fallback line guidelines

- Write fallback lines in the same voice as the NPC, because players will see them when AI is unavailable or validation rejects a reply.
- Include at least one neutral "I don't want to answer that" line and one redirect line that points back to the NPC's domain.
- Avoid generic assistant phrasing. A good fallback should still feel like authored character dialogue.

### Engine-owned tuning

Persona JSON does not control provider selection or connection details. The engine-owned settings screen now exposes:
- `ai.chat_history_window` — how many recent turns each NPC keeps in memory
- `ai.streaming_speed` — the dialogue-side token reveal cadence
- `ai.enable_world_gen` — whether world-generation hooks may surface narrated event log text and task-board flavor

Those settings live in `user://settings.cfg`, not in mod data.

### Current patch format

```json
{
  "patches": [
    {
      "target": "base:kael_persona",
      "set": {
        "speech_style": "Warmer, but still concise."
      },
      "add_tags": ["quest_giver"],
      "remove_tags": ["merchant"]
    }
  ]
}
```

---

## 8.2 `ai_templates.json`

World-generation hooks can also read reusable prompt templates from `data/ai_templates.json`. These load through `AITemplateRegistry` into `DataManager.ai_templates`.

Current addition format:

```json
{
  "ai_templates": [
    {
      "template_id": "my_name:my_mod:task_flavor",
      "purpose": "task_description",
      "prompt_template": "Write one mission-briefing sentence for {display_name} in {location_name}.",
      "fallback": "{display_name} awaits at {location_name}.",
      "tags": ["task_board"]
    }
  ],
  "patches": []
}
```

Current required fields:
- `template_id`
- `purpose`
- `prompt_template`

Current optional fields:
- `fallback`
- `tags`

Current patch format matches personas:

```json
{
  "patches": [
    {
      "target": "my_name:my_mod:task_flavor",
      "set": {
        "fallback": "The work is waiting."
      },
      "add_tags": ["world_gen"]
    }
  ]
}
```

The engine does not execute templates on its own. A hook or backend must look them up explicitly through `DataManager.get_ai_template()` or `query_ai_templates()`.

---

## 8.3 Behavior tree AI tasks

LimboAI behavior trees can now call the engine-owned AI layer directly through two custom tasks under `systems/ai/`.

- `BTActionAIQuery` resolves `{blackboard_var}` placeholders inside `prompt_template`, sends the request through `AIManager`, and writes the parsed result to `result_var`.
- `BTConditionAICheck` asks a yes/no question, appends a strict yes/no suffix to the prompt, and returns `SUCCESS` or `FAILURE` from the parsed answer.

### `BTActionAIQuery`

Current exported fields:
- `prompt_template` - prompt text with optional `{blackboard_var}` placeholders
- `result_var` - blackboard variable name that receives the parsed result
- `response_format` - `"text"`, `"enum"`, or `"json"`
- `enum_options` - required when `response_format` is `"enum"`
- `timeout_seconds` - timeout before the task fails and writes its fallback
- `fallback_value` - value written to `result_var` when AI is unavailable, times out, or fails parsing

Prompt placeholders are resolved from the active LimboAI blackboard. Missing variables are left in place and logged as warnings, so it is worth keeping templates explicit and blackboard setup predictable.

`response_format: "enum"` uses forgiving matching for common LLM drift:
- extra whitespace is ignored
- casing is ignored
- partial matches like `"full"` can still resolve to `full_price` when unambiguous

`response_format: "json"` expects a JSON object. Fenced ```json blocks are accepted, but malformed JSON causes the task to fail and write `fallback_value`.

### `BTConditionAICheck`

Current exported fields:
- `prompt_template`
- `default_result`
- `timeout_seconds`

The task automatically appends `Respond with only YES or NO.` unless the prompt already includes that instruction. It accepts common yes/no variants such as `YES.`, `y`, `no`, and `nah`. Ambiguous answers fall back to `default_result`.

### Example pattern

Use these tasks the same way the AI integration plan recommends: AI branch first, static branch second.

```text
Selector
  AIQuery greeting -> blackboard.greeting
  Set greeting = "Stick to business."
```

The first branch enhances behavior when AI is available. The second branch is the guaranteed fallback path when it is not.

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

### Entity presence at locations

The gameplay location surface resolves which NPCs appear at a location from three sources, merged and deduplicated:

1. **`entities_present`** — static list in `locations.json`. Always shows these entities at this location regardless of their runtime `location_id`.
2. **`DataManager.query_entities({"location_id": ...})`** — entities whose authored template has a matching `location_id`.
3. **`GameState.entity_instances`** — all runtime entity instances whose current `location_id` matches. This is the dynamic source — when a `TRAVEL` task completes and changes an entity's `location_id`, the entity appears at the new location automatically.

The player entity is always excluded from presence lists.

For static NPCs that never move, setting `location_id` on the entity template is enough. For NPCs that travel (via task routines or `TRAVEL` tasks), the runtime `location_id` on the entity instance is what the UI reads. Do **not** also add moving NPCs to any location's `entities_present` — that would cause the NPC to appear in two places simultaneously.

### Location entry conditions

Locations can be gated with conditions that must pass before the player can travel there. Both the gameplay location travel buttons and the world map backend check these conditions through `LocationAccessService`.

#### `entry_condition` — single condition (AND logic)

A single `ConditionEvaluator` dictionary. It must pass for entry to be allowed.

```json
{
  "location_id": "my_name:my_mod:vip_lounge",
  "display_name": "VIP Lounge",
  "locked_message": "Members only. You need a VIP pass.",
  "entry_condition": {
    "type": "has_flag",
    "flag_id": "my_name:my_mod:has_vip_pass",
    "value": true
  },
  "connections": {
    "my_name:my_mod:lobby": 1
  }
}
```

#### `entry_conditions` — multiple conditions (OR logic)

An array of `ConditionEvaluator` dictionaries. At least one must pass.

```json
"entry_conditions": [
  {
    "type": "has_flag",
    "flag_id": "my_name:my_mod:warehouse_key",
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

#### `locked_message`

Controls the text shown in the UI when travel is blocked. Defaults to `"You cannot enter this location right now."` if omitted.

All condition types from `ConditionEvaluator` work here — `has_flag`, `stat_check`, `has_item_tag`, `has_part`, `has_currency`, `reputation_threshold`, `quest_complete`, plus compound `AND`/`OR`/`NOT` blocks. See Section 12 (quests) for the full condition reference.

### `map_position` (world map layout)

Locations can declare their position on the world map using normalized coordinates:

```json
"map_position": { "x": 0.2, "y": 0.7 }
```

Or as an array:
```json
"map_position": [0.2, 0.7]
```

Values are normalized graph coordinates (0.0–1.0 range works well). If omitted, the world map places nodes in a deterministic circular layout. Node tint comes from a location's `faction_id` if present, or from the first faction whose `territory` includes that location.

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

Factions group entities, territory, contract quests, and reputation thresholds.

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
      "quest_pool": ["my_name:my_mod:delivery_contract"]
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

Tasks are time-based operations that entities perform. They are the low-level work queue for movement, waiting, crafting, routines, and other autonomous entity behavior. Player-facing work with objectives, completion notifications, and rewards should be authored as quests/contracts in `quests.json`.

### Current addition format

```json
{
  "task_templates": [
    {
      "template_id": "my_name:my_mod:worker_travel_to_clinic",
      "type": "TRAVEL",
      "target": "my_name:my_mod:back_alley",
      "travel_cost": 2,
      "reward": {},
      "description": "Move the assigned entity to the clinic.",
      "difficulty": 1,
      "repeatable": true
    }
  ]
}
```

### Task type behavior

The following types have special runtime handling in `TaskRunner`:
- `WAIT` — pure duration-based. Completes after `remaining_ticks` reaches 0.
- `CRAFT` — used internally by `CraftingBackend` for timed recipes. Completes after countdown.
- `DELIVER` / `TRAVEL` — completes after countdown (uses `travel_cost` from the template for duration). On completion, **moves the owning entity** to the `target` location. If the entity is the player, this calls `GameState.travel_to()` (which also updates discovered locations, fires `location_changed`, and invokes script hooks). If the entity is an NPC, it directly sets `entity.location_id`.

The following types are accepted but behave identically to `WAIT` (duration-based, no special logic):
- `BUILD`
- `FIGHT`
- `SURVIVE`

Modders can use any string as a task type; unrecognized types fall through to duration-based behavior.

### Duration resolution

`TaskRunner` resolves the task countdown in this order:
1. If `params.duration` or `params.remaining_ticks` is provided at accept time, use that.
2. If the task type is `DELIVER` or `TRAVEL`, use `template.travel_cost` (falls back to `balance.default_travel_cost_ticks` config).
3. Otherwise use `template.duration`.
4. Minimum duration is always 1 tick.

Use:
- `travel_cost` for travel-based tasks
- `duration` for pure timed waits/crafting
- `reward` only for low-level system payouts. Player-visible contract rewards should usually live on the quest/contract that the task helps complete.

---

## 11.1 Task routines (NPC schedules)

`TaskRoutineRunner` starts task templates at configured in-game ticks. Use it for daily NPC schedules — wandering merchants, guards rotating posts, couriers making deliveries, or any entity that should move on a clock.

The runner does not move entities directly. It starts `TRAVEL` tasks through `TaskRunner`, and `TaskRunner` moves the entity when the task completes. This means travel duration, rewards, and completion hooks all work the same as any other task.

### Config schema

Add a `task_routines` key to any loaded `config.json`:

```json
{
  "task_routines": [
    {
      "routine_id": "my_name:my_mod:guard_patrol",
      "entity_id": "my_name:my_mod:gate_guard",
      "loop": "daily",
      "entries": [
        {
          "tick": 6,
          "task_template_id": "my_name:my_mod:guard_to_gate"
        },
        {
          "tick": 18,
          "task_template_id": "my_name:my_mod:guard_to_barracks"
        }
      ]
    }
  ]
}
```

### Routine fields

- `routine_id` — unique id for the routine (used internally to prevent duplicate starts)
- `entity_id` — required. The entity that will perform the tasks (must exist in `GameState.entity_instances`)
- `loop` — currently only `"daily"` is supported
- `enabled` — optional, defaults to `true`
- `entries` — array of scheduled task starts

### Entry fields

- `tick` (or `at_tick` or `tick_into_day`) — required. The tick within the current day when the task should start.
- `task_template_id` (or `template_id`) — required. The task template to start.
- `target` — optional. Overrides the task template's target location.
- `duration` / `remaining_ticks` — optional. Overrides the routed travel cost.
- `task_type` — optional. Overrides the task type from the template.
- `reward` — optional. Overrides the reward payload.
- `complete_sound` — optional. Overrides the completion sound.
- `allow_duplicate` — optional, defaults to `true`. When `true`, the same template can be active from different routine entries simultaneously.

### Travel duration resolution

When a routine entry starts a `TRAVEL` task and no `duration` or `remaining_ticks` is supplied, `TaskRoutineRunner` resolves the travel cost from the location graph:

```
LocationGraph.get_route_travel_cost(entity.location_id, target_location_id)
```

This means routine JSON does not need hard-coded travel costs as long as locations are connected through `locations.json`.

### Important behavior

Each routine entry starts at most once per in-game day. The runner resets its tracking when the day changes, when a new game starts, or when a save is loaded.

Entry ticks are relative to the start of each day. The tick range is `0` to `game.ticks_per_day - 1`. If your config sets `ticks_per_day: 24`, valid ticks are 0–23.

### Task templates for routines

Routine travel tasks are just regular task templates. They should usually be `TRAVEL` type, `repeatable: true`, and have an empty reward:

```json
{
  "task_templates": [
    {
      "template_id": "my_name:my_mod:guard_to_gate",
      "type": "TRAVEL",
      "target": "my_name:my_mod:front_gate",
      "repeatable": true,
      "reward": {},
      "description": "The guard walks to the front gate."
    }
  ]
}
```

### Common pattern: private locations

When an NPC has a private home location, pair the routine with an entry condition on the location:

```json
{
  "location_id": "my_name:my_mod:guard_barracks",
  "display_name": "Guard Barracks",
  "locked_message": "The barracks door is locked.",
  "entry_condition": {
    "type": "has_flag",
    "flag_id": "my_name:my_mod:barracks_open",
    "value": true
  },
  "connections": { "my_name:my_mod:front_gate": 1 }
}
```

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

`CraftingBackend` requires `station_id`; optional `recipe_tags` and `recipe_ids` filter visible recipes. The backend rechecks those filters, station requirements, and discovery state when craft is confirmed, so a recipe that is not visible from the current station cannot be crafted by stale UI state. Instant recipes produce output immediately. Recipes with `craft_time_ticks > 0` consume inputs immediately and start the generic `base:recipe_craft` timed task, which grants the output when completed. The base mod ships that task shell in `mods/base/data/tasks.json`; authored timed-craft content should keep an equivalent `CRAFT` task template available if the base one is replaced or removed by a total conversion.

Supported discovery modes are `always`, `learned_on_flag`, and `auto_on_ingredient_owned`.

`learned_on_flag` checks for the `learned:<recipe_id>` flag on the crafter or global `GameState`. `ActionDispatcher` now supports a dedicated `learn_recipe` action so authored content does not need to hand-roll that flag format with `set_flag`.

`required_stations`, `required_flags`, and `tags` must contain non-empty strings. `required_stats` values must be numeric so stat gates fail validation instead of becoming implicit zero-value requirements.

---

## 11.7 `encounters.json`

Encounters are data-authored, turn-based scenes loaded through `EncounterRegistry` and launched with `EncounterBackend`. They mutate real entity stats through committed `EntityInstance` copies, while encounter-local meters such as intimidation or progress live only inside the active backend instance.

### Current addition format

```json
{
  "encounters": [
    {
      "encounter_id": "my_name:my_mod:tavern_brawl",
      "display_name": "Tavern Brawl",
      "screen_title": "Tavern Brawl",
      "participants": {
        "player": { "entity_id": "player" },
        "opponent": { "entity_id": "entity:my_name:my_mod:drunk_patron" }
      },
      "encounter_stats": {
        "intimidation": { "label": "Intimidation", "default": 0, "min": 0, "max": 100 }
      },
      "actions": {
        "player": [
          {
            "action_id": "strike",
            "label": "Strike",
            "check": { "type": "stat_check", "entity_id": "encounter:player", "stat": "strength", "op": ">=", "value": 4 },
            "on_success": [
              { "effect": "modify_stat", "target": "opponent", "stat": "health", "base_delta": -5 },
              { "effect": "log", "text": "{user_name} lands a clean hit." }
            ],
            "on_failure": [
              { "effect": "log", "text": "{user_name} misses." }
            ]
          }
        ],
        "opponent": [
          {
            "action_id": "swing",
            "label": "Swing",
            "weight": 1,
            "on_success": [
              { "effect": "modify_stat", "target": "player", "stat": "health", "base_delta": -3 }
            ]
          }
        ]
      },
      "resolution": {
        "max_rounds": 8,
        "max_rounds_outcome": "fled",
        "cancel_outcome": "fled",
        "outcomes": [
          {
            "outcome_id": "victory",
            "conditions": { "type": "stat_check", "entity_id": "encounter:opponent", "stat": "health", "op": "<=", "value": 0 },
            "screen_text": "The opponent yields.",
            "reward": { "credits": 5 },
            "pop_on_resolve": true
          }
        ]
      }
    }
  ]
}
```

### Important current details

- Required fields are `encounter_id`, `participants`, `actions`, and `resolution`.
- `participants.player` and `participants.opponent` are the v1 fixed roles. `entity_id` accepts `"player"`, `"entity:<id>"`, or a raw entity id. Template participant ids must reference known entity templates; launch-time payload overrides may still point at runtime entity ids.
- Launch payloads may override participants with `player_entity_id`, `opponent_entity_id`, or `participant_overrides`.
- Player actions are shown as buttons. Opponent actions are selected by weighted random among available actions.
- `opponent_strategy` currently supports `{ "kind": "weighted_random" }` only. Omit the field for the same behavior.
- `availability` and `check` use `ConditionEvaluator`; encounter contexts add `encounter:player`, `encounter:opponent`, `encounter_stat_check`, and `has_encounter_tag`.
- Supported effects are `modify_stat`, `modify_encounter_stat`, `set_encounter_stat`, `set_flag`, `log`, `resolve`, `apply_tag`, and `remove_tag`.
- `resolve` stops later effects in the same action list. Put any final `log` effect before the `resolve` effect.
- `apply_tag` writes an encounter-local tag to `player` or `opponent`; `duration_rounds` defaults to `1` and decrements after a full unresolved round. `has_encounter_tag` checks these tags from action availability or checks.
- Outcome `reward` is applied through `RewardService`; outcome `action_payload` is dispatched through `ActionDispatcher`.
- Resolved encounters stay on the encounter screen until the player presses Continue. The resolution panel shows `screen_text` and a formatted reward summary; Continue then performs the authored `next_screen_id` or `pop_on_resolve` navigation.
- Encounter patches support `set`, `add_player_actions`, `remove_player_action_ids`, `add_opponent_actions`, `remove_opponent_action_ids`, `add_outcomes`, and `remove_outcome_ids`.
- Load validation rejects unsupported effects, unknown real stats in `modify_stat`, unknown local meters in encounter-stat effects, unknown outcomes in `resolve`, missing tag ids on tag effects, malformed outcome action payloads, and invalid `push_screen` targets.
- The base pack ships three reference encounters: `base:tutorial_brawl`, `base:tutorial_negotiation`, and `base:tutorial_endurance`.

> **Note on `reward` shape:** outcome `reward` is a flat dict keyed by currency stat id, e.g. `{ "credits": 25 }`. Do not nest it under a `"currency"` key — that is not a recognised field.

---

### Cookbook

#### How do I make a non-combat encounter?

Leave out any `modify_stat` effects that touch `health`. Define one or more encounter-local meters as your progress axis and drive them with `modify_encounter_stat` effects. Wire `encounter_stat_check` conditions on the resolution outcomes so the encounter ends when a meter threshold is reached. The opponent side can be a no-damage pressure action (draining the player's `stamina`, filling a `pressure` meter, etc.) or omitted entirely — if all opponent actions are unavailable the backend logs `"The opponent hesitates."` and the round advances cleanly.

Minimal negotiation skeleton:

```json
{
  "encounter_id": "my_name:my_mod:merchant_negotiation",
  "display_name": "Negotiate",
  "participants": {
    "player": { "entity_id": "player" },
    "opponent": { "entity_id": "my_name:my_mod:merchant" }
  },
  "encounter_stats": {
    "concession": { "label": "Concession", "default": 0, "min": 0, "max": 100 }
  },
  "actions": {
    "player": [
      {
        "action_id": "persuade",
        "label": "Persuade",
        "check": { "type": "stat_check", "entity_id": "encounter:player", "stat": "charisma", "op": ">=", "value": 3 },
        "on_success": [
          { "effect": "modify_encounter_stat", "stat": "concession", "base_delta": 30, "stat_modifiers": { "user.charisma": 5.0 } },
          { "effect": "log", "text": "{user_name} makes a compelling point." }
        ],
        "on_failure": [
          { "effect": "modify_encounter_stat", "stat": "concession", "base_delta": 5 },
          { "effect": "log", "text": "{target_name} looks unmoved." }
        ]
      },
      {
        "action_id": "give_up",
        "label": "Walk Away",
        "on_success": [
          { "effect": "log", "text": "{user_name} ends the negotiation." },
          { "effect": "resolve", "outcome_id": "abandoned" }
        ]
      }
    ],
    "opponent": [
      {
        "action_id": "deflect",
        "label": "Deflect",
        "weight": 1,
        "on_success": [
          { "effect": "modify_encounter_stat", "stat": "concession", "base_delta": -10 },
          { "effect": "log", "text": "{user_name} pushes back." }
        ]
      }
    ]
  },
  "opponent_strategy": { "kind": "weighted_random" },
  "resolution": {
    "max_rounds": 6,
    "max_rounds_outcome": "abandoned",
    "cancel_outcome": "abandoned",
    "outcomes": [
      {
        "outcome_id": "deal",
        "conditions": { "type": "encounter_stat_check", "stat": "concession", "op": ">=", "value": 100 },
        "reward": { "credits": 50 },
        "action_payload": { "type": "set_flag", "flag_id": "my_name:my_mod:merchant_deal_struck", "value": true },
        "screen_text": "The merchant agrees to your terms.",
        "pop_on_resolve": true
      },
      {
        "outcome_id": "abandoned",
        "trigger": "manual",
        "screen_text": "No deal today.",
        "pop_on_resolve": true
      }
    ]
  }
}
```

---

#### How do I make an opponent that gets more aggressive when low on health?

Use `weight_modifiers` on the opponent action you want to escalate. Each entry has an `if` block (any `ConditionEvaluator` condition) and a replacement `weight`. The first matching modifier wins, so put narrow conditions before broad fallbacks.

```json
"opponent": [
  {
    "action_id": "heavy_strike",
    "label": "Heavy Strike",
    "weight": 1,
    "weight_modifiers": [
      {
        "if": { "type": "stat_check", "entity_id": "encounter:opponent", "stat": "health", "op": "<", "value": 30 },
        "weight": 6
      }
    ],
    "on_success": [
      { "effect": "modify_stat", "target": "player", "stat": "health", "base_delta": -12 },
      { "effect": "log", "text": "{user_name} swings desperately." }
    ]
  },
  {
    "action_id": "jab",
    "label": "Jab",
    "weight": 3,
    "on_success": [
      { "effect": "modify_stat", "target": "player", "stat": "health", "base_delta": -4 }
    ]
  }
]
```

At full health `heavy_strike` has weight 1 vs `jab`'s 3 — a 25 % chance. Below 30 health its weight jumps to 6 vs 3, making it the 67 % pick. The same pattern works with any condition the engine supports: `has_encounter_tag`, `encounter_stat_check`, `has_flag`, etc.

---

#### How do I add a flee option?

Add a player action with a `resolve` effect naming a `"manual"` outcome. Manual outcomes only fire when a `resolve` effect explicitly targets them — they are never matched by the automatic resolution loop.

Put any `log` effect **before** the `resolve` effect; `resolve` stops further effects in the same list immediately.

```json
"player": [
  {
    "action_id": "flee",
    "label": "Flee",
    "on_success": [
      { "effect": "log", "text": "{user_name} breaks away and runs." },
      { "effect": "resolve", "outcome_id": "fled" }
    ]
  }
]
```

```json
"resolution": {
  "cancel_outcome": "fled",
  "outcomes": [
    {
      "outcome_id": "fled",
      "trigger": "manual",
      "screen_text": "You get away clean.",
      "pop_on_resolve": true
    }
  ]
}
```

Setting `cancel_outcome` to the same `outcome_id` means the Back button also routes through the authored outcome, so any `reward` or `action_payload` on the fled outcome applies whether the player presses Flee or Back. If you want Back to exit silently without firing the outcome, omit `cancel_outcome`.

---

## 12. `quests.json`

Quests are progression/state-tracking structures. They are also the player-facing contract layer: objectives, rewards, notifications, and quest log entries live here. A quest can be assigned to a non-player entity by starting it with an `assignee_entity_id`; objectives can reference that entity with `entity_id: "quest:assignee"`.

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

### Assignable contract example

```json
{
  "quest_id": "my_name:my_mod:delivery_contract",
  "display_name": "Delivery Contract",
  "description": "Send an assigned entity to the clinic drop point.",
  "stages": [
    {
      "description": "Assigned courier reaches the clinic.",
      "objectives": [
        {
          "type": "reach_location",
          "entity_id": "quest:assignee",
          "location_id": "my_name:my_mod:back_alley"
        }
      ]
    }
  ],
  "reward": {
    "credits": 80,
    "reputation": { "my_name:my_mod:night_clinic": 10 }
  },
  "repeatable": true
}
```

The task layer can move the assigned entity with a `TRAVEL` task. The quest layer decides when the contract is complete and who receives the reward. By default, quest rewards go to the player; callers can override `reward_recipient_entity_id` when starting the quest.

### Objective types

Quest objectives are evaluated by `ConditionEvaluator`. Each objective in the `objectives` array is a condition dictionary. Supported typed conditions (`"type"` field):

- `has_item_tag` — entity owns a part with the given tag. Fields: `tag`, `count` (default 1), optional `entity_id`.
- `reach_location` — entity is at the given location. Fields: `location_id`, optional `entity_id`.
- `has_part` — entity owns a specific part template. Fields: `template_id`, `count` (default 1), optional `entity_id`.
- `has_flag` — flag is set. Fields: `flag_id`, optional `entity_id` (default `"global"`), optional `value` (default `true`).
- `stat_check` — stat comparison. Fields: `stat`, `op` (`>=`, `>`, `<=`, `<`, `==`, `!=`), `value`, optional `entity_id`.
- `stat_greater_than` — shorthand for stat > value. Fields: `stat`, `value`.
- `stat_less_than` — shorthand for stat < value. Fields: `stat`, `value`.
- `has_currency` — entity has at least the given currency amount. Fields: `currency_id` (or `key`), `amount`, optional `entity_id`.
- `reputation_threshold` — faction reputation check. Fields: `faction_id`, `threshold`, `comparison` (default `>=`), optional `entity_id`.
- `quest_complete` — a quest has been completed. Fields: `quest_id`.

Objectives also support logic blocks for compound conditions: `AND` (array, all must pass), `OR` (array, any must pass), `NOT` (single condition, must fail). These can be nested.

Legacy dict-key conditions (without `"type"`) are also supported for backward compatibility — see `ConditionEvaluator` source for details.

When a quest completes, `QuestTracker` applies the quest-level `reward`, records a runtime completion entry, and emits a `ui_notification_requested` toast containing the quest name and formatted reward summary. Quest log screens can set `include_completed: true` to keep completed quest cards available for later reward review.

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
- `hidden`
- `icon`
- `unlock_sound`
- `unlock_vfx`

`hidden: true` keeps an achievement out of `AchievementListBackend` rows until that achievement is unlocked. Once unlocked, the row becomes visible and still carries its `hidden` metadata in the backend view model.

`unlock_vfx` is forwarded through the `achievement_unlocked` event payload and the runtime unlock stub so authored content can already declare which future VFX resource should play when the visual layer is added.

---

## 14. `config.json`

`config.json` is deep-merged into the current config.

### Current base pack example areas
- `game`
- `ui`
- `stats`
- `task_routines`

### Example

```json
{
  "game": {
    "title": "My Total Conversion",
    "tagline": "A new world built on Omni-Framework.",
    "starting_player_id": "base:player",
    "starting_location": "my_name:my_mod:back_alley"
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
- Starting currencies are set on the player entity template in `entities.json`, not in `config.json`. To change starting money, patch the player entity's `currencies` field.
- `game.ticks_per_day` and `game.ticks_per_hour` must be positive integers when provided
- `ui.time_advance_buttons` must be an array of labels ending in `tick(s)`, `hour(s)`, or `day(s)` when provided, such as `"1 hour"` or `"1 day"`
- The current base content also defines `game.new_game_flow`, which means the startup flow can be configured through data instead of hardcoding it all in scripts

Task routines are configured through `config.json` under the `task_routines` key (or nested under `routines.task_routines`). See Section 11.1 for the full schema. Mods can add their own routines through their own `config.json`, and multiple mods' routines will all be active simultaneously since config is deep-merged.

---

## 15. Backends currently registered by the loader

The current loader registers these backend classes:

- `AssemblyEditorBackend`
- `ExchangeBackend`
- `ListBackend`
- `ChallengeBackend`
- `TaskProviderBackend`
- `CatalogListBackend`
- `CraftingBackend`
- `DialogueBackend`
- `EncounterBackend`
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

Notes:
- `faction_id` must reference a faction whose `quest_pool` points at quest/contract templates.
- The backend starts the selected quest for `assignee_entity_id` (default `"player"`) and keeps rewards assigned to the player unless a custom caller overrides `reward_recipient_entity_id`.
- Rows always include the static quest `description`.
- When `ai.enable_world_gen` is on, AI is available, `config.json` enables `ai.task_flavor_enabled`, and `ai.world_gen_hooks.task_flavor` points at a valid hook, the backend may append a cached AI flavor line below the static description and into the selected contract card's `flavor_text`.

#### `DialogueBackend`
Required in practical use:
- `dialogue_resource` or `dialogue_id`

Useful optional fields:
- `dialogue_start`
- `speaker_entity_id`
- `screen_title`
- `screen_description`
- `cancel_label`
- `ai_mode` — `"hybrid"` keeps authored `.dialogue` branches as the primary flow and lets the script hand off to AI chat with `do ai_chat_open()`. `"freeform"` opens directly into AI chat when the speaker entity has `ai_persona_id` and `AIManager` is available.

#### `ChallengeBackend`
Required:
- `required_stat`
- `required_value`

Useful optional fields:
- `target_entity_id`
- `portrait_entity_id`
- `screen_title`
- `screen_description`
- `confirm_label`
- `cancel_label`
- `reward` — dictionary applied on success via `RewardService`
- `action_payload` — single action dictionary dispatched on success via `ActionDispatcher`
- `failure_action_payload` — single action dictionary dispatched on failure
- `success_sound`
- `failure_sound`
- `next_screen_id` / `next_screen_params` — screen pushed on success
- `pop_on_confirm` — pop on success instead of pushing
- `failure_next_screen_id` / `failure_next_screen_params` — screen pushed on failure
- `failure_pop_on_confirm` — pop on failure

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

The map reads `locations.json` through `LocationGraph.get_all_locations()`. A location may optionally provide `map_position` as `{ "x": 0.5, "y": 0.5 }` or `[0.5, 0.5]` using normalized graph coordinates. If omitted, the screen places nodes in a deterministic circular layout. Node tint comes from a location's `faction_id` when present, or from the first faction whose `territory` includes that location. The runtime screen also provides route lines, mouse-wheel zoom, drag panning, fit/current centering controls, and radial/horizontal/vertical orientation modes. The graph now declutters while zoomed out by shrinking nodes into compact pills or markers and hiding travel-cost badges until there is enough space to read them. Traveling from the map consumes the cheapest routed total `travel_cost` in ticks; unreachable destinations are rejected instead of free-teleporting.

#### `EncounterBackend`
Required:
- `encounter_id`

Useful optional fields:
- `screen_title`
- `screen_description`
- `cancel_label`
- `player_entity_id`
- `opponent_entity_id`
- `participant_overrides`
- `next_screen_id`
- `next_screen_params`
- `pop_on_resolve`
- `default_sound`

Most encounter behavior lives in the referenced `encounters.json` template. The backend payload is mainly for launch context, participant overrides, and navigation overrides.

#### `EntitySheetBackend`
No required params. Common useful optional fields:
- `target_entity_id`
- `screen_title`
- `screen_description`
- `stat_title`
- `cancel_label`
- `show_currencies`
- `show_equipped`
- `show_inventory`
- `show_reputation`
- `inventory_limit`

The current entity sheet is read-only and exposes stats, currency balances, equipped parts, inventory summaries, and faction standing.

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

When the selected equipped part template declares `custom_fields`, the assembly editor sidebar renders them as editable controls inside the draft session. Fields with an `options` array render as dropdowns, and fields without options render as free-text inputs. Those edits stay draft-only until the player confirms the build, which means `EntitySheetBackend` remains read-only while `AssemblyEditorBackend` is the place to author per-instance values such as eye color, hair color, callsigns, or serial numbers.

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

#### `ListBackend`
No required params. Common useful optional fields:
- `data_source` — `"player:inventory"` (default), `"entity:<entity_id>:inventory"`, or `"game_state.active_quests"`
- `screen_title`
- `screen_description`
- `confirm_label`
- `cancel_label`
- `action_payload`
- `empty_label`

#### `CraftingBackend`
Required:
- `station_id`

See Section 11.5 for full crafting details. Useful optional fields:
- `recipe_tags` — array of tag strings to filter visible recipes
- `recipe_ids` — array of specific recipe ids to show
- `crafter_entity_id`
- `input_source_entity_id`
- `output_destination_entity_id`
- `screen_title`
- `confirm_label`
- `cancel_label`
- `empty_label`

#### `ActiveQuestLogBackend`
No required params. Common useful optional fields:
- `screen_title`
- `screen_description`
- `cancel_label`
- `include_completed`

#### `FactionReputationBackend`
No required params. Common useful optional fields:
- `screen_title`
- `screen_description`
- `cancel_label`

#### `AchievementListBackend`
No required params. Common useful optional fields:
- `screen_title`
- `screen_description`
- `cancel_label`

Hidden achievements (`hidden: true`) are filtered out of this backend until they are unlocked. Unlocked rows expose both `hidden` and `unlock_vfx` metadata in their view-model payload so custom UI can differentiate secret achievements from normal ones.

#### `EventLogBackend`
No required params. Common useful optional fields:
- `screen_title`
- `screen_description`
- `cancel_label`
- `limit`

Notes:
- Rows always include the recorded event name, args summary, and timestamp.
- If a world-generation hook calls `GameEvents.add_event_narration(...)`, the backend also exposes `narration_text` for that event row and the stock screen renders it as an extra line.

---

## 15.5 Action types (`ActionDispatcher`)

Actions are side-effect operations dispatched from quest stages, task rewards, challenge results, and backend `action_payload` fields. Each action is a dictionary with a `type` key.

### Available action types

| Type | Key fields | Notes |
|---|---|---|
| `give_currency` / `add_currency` | `currency_id` (or `key`), `amount`, optional `entity_id` | |
| `take_currency` / `remove_currency` | `currency_id` (or `key`), `amount`, optional `entity_id` | |
| `give_part` | `part_id`, optional `entity_id` | Creates a new instance from template |
| `remove_part` / `consume` | `instance_id` or `part_id` (or `template_id`), optional `entity_id` | Removes one instance |
| `set_flag` | `flag_id` (or `key`), `value`, optional `entity_id` (default `"global"`) | |
| `modify_stat` | `stat`, `delta`, optional `entity_id` | |
| `modify_reputation` / `add_reputation` / `remove_reputation` | `faction_id`, `amount`, optional `entity_id` | |
| `travel` | `location_id` | Moves the player |
| `start_task` | `task_template_id` (or `template_id`), optional `entity_id` | |
| `start_quest` | `quest_id` | |
| `unlock_location` | `location_id`, optional `entity_id` | Adds to discovered locations |
| `spawn_entity` | `template_id` (or `entity_template_id`), optional `location_id` | Instantiates a new entity |
| `learn_recipe` | `recipe_id`, optional `entity_id` | Sets `learned:<recipe_id>` flag |

### `spawn_entity` details

Creates a new `EntityInstance` from an entity template and commits it to `GameState.entity_instances`. If the template's `entity_id` already exists at runtime, the spawned instance gets a unique generated id to avoid collision.

```json
{
  "type": "spawn_entity",
  "template_id": "my_name:my_mod:reinforcement_guard",
  "location_id": "my_name:my_mod:front_gate"
}
```

- `template_id` (or `entity_template_id`) — required. Must reference a valid entity template.
- `location_id` — optional. If provided, overrides the template's `location_id`. Must reference a valid location.

Once spawned, the entity is fully live — it appears at its location, can receive tasks from routines, and persists through saves.

### `travel` details

The `travel` action also accepts an optional `travel_ticks` field. If `travel_ticks` is 0 or omitted, travel is instant.

```json
{
  "type": "travel",
  "location_id": "my_name:my_mod:hideout",
  "travel_ticks": 3
}
```
| `unlock_achievement` | `achievement_id` | |
| `reward` | `reward` (or inline reward fields) | Delegates to `RewardService` |
| `emit_signal` | `signal_name`, optional `args` | Emits on `GameEvents` |
| `push_screen` | `screen_id`, optional `params` | |
| `pop_screen` | (none) | |
| `replace_all_screens` | `screen_id`, optional `params` | |

### Example

```json
{
  "type": "give_currency",
  "currency_id": "credits",
  "amount": 100,
  "entity_id": "player"
}
```

`entity_id` defaults to `"player"` for most action types. Use `"global"` for `set_flag` when targeting global game state.

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
  "dialogue_start": "start",
  "ai_mode": "hybrid"
}
```

Recommended folder:

```text
mods/<author>/<mod>/dialogue/
```

For hybrid authored handoff, pass the routed screen itself into Dialogue Manager with a branch like:

```text
~ start
NPC: We can stay on script, or not.
- Talk freely. [if can_open_ai_chat()]
	do ai_chat_open()
	=> END
- Maybe later.
	=> END
```

`ai_chat_open()` switches the routed dialogue screen into AI mode. `can_open_ai_chat()` keeps the option hidden when AI is unavailable, so the scripted tree remains the zero-error fallback.

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

`on_tick` is dispatched once per game tick for every part instance (inventory or equipped) across all entities in `GameState.entity_instances` whose template declares a `script_path`. This includes the player and all NPCs/vendors.

`on_location_enter` and `on_location_exit` fire on the **location template**, not on entities. When the player travels, `GameState.travel_to()` invokes `on_location_exit` on the old location's template and `on_location_enter` on the new location's template. These hooks do not fire when NPCs move via `TRAVEL` tasks.

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

### 8. Putting a moving NPC in `entities_present`
If an NPC moves via task routines or `TRAVEL` tasks, do not also list them in a location's `entities_present`. That would cause the NPC to always appear at that location regardless of where they actually are. Set the entity's initial `location_id` in `entities.json` and let the task system handle movement.

### 9. Forgetting `locked_message` on gated locations
If you add `entry_condition` or `entry_conditions` to a location but omit `locked_message`, the UI will show the generic default "You cannot enter this location right now." Always provide a thematic `locked_message`.

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
          "template_id": "my_name:starter_plus:training_blade"
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
- `docs/TASK_ROUTINES.md`
- `docs/LOCATION_ACCESS.md`

If your mod needs custom behavior, also inspect:
- `core/script_hook.gd`
- backend scripts under `ui/screens/backends/`
- loader logic in `autoloads/mod_loader.gd`

For a working example of task routines, NPC movement, and location locking, study the included example mod:

```
mods/example/traveling_merchant/
```

It adds a merchant NPC (Sable) who travels between Market Row, the Warehouse, and a private locked room on a daily schedule. The mod demonstrates task routine configuration, `TRAVEL` task templates, location entry conditions with `entry_condition` and `locked_message`, patching base locations with `add_connections`, and entity setup with inventory and interactions.

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
- task routine `entity_id` references an entity that exists in `entities.json`
- routine entry ticks fall within `0` to `ticks_per_day - 1`
- routine task templates exist in `tasks.json`
- locked locations have both `entry_condition` (or `entry_conditions`) and `locked_message`
- moving NPCs are not also listed in any location's `entities_present`

If those pass, your mod is aligned with the current repo much more closely than the older guide.
