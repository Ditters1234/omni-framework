# Omni-Framework - Official Modding Guide

Welcome to the **Omni-Framework** modding scene. 

This engine was built from the ground up to be a **100% data-driven** generalized game platform. You do not need to know how to write GDScript or use the Godot Engine to add new items, magic systems, NPCs, or entire worlds. If you can edit a JSON file and draw some pixel art, you can mod any game built on this platform.

This guide covers the core architecture, the system hierarchy, and provides practical examples for modifying every core game system.

---

## 1. System Architecture & Hierarchy Map

The Omni-Framework relies on a strict separation between engine logic and game data. The engine provides "Systems" (like the Parts system or the Quest system), which are entirely fueled by JSON data. 

### The Two-Phase Loading System
To ensure maximum compatibility between mods, the game uses a **Two-Phase Loading** architecture:
1. **Phase 1 (Additions):** The base game JSON files are loaded, followed by all new items/entities/locations added by active mods.
2. **Phase 2 (Patches):** All active mods apply their "patches". Because patches run last, a patch in Mod B can successfully modify a part that was added by Mod A.

### System Hierarchy Map
Here is how the core systems interact with your mod files:

```text
Game Boot
 ↳ GameEvents (Global event bus)
 ↳ ModLoader (Scans res://mods/, reads mod.json, builds load order, resolves dependencies)
    │
    ├─► Definitions
    │     (Reads data/definitions.json -> Defines valid Stats and Currencies)
    │
    ├─► Parts System
    │     (Reads data/parts.json -> Loads Mod Additions -> Applies Mod Patches)
    │
    ├─► WorldMap System
    │     (Reads data/locations.json -> Loads Mod Additions -> Applies Mod Patches)
    │     (Dynamically generates map layout based on connections)
    │
    ├─► Entities System
    │     (Reads data/entities.json -> Loads Mod Additions -> Applies Mod Patches)
    │
    ├─► Factions System
    │     (Reads data/factions.json -> Loads Mod Additions -> Applies Mod Patches)
    │
    ├─► Quest System
    │     (Reads data/quests.json -> Loads Mod Additions -> Applies Mod Patches)
    │
    ├─► Tasks System
    │     (Reads data/tasks.json -> Loads Mod Additions -> Applies Mod Patches)
    │
    ├─► Achievement System
    │     (Reads data/achievements.json -> Loads Mod Additions -> Applies Mod Patches)
    │
    └─► ConfigLoader
          (Deep-merges data/config.json overrides from all mods)
```

---

## 2. Mod Structure & Load Order

To create a mod, do not modify the base game files. Instead, create a new folder structure inside the `mods/` directory.

Your mod folder must look like this:
```text
mods/<author_id>/<mod_id>/
├── mod.json          (Mod manifest: name, version, load_order, dependencies)
├── data/             (JSON files to merge into the base game)
├── scripts/          (Optional GDScript hooks)
└── assets/           (Your custom PNGs and audio)
```

### The Manifest (`mod.json`)
Every mod must have a manifest at its root:
```json
{
  "name": "My Cool Mod",
  "version": "1.0.0",
  "load_order": 100,
  "enabled": true,
  "dependencies": ["base"]
}
```
**Field Descriptions:**
- `name` (required, string): Human-readable mod name displayed to players.
- `version` (required, string): Semantic versioning for your mod (e.g., "1.0.0", "1.2.3-beta").
- `load_order` (required, number): Integer controlling load sequence. Lower values load first. Use 0-50 for foundational content mods, 51-100 for feature mods, 101+ for balance overhauls. Mods with equal load_order are sorted alphabetically by directory name.
- `enabled` (optional, boolean, default: true): If false, this mod will not load.
- `dependencies` (optional, array): List of other mods this one requires, formatted as `"author_id:mod_id"`. The system will error if dependencies are missing.

*Mods with a lower `load_order` load first. Higher `load_order` mods will override lower ones in the event of a config conflict.*

### Namespacing Convention

**Namespacing Rule:** All custom part IDs, entity IDs, location IDs, faction IDs, and task IDs must use your unique namespace: `author_id:mod_id:object_name` (e.g., `my_name:my_mod:magic_sword`).

- Use **colons** (`:`) to separate namespace hierarchy.
- Use **underscores** (`_`) for multi-word names within a component (e.g., `my_name:my_mod:flaming_sword`).
- IDs are case-sensitive and should use lowercase alphanumerics.
- Do NOT use the `base:` prefix - that's reserved for the base game.

---

## 3. Modding Core Systems (Examples)

For every system, you have two options: **Add** a completely new object, or **Patch** an existing one. Both are done in the same file.

### 3.1. Root Definitions (Stats & Currencies)
File: `data/definitions.json`

Define your game's physical laws here. This is the **foundational system** - a modder building in a different genre shouldn't be stuck with hardcoded stats. Define new global standards that ALL other systems will recognize.

**Structure:**
```json
{
  "currencies": ["gold", "gems", "credits"],
  "stats": ["strength", "agility", "mana", "stamina", "health_max"]
}
```

