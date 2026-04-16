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
  "dependencies": []
}
```
*Mods with a lower `load_order` load first. Higher `load_order` mods will override lower ones in the event of a config conflict.*

**Namespacing Rule:** All custom part IDs and entity IDs you define in your JSON must use your unique namespace: `author_id:mod_id:part_name` (e.g., `my_name:my_mod:magic_sword`).

---

## 3. Modding Core Systems (Examples)

For every system, you have two options: **Add** a completely new object, or **Patch** an existing one. Both are done in the same file.

### 3.1. Root Definitions (Stats & Currencies)
File: `data/definitions.json`

Define your game's physical laws here. A modder shouldn't be stuck with hardcoded stats if they are building a different genre. You can define new global standards.

```json
{
  "currencies": ["gold", "gems", "credits"],
  "stats": ["strength", "agility", "mana", "stamina"]
}
```

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
      "custom_field_label": "Kill Count",
      "script_path": "res://mods/my_name/my_mod/scripts/flaming_sword.gd"
    }
  ]
}
```
*Properties:*
*   `tags`: Defines what this part is and what sockets it can fit into.
*   `required_tags`: The parent part/entity must have these tags for this part to be attached.
*   `sprite`, `ui_color`, `equip_sound`: Rich UI and audio presentation options. `ui_color` can be used for item rarity or elemental borders.
*   `equippable`: If true, this item can be equipped directly by an entity.
*   `provides_sockets`: Defines sub-slots this part creates when equipped.
*   `stats`: Stats with `_max` (like `mana_max`) define progress bar capacities. Standard stats (like `strength`) are flat attributes.

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
      "flags": {
        "met_player": false
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

**Inventory Shops vs. Catalog Shops:**
There are two primary ways to create a functional store in your game. Both perfectly support multi-currency:
*   **Inventory Shops (`ExchangeBackend`):** Sells physical *Instances* directly out of an Entity's `inventory` array. Once the NPC runs out of an item, it's gone until they are given a restock action. Uses real game economy.
    *   *Config:* `"backend_class": "ExchangeBackend"`
    *   *Required:* Define `"source_inventory"` (e.g., `"entity:npc_merchant"`) and `"destination_inventory"` (e.g., `"player"`). 
*   **Catalog Shops (`ListBackend`):** Acts as an infinite vending machine. Sells raw `Part` templates directly from the database (like an MMO vendor).
    *   *Config:* `"backend_class": "ListBackend"` and `"data_source": "catalog"`
    *   *Required:* You must attach a primary action to allow purchasing: `"action_payload": {"type": "buy_item"}`

**Currency & Pricing Rules:**
A Part's `"price"` property is a dictionary of currencies and their respective values. This allows items to natively cost multiple currencies simultaneously!
*   Use `"price": { "gold": 500 }` for a standard item.
*   Use `"price": { "gold": 10, "gems": 20 }` for an item that requires mixed currencies to purchase.
*   Use `"price_modifier": 0.1` in a shop's config to apply an exchange rate multiplier (e.g. all values in the dictionary will be multiplied by 0.1 at this specific shop).

*   **`AssemblyEditorBackend` (Workbenches):** Lets players modify their body/gear. Use `editable_tags` to restrict what they can attach (e.g., `["weapon"]` for an armory bench).
*   **`ExchangeBackend` (Shops):** Handled via the *Inventory Shop* method above. Reverse the source/destination to create a "Sell" screen. *(Note: Because currencies are local to each entity, an NPC vendor will literally run out of money unless their entity is restocked!)*
*   **`ListBackend` (Data Displays):** Shows lists like `"player:inventory"` or `"player:fleet"`. Use `action_payload` to trigger events when clicked.
*   **`ChallengeBackend` (Stat Checks):** Allows the player to attempt instantaneous challenges. You define a `required_stat` (e.g., `"power"`) and `required_value`. If the player meets or beats the stat, they succeed and trigger a `reward` or `action_payload`.

**Action Payloads & The Condition System (Modifying State via JSON):**
Many screens and quest rewards support an `action_payload` object. This is how you manipulate game state or trigger events strictly through JSON. You can also gate these using a nested `conditions` block.
```json
{
  "conditions": {
    "AND": [
      { "type": "has_flag", "entity_id": "global", "flag_id": "boss_defeated", "value": true },
      { "type": "stat_greater_than", "stat": "strength", "value": 15 }
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
*You can attach rich UI feedback directly to payloads via `success_sound`, `error_sound`, and `vfx` parameters.*

*Common payload types:* `"start_task"`, `"start_quest"`, `"consume"`, `"unlock_location"`, `"spawn_entity"`, and `"set_flag"`. If `"entity_id"` or `"currency_id"` are omitted, payloads default to affecting the player entity.

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
      "reward": { "gold": 150, "reputation": { "pizza_syndicate": 50 } }
    }
  ]
}
```

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
      "stages": [
        {
          "objectives": [
            { "type": "has_item_tag", "tag": "weapon", "count": 1 }
          ],
          "reward": { "gold": 500 }
        },
        {
          "objectives": [
            { "type": "reach_location", "location_id": "hub_safehouse" }
          ]
        }
      ],
      "reward": { "gold": 1000 },
      "complete_sound": "res://mods/my_name/my_mod/assets/sfx/quest_done.wav"
    }
  ]
}
```

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

Achievements provide meta-progression or milestones for players. Game logic tracks statistics (like gold spent, items bought) and when the stat reaches the requirement, the achievement pops.

**Adding a New Achievement:**
```json
{
  "achievements": [
    {
      "achievement_id": "my_name:my_mod:big_spender",
      "display_name": "High Roller",
      "description": "Spend your first 5,000 gold.",
      "requirement": 5000
    }
  ]
}
```

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

Your `config.json` is **deep-merged** into the base game config. This allows you to globally rename the game, alter balance variables, change UI text, or register default fallback sprites without touching the core files.

**Supported Config Categories:**
*   `game`: `title`, `tagline`, `starting_money`, `starting_location`, `ticks_per_day`, `starting_discovered_locations`.
*   `balance`: `sell_price_ratio`, `default_travel_cost_ticks`, `shop_restock_day_hour`, `repair_cost_multiplier`.
*   `ui`: `currency_symbol`, `time_advance_buttons`, `strings` (for translation overrides), `default_sprites`, `theme` (global color & font reskins), `sounds` (global UI sound effects).
*   `stats`: `groups` (defines stat categories and their UI representation).

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

## 6. Modding Checklist

*   [ ] Did I put my files in `mods/<author_id>/<mod_id>/`?
*   [ ] Did I define my mod dependencies (`"dependencies": ["author:other_mod"]`) in `mod.json`?
*   [ ] Are my custom IDs properly namespaced (`author_id:mod_id:name`)?
*   [ ] Did I define my game's physical laws (Stats/Currencies) in `definitions.json`?
*   [ ] Does my item have a base price so it can be sold?
*   [ ] If my item takes up stats like mana or stamina, did I test the math against the `_max` budgets?
*   [ ] Are my explicit `"sprite"` links pointing to the correct `.png` paths?
*   [ ] Did I verify my `.wav` or `.ogg` paths for custom audio/UI sounds?
*   [ ] If I have no explicit sprite, did I register a default tag sprite in my mod's `data/config.json`?
*   [ ] If I'm adding a new location, did I patch the neighbouring locations to list it in their `connections`?
*   [ ] If I'm patching a part, did I use `"target"` (the ID to patch) not `"id"` (which would create a new part)?
*   [ ] Did I use `modify_screen` rather than overriding the entire location data when extending an existing UI screen?
*   [ ] Did I avoid editing any file under `data/` or `scripts/`? Everything should live in my mod folder.

Happy modding.