**Important Notes:**
- **Stats are global** - once defined here, they can be referenced in Parts (`stats` field), Entities (`stats` field), and Challenges (`required_stat` field).
- **Stats with `_max` suffix** (like `health_max`, `mana_max`) are interpreted as **progress bar capacities**. The engine treats these differently from flat stats.
- **Currencies are global** - they appear in Entity `currencies` dictionaries, Part `price` fields, and Task `reward` fields. If a currency isn't listed here, it won't be recognized.
- **There is no patching** for Definitions - it's a foundational layer. Mods should add to the arrays non-destructively (the system merges all mods' definitions).

### 3.2. Parts (Hierarchical Data & Stat Nodes)
File: `data/parts.json`

Parts are the fundamental building blocks of the game's data. Rather than just being "items", a Part is any attachable node that can grant stats, require specific tags, and provide sockets for further nesting. You can use Parts to create weapons and clothing, but you could just as easily use them to build a complex skill tree (where unlocking a "Node" Part provides sockets for "Sub-Skill" Parts), a modular spaceship, or a spell-crafting system.

**Adding a New Part (Example: A Flaming Sword):**
```json
{
  "parts": [
    {
      "id": "my_name:my_mod:flaming_sword",
      "display_name": "Sword of Flames",
      "description": "Heavy magical weapon with an integrated fire enchantment.",
      "tags": ["weapon", "melee", "sword"],
      "required_tags": ["humanoid"],
      "sprite": "res://mods/my_name/my_mod/assets/flaming_sword.png",
      "ui_color": "#ff4400",
      "equip_sound": "res://mods/my_name/my_mod/assets/sfx/sword_draw.wav",
      "price": { "gold": 2500 },
      "stats": { "mana_max": -25, "power": 15, "strength": 12 },
      "equippable": true,
      "provides_sockets": [
        { "id": "rune_slot", "accepted_tags": ["rune"], "label": "Rune Socket" }
      ],
      "customizable": true,
      "custom_field_labels": ["Inscription","Flame Color"]
      "script_path": "res://mods/my_name/my_mod/scripts/flaming_sword.gd"
    }
  ]
}
```

**Field Descriptions (Required & Optional):**
- `id` (required, string): Namespaced ID: `author:mod:part_name`.
- `display_name` (required, string): Human-readable name shown in UI.
- `description` (required, string): Text explaining the part. Supports multi-line.
- `tags` (required, array): List of tags defining what this part IS. Used for socket matching and filtering.
- `required_tags` (optional, array): Tags the parent entity/part must have to accept this part.
- `sprite` (optional, string): Path to PNG file. If omitted, system uses fallback hierarchy (magic filename, config default, global fallback).
- `ui_color` (optional, string): Hex color code used for UI borders/highlights. Useful for rarity, elements, or visual categories.
- `equip_sound` (optional, string): WAV/OGG path played when this part is equipped.
- `price` (required, object): Dictionary of `{ "currency_id": amount }`. Example: `{ "gold": 500 }` or `{ "gold": 10, "gems": 5 }`. At least one currency required for selling.
- `stats` (optional, object): Dictionary of `{ "stat_name": modifier }`. Negative values reduce (e.g., `"mana_max": -25` costs mana).
- `equippable` (optional, boolean): If true, entity can equip this part as sub-part.
- `provides_sockets` (optional, array): Array of socket objects that this part creates when attached.
  - Socket object: `{ "id": "socket_name", "accepted_tags": ["tag1", "tag2"], "label": "Display Name" }`
- `customizable` (optional, boolean): If true, entity can set custom values on this part (e.g., renaming, tracking state).
- `custom_field_label` (optional, object): Dictionary of `{Label for the custom field UI (e.g., "Kill Count", "Hair Color")}.
- `script_path` (optional, string): Path to GDScript hook extending `ScriptHook` base class.

**Patching an Existing Part:**
You can modify an existing part to add/remove tags, sockets, or change stats and text.
```json
{
  "patches": [
    {
      "target": "human_head",
      "add_sockets": [
        { "id": "eyewear", "accepted_tags": ["eyewear", "glasses"], "label": "Glasses" }
      ],
      "remove_sockets": ["old_socket_id"],
      "add_tags": ["has_eyewear_slot"],
      "remove_tags": ["basic_head"],
      "add_required_tags": ["organic"],
      "set_stats": { "perception": 1 },
      "set": { 
        "description": "A customized human head.",
        "price": { "gold": 100 }
      }
    }
  ]
}
```

### 3.3. Entities (Stateful Actors & Containers)
File: `data/entities.json`

Entities are the stateful actors of the game engine. While they are typically used to represent the Player, NPCs, or Vendors, an Entity is fundamentally just a container. It holds an `inventory` of Parts, equips Parts into an `assembly_socket_map`, exists at a specific Location, and exposes UI `interactions`. 

Crucially, **every Entity natively owns its own progression and state**. Any entity (not just the player) can have its own `currencies`, `reputation`, `stats`, `discovered_locations`, and persistent boolean `flags`. You could use an Entity to represent a locked treasure chest that tracks if it's been opened, a drivable vehicle that tracks its fuel as a currency, a physical terminal, or an abstract progression manager.

**Adding a New Entity (Example: A Vendor):**
```json
{
  "entities": [
    {
      "entity_id": "my_name:my_mod:merchant_bob",
      "display_name": "Merchant Bob",
      "description": "A shady vendor.",
      "portrait": "res://mods/my_name/my_mod/assets/merchant_bob_portrait.png",
      "dialogue_blip": "res://mods/my_name/my_mod/assets/sfx/bob_talk.wav",
      "location_id": "town_square",
      "currencies": {
        "gold": 5000,
        "gems": 150
      },
      "stats": {
        "charisma": 8
      },
      "flags": {
        "met_player": false,
        "inventory_restocked": false
      },
      "inventory": [
        { "instance_id": "bob_sword_1", "template_id": "base:iron_sword", "condition": 1.0 }
      ],
      "interactions": [
        { 
          "tab_id": "bob_shop", 
          "label": "Trade", 
          "backend_class": "ExchangeBackend",
          "source_inventory": "entity:my_name:my_mod:merchant_bob",
          "destination_inventory": "player",
          "currency_id": "gold",
          "transaction_sound": "res://mods/my_name/my_mod/assets/sfx/cha_ching.wav",
          "list_icon": "res://mods/my_name/my_mod/assets/icons/trade_icon.png"
        }
      ]
    }
  ]
}
```

**Field Descriptions (Required & Optional):**
- `entity_id` (required, string): Namespaced ID: `author:mod:entity_name`.
- `display_name` (required, string): Name shown in UI and dialogue.
- `description` (optional, string): Bio/description shown on character sheets.
- `portrait` (optional, string): PNG path for character portrait/avatar in UI.
- `dialogue_blip` (optional, string): WAV/OGG audio clip played when entity speaks.
- `location_id` (optional, string): Which location this entity starts at. If omitted, entity is "unplaced" (useful for inventory-only entities or abstract containers).
- `currencies` (optional, object): Dictionary of `{ "currency_id": amount }`. Each currency the entity owns.
- `stats` (optional, object): Dictionary of `{ "stat_id": value }`. Flat stats for this entity (separate from equipped parts).
- `reputation` (optional, object): Dictionary of `{ "faction_id": points }`. Starting reputation with each faction.
- `flags` (optional, object): Dictionary of `{ "flag_name": boolean }`. Persistent boolean state tracking (e.g., `"met_player": false`).
- `discovered_locations` (optional, array): List of location IDs this entity has discovered.
- `inventory` (optional, array): Array of part instances this entity owns.
  - Instance object: `{ "instance_id": "unique_id", "template_id": "part:id", "condition": 1.0, "custom_data": "optional" }`
  - `instance_id`: Unique identifier for THIS specific copy (used to track which exact item is equipped where).
  - `template_id`: References a Part definition (e.g., `"base:iron_sword"` or `"my_name:my_mod:flaming_sword"`).
  - `condition`: Float 0.0-1.0 representing durability/wear. Used in pricing and UI feedback.
- `assembly_socket_map` (optional, object): Dictionary of `{ "socket_id": "instance_id" }`. Which parts are currently equipped where.
- `assembly_instance_ids` (optional, array): List of instance IDs currently equipped on this entity (convenience for UI).
- `owned_entity_ids` (optional, array): List of entity IDs this entity "owns" (e.g., minions, vehicles, summons).
- `interactions` (optional, array): Array of interaction/screen objects defining UI tabs.

**Patching an Existing Entity:**
Want to sell your new item at the local blacksmith, give them a custom currency, or move them to a new location?
```json
{
  "patches": [
    {
      "target": "npc_blacksmith",
      "add_inventory": [
        { "instance_id": "my_name:my_mod:inst_001", "template_id": "my_name:my_mod:flaming_sword", "condition": 1.0 }
      ],
      "add_interactions": [
        { "tab_id": "secret_stash", "label": "Secret Stash", "backend_class": "ExchangeBackend" }
      ],
      "remove_interactions": ["old_dialogue_tab"],
      "modify_interaction": [
        { "tab_id": "blacksmith_shop", "set": { "label": "Black Market Weapons" } }
      ],
      "add_owned_entity_ids": ["my_name:my_mod:guard_dog"],
      "add_assembly_socket_map": { "head_slot": "my_name:my_mod:inst_002" },
      "add_assembly_instance_ids": ["my_name:my_mod:inst_002"],
      "set_currencies": { "gold": 10000 },
      "set": {
        "location_id": "my_name:my_mod:secret_lab",
        "display_name": "Shady Blacksmith"
      }
    }
  ]
}
```

### 3.4. Locations (Graph Nodes & UI Contexts)
File: `data/locations.json`

Locations represent nodes in a topological graph. While they form the "World Map", under the hood they are simply contexts that define what UI screens the player can access and how they connect to other nodes. You define the `connections` and `connection_costs` to generate a network. A Location could be a city district, a specific room in a dungeon, or even an abstract menu state.

**Adding a New Location (Example: A Hidden Lab):**
```json
{
  "locations": [
    {
      "location_id": "my_name:my_mod:secret_lab",
      "display_name": "Abandoned Lab",
      "description": "An old, forgotten research facility.",
      "map_icon": "res://mods/my_name/my_mod/assets/lab_icon.png",
      "background_image": "res://mods/my_name/my_mod/assets/lab_bg.png",
      "music_track": "res://mods/my_name/my_mod/assets/music/spooky_lab.ogg",
      "ambient_sound": "res://mods/my_name/my_mod/assets/sfx/machinery_hum.wav",
      "connections": ["hub_safehouse"],
      "connection_costs": { "hub_safehouse": 5 },
      "screens": []
    }
  ]
}
```

**Field Descriptions (Required & Optional):**
- `location_id` (required, string): Namespaced ID: `author:mod:location_name`.
- `display_name` (required, string): Name shown on world map and in UI.
- `description` (optional, string): Flavor text/description for the location.
- `map_icon` (optional, string): PNG path for world map icon.
- `background_image` (optional, string): PNG path for location background/wallpaper.
- `music_track` (optional, string): OGG/WAV path for ambient music (loops on visit).
- `ambient_sound` (optional, string): OGG/WAV path for background sound effects.
- `connections` (optional, array): List of location IDs this location connects to (graph edges).
- `connection_costs` (optional, object): Dictionary of `{ "location_id": ticks }` defining travel cost to each connection.
- `screens` (optional, array): Array of interaction/UI screen objects available at this location.
- `flags` (optional, object): Dictionary of persistent booleans for this location (e.g., `"discovered": true`).
- `entities_present` (optional, array): List of entity IDs that spawn here by default.

**Patching a Location (Adding Connections & Screens):**
To make your new location accessible, you must patch an existing location to connect *back* to it. You can also append new UI tabs or modify existing ones.
```json
{
  "patches": [
    {
      "target": "hub_safehouse",
      "add_connections": { "my_name:my_mod:secret_lab": 5 },
      "remove_connections": ["old_busted_hideout"],
      "add_screens": [
        { "tab_id": "my_tab", "label": "My Custom Board", "backend_class": "TaskProviderBackend" }
      ],
      "set": { "description": "The updated safehouse." }
    },
    {
      "target": "loc:scrap_heaps:workshop",
      "modify_screen": [
        {
          "tab_id": "my_wardrobe",
          "append_editable_tags": ["clothing", "outerwear", "top"],
          "append_custom_editable_tags": ["my_custom_tag"],
          "set": { "label": "Mirror & Wardrobe" }
        }
      ],
      "remove_screens": ["old_tab_id"]
    }
  ]
}
```

### 3.5. UI Screens & Action Payloads
When defining a screen in a location or an interaction on an NPC, you assign a `backend_class` to dictate its functionality.

**Backend Classes (Screen Types):**
*   **`AssemblyEditorBackend` (Workbenches/Assembly):** Lets players modify their body/gear. Use `editable_tags` to restrict what they can attach (e.g., `["weapon"]` for an armory bench). Emits events when parts are attached/detached.
*   **`ExchangeBackend` (Inventory Shops/Trading):** Sells physical *Instances* directly out of an Entity's `inventory` array. Once the NPC runs out of an item, it's gone until restocked. Uses real game economy. Reverse source/destination to create a "Sell" screen.
    *   *Required:* Define `"source_inventory"` (e.g., `"entity:my_name:my_mod:merchant_bob"`) and `"destination_inventory"` (e.g., `"player"`). 
    *   *Optional:* Define `"transaction_sound"` and `"list_icon"` for rich feedback.
*   **`ListBackend` (Data Displays):** Shows lists like `"player:inventory"` or `"player:fleet"`. Use `action_payload` to trigger events when items are clicked.
*   **`ChallengeBackend` (Stat Checks/Challenges):** Allows the player to attempt instantaneous challenges. Define `required_stat` (e.g., `"power"`) and `required_value`. On success, trigger `reward` or `action_payload`.
*   **`TaskProviderBackend` (Job Boards):** Shows repeatable tasks from a Faction's `quest_pool`. Requires `faction_id` field.
*   **`CatalogListBackend` (Infinite Vending):** Acts as an infinite vending machine. Sells raw `Part` templates directly from the database (like an MMO vendor). Requires `data_source: "catalog"` and `action_payload: {"type": "buy_item"}`.

**Currency & Pricing Rules:**
A Part's `"price"` property is a dictionary of currencies and their respective values. This allows items to natively cost multiple currencies simultaneously!
*   Use `"price": { "gold": 500 }` for a single-currency item.
*   Use `"price": { "gold": 10, "gems": 20 }` for an item requiring mixed currencies.
*   Use `"price_modifier": 0.1` in a shop's config to apply an exchange rate multiplier (all prices multiplied by 0.1 at this specific shop).
*   Negative prices are unsupported - items must have positive cost.
*   **Economy Note:** Because currencies are local to each entity, an NPC vendor will literally run out of money unless their entity is restocked!

**Screen Object Structure (Common Fields):**
```json
{
  "tab_id": "unique_screen_id",
  "label": "Display Name",
  "backend_class": "ExchangeBackend",
  "description": "Optional tooltip/description",
  "icon": "res://path/to/icon.png",
  "transaction_sound": "res://path/to/sound.wav",
  "list_icon": "res://path/to/list_icon.png",
  "currency_id": "gold",
  "price_modifier": 1.0,
  "action_payload": { "type": "buy_item" },
  "conditions": { "AND": [] }
}
```

**Action Payloads & The Condition System (Modifying State via JSON):**
Many screens and quest rewards support an `action_payload` object. This is how you manipulate game state or trigger events strictly through JSON. You can gate actions using a nested `conditions` block.
```json
{
  "conditions": {
    "AND": [
      { "type": "has_flag", "entity_id": "global", "flag_id": "boss_defeated", "value": true },
      { "type": "stat_greater_than", "entity_id": "player", "stat": "strength", "value": 15 },
      { "type": "has_item_tag", "tag": "weapon", "count": 1 }
    ]
  },
  "action_payload": {
    "type": "set_flag",
    "entity_id": "npc_smuggler_jim",
    "flag_id": "talked_to_player",
    "value": true,
    "success_sound": "res://mods/my_name/my_mod/assets/sfx/quest_update.wav",
    "vfx": "confetti"
  }
}
```

**Condition Types:**
- `has_flag`: Check if entity has a flag set. Requires `entity_id`, `flag_id`, `value`.
- `stat_greater_than`: Check if entity stat exceeds value. Requires `entity_id`, `stat`, `value`.
- `stat_less_than`: Check if entity stat is below value. Requires `entity_id`, `stat`, `value`.
- `has_item_tag`: Check if entity inventory contains item with tag. Requires `tag`, `count`.
- `has_currency`: Check if entity has enough currency. Requires `currency_id`, `amount`.
- `reputation_threshold`: Check faction reputation. Requires `faction_id`, `threshold`, `comparison` (e.g., `">="`).

**Payload Types (Common Actions):**
*   `"start_task"`: Begin a repeatable task. Requires `task_template_id`.
*   `"start_quest"`: Begin a quest. Requires `quest_id`.
*   `"set_flag"`: Set entity flag. Requires `flag_id`, `value`. Defaults to player if `entity_id` omitted.
*   `"add_currency"`: Add currency to entity. Requires `currency_id`, `amount`. Defaults to player if `entity_id` omitted.
*   `"consume"`: Remove item from inventory. Requires `instance_id`.
*   `"unlock_location"`: Add location to discovered. Requires `location_id`.
*   `"spawn_entity"`: Create new entity instance. Requires `entity_id`, `location_id`.
*   `"reward"`: Grant rewards (gold, reputation, items). Dictionary of currencies and reputation gains.

*You can attach UI feedback to payloads via `success_sound`, `error_sound`, and `vfx` parameters.*

### 3.6. Factions (Relational Groupings & Reputation)
File: `data/factions.json`

Factions act as an abstract interaction layer. They are relational databases that bind Entities, Locations, and Quests together under a shared identity. A Faction doesn't execute logic on its own; it provides context. It defines which Entities belong to it (`roster`), which map nodes it controls (`territory`), what repeatable operations it offers (`quest_pool`), and how it views the player based on a numerical axis (`reputation_thresholds`). You could use Factions for gangs, but also for corporate allegiances, abstract pantheons of gods, or different magical schools.

**Adding a Faction (Example: A Syndicate):**
```json
{
  "factions": [
    {
      "faction_id": "pizza_syndicate",
      "display_name": "The Pizza Syndicate",
      "description": "They control the dough.",
      "faction_color": "#ff3300",
      "emblem": "res://mods/my_name/my_mod/assets/pizza_logo.png",
      "territory": ["my_name:my_mod:pizza_shop"],
      "roster": ["my_name:my_mod:pizza_boss"],
      "reputation_thresholds": { "allied": 500, "friendly": 200, "neutral": 0, "hostile": -200 },
      "quest_pool": ["my_name:my_mod:delivery_task"]
    }
  ]
}
```

**Field Descriptions (Required & Optional):**
- `faction_id` (required, string): Namespaced ID: `author:mod:faction_name`.
- `display_name` (required, string): Faction name shown in UI.
- `description` (optional, string): Flavor text explaining the faction's purpose/history.
- `faction_color` (optional, string): Hex color code for UI borders and faction badges.
- `emblem` (optional, string): PNG path for faction logo/icon.
- `territory` (optional, array): List of location IDs this faction controls (used for UI grouping on world map).
- `roster` (optional, array): List of entity IDs who are members of this faction.
- `reputation_thresholds` (optional, object): Dictionary defining reputation tiers. Keys are tier names, values are point thresholds. Example: `{ "allied": 500, "friendly": 200, "neutral": 0, "hostile": -200 }`. Default threshold keys are arbitrary - define what makes sense for your game.
- `quest_pool` (optional, array): List of task template IDs that NPCs of this faction can offer.

**Patching a Faction:**
You can inject your custom locations into a faction's territory, add custom NPCs into their roster, or add new tasks to their job board.
```json
{
  "patches": [
    {
      "target": "guard_faction",
      "add_territory": ["my_name:my_mod:guard_station"],
      "add_roster": ["my_name:my_mod:captain"],
      "add_quest_pool": ["my_name:my_mod:bounty_task"],
      "set_reputation_thresholds": { "friendly": 100 }
    }
  ]
}
```

### 3.7. Tasks (Time-Bound Operations)
File: `data/tasks.json`

Tasks are a bridge to the **Time-Keeping System**. A Task is any operation that occupies an entity for a specific duration (measured in ticks). While typically used for repeatable jobs (like delivery gigs or crafting), Tasks fundamentally allow entities to interact with time. 

For example, a `DELIVER` task forces an entity to dead-reckon travel across the Location graph over time. You could use Tasks to simulate building a settlement, researching a technology, or forcing an NPC to follow a daily schedule.

**Task Types:** `BUILD, FIGHT, DELIVER, TRAVEL, SURVIVE, WAIT, CRAFT`. 

**Adding a Task (Example: A Delivery Job):**
```json
{
  "task_templates": [
    {
      "template_id": "my_name:my_mod:delivery_task",
      "type": "DELIVER",
      "target": "hub_safehouse",
      "travel_cost": 4, 
      "reward": { "gold": 150, "reputation": { "pizza_syndicate": 50 } },
      "complete_sound": "res://mods/my_name/my_mod/assets/sfx/task_complete.wav"
    }
  ]
}
```

**Field Descriptions (Required & Optional):**
- `template_id` (required, string): Namespaced ID: `author:mod:task_name`.
- `type` (required, string): Task category. Determines mechanic. Types: `BUILD, FIGHT, DELIVER, TRAVEL, SURVIVE, WAIT, CRAFT`.
- `target` (optional, string): For `DELIVER`/`TRAVEL` tasks, location ID where task concludes. For `BUILD`/`CRAFT`, what is being built.
- `travel_cost` (optional, number): For `DELIVER`, ticks required to complete travel portion.
- `duration` (optional, number): For `WAIT`/`CRAFT`, total ticks until completion.
- `reward` (optional, object): What the task giver grants on completion. Can include `gold`, `reputation` (faction dict), `items` (part instances).
- `complete_sound` (optional, string): WAV/OGG played when task completes.
- `description` (optional, string): Task flavor text/briefing shown to player.
- `difficulty` (optional, number): Difficulty rating (used for UI display and possibly challenge scaling).
- `repeatable` (optional, boolean, default: true): Whether this task can be done multiple times or only once.

**Patching a Task:**
```json
{
  "patches": [
    {
      "target": "base:delivery_task",
      "set_reward": { "gold": 500, "reputation": { "guard_faction": 20 } },
      "set": { "target": "my_name:my_mod:secret_lab" }
    }
  ]
}
```

To show tasks in-game, you add a `TaskProviderBackend` UI screen to an NPC or Location, linking it to the Faction:
```json
{
  "tab_id": "pizza_jobs",
  "label": "Pizza Delivery",
  "backend_class": "TaskProviderBackend",
  "faction_id": "pizza_syndicate"
}
```

### 3.8. Quests (Event-Driven State Machines)
File: `data/quests.json`

Quests are event-driven state machines used for progression. They do not cost time; instead, they passively listen to the global event bus to track if an entity has met specific criteria. Once all objectives in a stage are met, the state machine advances. While used for narrative missions, you could use the Quest system to track hidden game states, manage an intricate achievement system, or unlock new gameplay mechanics when arbitrary thresholds are reached.

Supported objective types: `has_item_tag` and `reach_location`.

**Adding a New Quest (Example: A Multi-Stage Mission):**
```json
{
  "quests": [
    {
      "quest_id": "my_name:my_mod:first_gig",
      "display_name": "First Gig",
      "description": "Your first job in the big city.",
      "stages": [
        {
          "description": "Find a weapon for the job.",
          "objectives": [
            { "type": "has_item_tag", "tag": "weapon", "count": 1 }
          ],
          "reward": { "gold": 500 }
        },
        {
          "description": "Reach the safehouse.",
          "objectives": [
            { "type": "reach_location", "location_id": "hub_safehouse" }
          ]
        }
      ],
      "reward": { "gold": 1000, "reputation": { "my_faction": 25 } },
      "complete_sound": "res://mods/my_name/my_mod/assets/sfx/quest_done.wav"
    }
  ]
}
```

**Field Descriptions (Required & Optional):**
- `quest_id` (required, string): Namespaced ID: `author:mod:quest_name`.
- `display_name` (required, string): Quest name shown in journal/UI.
- `description` (optional, string): Quest summary/briefing text.
- `stages` (required, array): Array of stage objects defining progression milestones.
  - Stage object:
    - `description` (optional, string): Stage-specific flavor text.
    - `objectives` (required, array): Array of objective checks.
      - Objective types:
        - `{ "type": "has_item_tag", "tag": "weapon", "count": 1 }` - Check inventory.
        - `{ "type": "reach_location", "location_id": "hub_safehouse" }` - Travel to location.
    - `reward` (optional, object): Reward for completing THIS stage (separate from quest reward).
- `reward` (optional, object): Final reward granted when ALL stages complete. Can include gold, reputation dicts, items.
- `complete_sound` (optional, string): WAV/OGG played when entire quest completes.
- `repeatable` (optional, boolean, default: false): Whether player can retake quest after completion.

**Patching an Existing Quest:**
```json
{
  "patches": [
    {
      "target": "base_quest",
      "add_stages": [
        {
          "objectives": [
            { "type": "reach_location", "location_id": "my_name:my_mod:secret_lab" }
          ]
        }
      ],
      "set": { "display_name": "Extended Base Quest" }
    }
  ]
}
```

### 3.9. Achievements
File: `data/achievements.json`

Achievements provide meta-progression or milestones for players. Game logic tracks statistics (like gold spent, items bought, locations discovered) and when the stat reaches the requirement, the achievement pops. Achievements are **global state trackers** - any entity can contribute to them.

**Adding a New Achievement:**
```json
{
  "achievements": [
    {
      "achievement_id": "my_name:my_mod:big_spender",
      "display_name": "High Roller",
      "description": "Spend your first 5,000 gold.",
      "stat_name": "gold_spent",
      "requirement": 5000,
      "unlock_sound": "res://mods/my_name/my_mod/assets/sfx/achievement_unlock.wav",
      "unlock_vfx": "sparkles"
    }
  ]
}
```

**Field Descriptions (Required & Optional):**
- `achievement_id` (required, string): Namespaced ID: `author:mod:achievement_name`.
- `display_name` (required, string): Achievement name shown in UI.
- `description` (optional, string): Achievement description/flavor.
- `stat_name` (required, string): Which global stat this tracks (e.g., `"gold_spent"`, `"items_bought"`, `"locations_discovered"`).
- `requirement` (required, number): Stat value needed to unlock achievement.
- `icon` (optional, string): PNG path for achievement icon.
- `unlock_sound` (optional, string): WAV/OGG played when achieved.
- `unlock_vfx` (optional, string): Visual effect ID for achievement unlock (e.g., `"sparkles"`, `"confetti"`).
- `hidden` (optional, boolean): If true, achievement is not shown until unlocked.

**Patching an Existing Achievement:**
```json
{
  "patches": [
    {
      "target": "base:big_spender",
      "set": { "requirement": 10000, "description": "Spend 10,000 gold." }
    }
  ]
}
```

### 3.10. Mod Config (Global Settings & UI Reskins)
File: `data/config.json`

Your `config.json` is **deep-merged** into the base game config. This allows you to globally rename the game, alter balance variables, change UI text, or register default fallback sprites without touching the core files. This is where you define global game constants, translations, and aesthetic overrides.

**Supported Config Categories:**

**`game` (Core Game Settings):**
- `title` (string): Game name displayed in UI header.
- `tagline` (string): Subtitle/tagline.
- `starting_money` (object): Initial player currency. Example: `{ "gold": 1000 }`.
- `starting_location` (string): Location ID where player begins.
- `starting_discovered_locations` (array): List of location IDs player starts knowing about.
- `ticks_per_day` (number): How many ticks = 1 in-game day.
- `ticks_per_hour` (number): How many ticks = 1 in-game hour.

**`balance` (Economy & Mechanics):**
- `sell_price_ratio` (number): Multiplier for NPC sell-back prices (e.g., 0.5 = sell for 50% of buy price).
- `default_travel_cost_ticks` (number): Default ticks to travel between connected locations (can be overridden per-connection).
- `shop_restock_day_hour` (string): Time when NPC inventory restocks (e.g., `"6:00"`).
- `repair_cost_multiplier` (number): Multiplier on repair costs based on item condition.

**`ui` (User Interface):**
- `currency_symbol` (string): Symbol displayed next to currency values (e.g., `"$"`).
- `time_advance_buttons` (array): List of time skip buttons shown to player (e.g., `["1 hour", "1 day"]`).
- `strings` (object): Dictionary for UI text overrides (translation/localization). Example: `{ "menu_button": "Grimoire" }`.
- `default_sprites` (object): Fallback PNG paths keyed by tag. Example: `{ "parts": { "clothing": "res://assets/icon_clothing.png" } }`.
- `theme` (object): Global color & font reskins:
  - `primary_color`, `secondary_color`, `bg_color` (hex strings)
  - `font_main`, `font_mono` (TTF paths)
- `sounds` (object): Global UI sound effects. Example: `{ "hover": "res://sfx/ui_hover.wav", "click": "res://sfx/ui_click.wav" }`.

**`stats` (Stat System Configuration):**
- `groups` (object): Organize stats into display categories. Example: `{ "combat": ["strength", "power"], "survival": ["stamina", "health_max"] }`.

**Example `config.json` patch:**
```json
{
  "game": {
    "title": "Fantasy Syndicate",
    "tagline": "Upgrade your magic and survive.",
    "starting_money": 1000
  },
  "balance": {
    "sell_price_ratio": 0.8
  },
  "ui": {
    "currency_symbol": "$",
    "strings": {
      "menu_button": "Grimoire",
      "day_format": "Cycle %d"
    },
    "default_sprites": {
      "parts": {
        "clothing": "res://mods/my_name/my_mod/assets/icon_clothing.png"
      }
    },
    "theme": {
      "primary_color": "#ff0044",
      "bg_color": "#111111",
      "font_main": "res://mods/my_name/my_mod/assets/fonts/fantasy.ttf"
    },
    "sounds": {
      "hover": "res://mods/my_name/my_mod/assets/sfx/ui_hover.wav",
      "click": "res://mods/my_name/my_mod/assets/sfx/ui_click.wav"
    }
  }
}
```

---

## 4. Advanced Modding: Script Hooks

If you need an item, quest, or NPC to execute unique logic that JSON can't handle, you can attach a **Script Hook**.

1. Create a script extending `ScriptHook` (`res://mods/my_name/my_mod/scripts/my_hook.gd`).
2. Override the virtual methods you need.
3. Link it in your JSON using `"script_path": "res://mods/my_name/my_mod/scripts/my_hook.gd"`.

**Common Hooks:**
*   `on_equip(entity, instance)` / `on_unequip(entity, instance)`
*   `on_part_attached(assembly, socket_id, instance)`
*   `on_tick(entity, tick)` / `on_day_start(entity, day)`
*   `get_buy_price(instance, buyer) -> int` (Override market economy)

*Note: Mods with GDScript files will trigger a security warning in the console when loaded, as they can execute arbitrary code.*

---

## 5. The Art Pipeline & Sprite Fallbacks

The engine uses a smart, 4-step hierarchy to find the sprite for your part or location:
1.  **Explicit JSON Link (Best Practice):** If your JSON has `"sprite": "res://mods/my_name/my_mod/assets/image.png"`, it loads that.
2.  **Magic Filename Match:** Searches `res://assets/generated/` for an image starting with your item's `"id"`.
3.  **Config Default Tags:** Checks the deep-merged `config.json` to see if a default sprite is assigned to any of the item's `"tags"`.
4.  **Global Fallback:** Renders the global fallback icon (the holographic question mark) so the game never crashes.

---

---

## 7. Data Type Conventions & Field Naming

To ensure your mods integrate seamlessly with other mods and the omni-framework, follow these conventions:

**ID Fields (Always Namespaced Strings):**
- Part/Entity/Quest/Faction/Location/Task IDs use format: `author:mod:name`
- Within patches, use `"target"` to reference the ID being patched (never `"id"`).
- Global/singleton entities use `"global"` as the entity_id.

**Currency & Reward Fields (Always Objects/Dictionaries):**
- `price` is ALWAYS `{ "currency_id": amount }`, never a single number.
- `currencies` (on entities) is ALWAYS `{ "currency_id": amount }`, never a list.
- `reward` (on tasks/quests) can include: `{ "gold": 100, "reputation": { "faction_id": 50 }, "items": [...] }`.

**Stat Fields (Always Objects/Dictionaries):**
- `stats` on parts/entities is ALWAYS `{ "stat_name": modifier }`.
- Stats ending in `_max` (e.g., `health_max`, `mana_max`) define capacity. Don't create both `mana` and `mana_max` without careful design.

**Array vs Object Decisions:**
- `tags` / `required_tags`: Arrays (multiple values, order-independent).
- `connections`: Can be array `["loc1", "loc2"]` OR object `{ "loc1": cost, "loc2": cost }` - object preferred for costs.
- `interaction` / `screen`: Array of objects (multiple screens per entity/location).
- `inventory`: Array of instance objects.
- `assembly_socket_map`: Object mapping socket_id → instance_id.

**Boolean vs String Fields:**
- `enabled`: Boolean (on mod.json, flags).
- `type` (on tasks/challenges): String enum (`"DELIVER"`, `"CRAFT"`, etc.).
- `backend_class`: String class name (`"ExchangeBackend"`, etc.).
- `flag_id`: String identifier within entity's `flags` object.

**Paths (Always res:// Relative):**
- `sprite`, `portrait`, `emblem`, `map_icon`: PNG paths.
- `equip_sound`, `dialogue_blip`, `complete_sound`: WAV/OGG paths.
- `music_track`, `ambient_sound`: OGG paths (preferred for long audio).
- `script_path`: Path to GDScript hook file.

---

## 8. Modding Checklist

*   [ ] Did I put my files in `mods/<author_id>/<mod_id>/`?
*   [ ] Did I define my mod manifest (`mod.json`) with `name`, `version`, `load_order`, `enabled`, and `dependencies`?
*   [ ] Are my custom IDs properly namespaced (`author_id:mod_id:name`)?
*   [ ] Did I add my game's physical laws (Stats/Currencies) to `definitions.json` if needed?
*   [ ] Does every item have a `price` field (object, not number) so it can be sold?
*   [ ] If my item uses stat modifiers, did I test the math against capacity (`_max` budgets)?
*   [ ] Are my explicit `"sprite"`, `"portrait"`, `"emblem"` links pointing to correct PNG paths?
*   [ ] Did I verify all `.wav` and `.ogg` paths for audio exist?
*   [ ] If I have no explicit sprite, did I register a default tag sprite in my mod's `data/config.json`?
*   [ ] If I'm adding a new location, did I patch existing neighbouring locations to list it in their `connections`?
*   [ ] If I'm patching data, did I use `"target"` (the ID to patch) NOT `"id"` (which creates a new object)?
*   [ ] Did I use `modify_screen` / `modify_interaction` rather than replacing entire arrays when extending?
*   [ ] Are all action payloads properly structured with `conditions` and `action_payload` blocks?
*   [ ] Did I use the correct Currency/Reward format everywhere (objects, not numbers)?
*   [ ] Did I avoid editing any file under `data/` or `scripts/`? Everything should live in my mod folder.

Happy modding.