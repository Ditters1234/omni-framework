# Omni-Framework - Official Modding Guide

Welcome to the **Omni-Framework** modding scene. 

This engine was built from the ground up to be a **100% data-driven** generalized game platform. You do not need to know how to write GDScript or use the Godot Engine to add new items, magic systems, NPCs, or entire worlds. If you can edit a JSON file and draw some pixel art, you can mod any game built on this platform.

This guide covers the core architecture, the system hierarchy, and provides practical examples for modifying every core game system.

---

## 1. System Architecture & Hierarchy Map

The Omni-Framework relies on a strict separation between engine logic and game data. The engine provides "Systems" (like the Parts system or the Quest system), which are entirely fueled by JSON data. 

### The Two-Phase Loading System
To ensure maximum compatibility between mods, the engine uses a **Two-Phase Loading** architecture:
1. **Phase 1 (Additions):** The base game JSON files are loaded, followed by all new items/entities/locations added by active mods.
2. **Phase 2 (Patches):** All active mods apply their "patches". Because patches run last, a patch in Mod B can successfully modify a part that was added by Mod A.

If two mods patch the exact same item, the built-in **ModValidator** handles conflict resolution. The console will clearly log which mod "won" the conflict based on their `load_order`.

### System Hierarchy Map
Here is how the core systems interact with your mod files:

```text
Game Boot
 ↳ GameEvents (Global event bus)
 ↳ ModLoader (Scans res://mods/, reads mod.json, builds load order, resolves dependencies)
    │
    ├─► Schema Definitions
    │     (Reads data/definitions.json -> Defines valid Stats, Currencies, and Laws)
    │
    ├─► Parts System
    │     (Reads data/parts.json -> Loads Mod Additions -> Applies Mod Patches)
    │
    ├─► WorldMap System
    │     (Reads data/locations.json -> Loads Mod Additions -> Applies Mod Patches)
    │     (Dynamically generates map layout and nested sub-locations)
    │
    ├─► Entities System
    │     (Reads data/entities.json -> Loads Mod Additions -> Applies Mod Patches)
    │
    ├─► Procedural Generation
    │     (Reads data/tables.json -> Generates dynamic loot and spawn tables)
    │
    ├─► Factions, Tasks, Quests, Achievements
    │     (Reads respective JSONs -> Loads Mod Additions -> Applies Mod Patches)
    │
    └─► ConfigLoader & Localization
          (Deep-merges data/config.json and localization/ text from all mods)
```

---

## 2. Developer Experience & Ergonomics

We provide top-tier tools to ensure modders don't break the game and can build efficiently:

*   **JSON Schema Validation:** The engine provides a `.schema.json` file. By associating this with your workspace in VS Code, you get full auto-complete and "red squiggly" error lines if you mistype a key or property.
*   **In-Game Debug Suite:** A built-in "God Mode" panel allows modders to:
    *   View all active Entity Flags and Global Blackboard state.
    *   Instantly teleport to any Location.
    *   Force-complete Quest stages to test branching paths and condition evaluation.
*   **String Tokens:** UI text supports dynamic variable tokens. You can write: *"Hello, {player_name}, welcome to {current_location_name}"* and the engine will evaluate it at runtime.

---

## 3. Mod Structure & Load Order

To create a mod, do not modify the base game files. Instead, create a new folder structure inside the `mods/` directory.

Your mod folder must look like this:
```text
mods/<author_id>/<mod_id>/
├── mod.json          (Mod manifest: name, dependencies, load_order)
├── data/             (JSON files to merge into the base game)
├── localization/     (Localized string tables for multi-language support)
├── scripts/          (Optional GDScript hooks)
└── assets/           (Your custom PNGs and audio)
```

### The Manifest (`mod.json`)
Every mod must have a manifest at its root:
```json
{
  "name": "My Epic Expansion",
  "version": "1.0.0",
  "load_order": 100,
  "enabled": true,
  "dependencies": ["other_author:core_library"]
}
```
*   `load_order`: Mods with a lower number load first. Higher numbers override lower ones.
*   `dependencies`: Ensures this mod is loaded *after* the listed mods.

**Namespacing Rule:** All custom IDs you define in your JSON must use your unique namespace: `author_id:mod_id:object_name` (e.g., `my_name:my_mod:magic_sword`).

---

## 4. The Universal Logic Evaluator

The biggest feature of the Omni-Framework is the **Logic Layer**. You can create complex interactions, conditional visibility, and state changes entirely within JSON.

### The Condition System
You can attach a `conditions` schema to almost any object (Locations, UI Tabs, Dialogue, Tasks, Quests). 
The system supports nested `AND`, `OR`, and `NOT` operators.

Available checks include: `has_flag`, `stat_greater_than`, `owns_item`, `is_time_between`.

```json
"conditions": {
  "AND": [
    { "type": "has_flag", "entity_id": "global", "flag_id": "dragon_defeated", "value": true },
    {
      "OR": [
        { "type": "stat_greater_than", "stat": "strength", "value": 15 },
        { "type": "owns_item", "item_tag": "magic_key" }
      ]
    }
  ]
}
```

### Expanded Action Payloads
Action payloads are used to manipulate game state. Beyond `set_flag`, you can trigger powerful engine features:
*   `spawn_entity`: Create an entity from a template at a specific location.
*   `modify_stat_permanent`: Permanently change a base stat on an instance.
*   `trigger_event`: Emit a custom string to the `GameEvents` bus.
*   `set_flag`: Set a persistent boolean on an entity or the global blackboard.

```json
"action_payload": {
  "type": "spawn_entity",
  "template_id": "my_name:my_mod:boss_monster",
  "location_id": "my_name:my_mod:dungeon_depths"
}
```

---

## 5. Modding Core Systems (Examples)

### 5.1. Root Definitions (Stats & Currencies)
File: `data/definitions.json`

Define your game's physical laws here. A modder shouldn't be stuck with "credits" and "strength" if they are building a fantasy game. You can define `gold` and `mana` as the new global standard.

```json
{
  "currencies": ["gold", "gems"],
  "stats": ["strength", "agility", "mana", "stamina"]
}
```

### 5.2. Parts (Hierarchical Data & Stat Nodes)
File: `data/parts.json`

Parts are the fundamental building blocks. A Part is any attachable node that can grant stats, require tags, and provide sockets. They can be weapons, clothing, a complex skill tree, a modular spaceship, or a spell-crafting system.

**Adding a New Part:**
```json
{
  "parts": [
    {
      "id": "my_name:my_mod:flaming_sword",
      "display_name": "Sword of Flames",
      "tags": ["weapon", "melee", "sword"],
      "required_tags": ["humanoid"],
      "price": { "gold": 250 },
      "stats": { "strength": 5, "mana_max": -10 },
      "equippable": true,
      "provides_sockets": [
        { "id": "rune_slot", "accepted_tags": ["rune"], "label": "Rune Socket" }
      ]
    }
  ]
}
```

### 5.3. Entities (Stateful Actors & Global Blackboard)
File: `data/entities.json`

Entities are the stateful actors. An Entity is a container that holds an `inventory`, equips Parts, exists at a Location, and exposes UI `interactions`. Every entity owns its own `currencies`, `reputation`, `stats`, and `flags`.

**The Global Blackboard:**
You can use the `WorldEntity` to store flags that aren't tied to a specific person. Perfect for global world states.

**Adding an Entity with Loot Tables:**
Instead of a fixed inventory, entities can point to a `loot_table_id`. The engine rolls on this table based on weights and rarity (defined in `data/tables.json`).

```json
{
  "entities": [
    {
      "entity_id": "my_name:my_mod:merchant_bob",
      "display_name": "Merchant Bob",
      "location_id": "town_square",
      "currencies": { "gold": 5000 },
      "loot_table_id": "my_name:my_mod:rare_merchant_table",
      "interactions": [
        { 
          "tab_id": "bob_shop", 
          "label": "Trade", 
          "backend_class": "ExchangeBackend",
          "source_inventory": "entity:my_name:my_mod:merchant_bob",
          "destination_inventory": "player",
          "currency_id": "gold"
        }
      ]
    }
  ]
}
```

### 5.4. Locations (Hierarchical Nodes)
File: `data/locations.json`

Locations define where entities exist and the UI screens available. Locations can now contain `sub_nodes` (e.g., a Ship Location containing a Bridge and Engine Room).

```json
{
  "locations": [
    {
      "location_id": "my_name:my_mod:castle",
      "display_name": "High Castle",
      "connections": ["plains"],
      "sub_nodes": ["my_name:my_mod:throne_room", "my_name:my_mod:dungeon"],
      "screens": []
    }
  ]
}
```

### 5.5. UI Screens & Tag-Based Auto-Injection
When defining a screen in a location or an interaction on an NPC, you assign a `backend_class` (like `ExchangeBackend` for shops, `ListBackend` for catalogs, `ChallengeBackend` for stat checks).

**Dynamic Anchors (Tag-Based Auto-Injection):**
A top-tier platform doesn't require modders to patch every shop manually. You can inject items dynamically based on tags.
```json
{
  "patches": [
    {
      "target_type": "shop",
      "with_tag": "black_market",
      "inject_items": ["my_name:my_mod:illegal_potion"]
    }
  ]
}
```

### 5.6. Quests, Tasks & Factions
*   **Factions:** Relational databases binding Entities and Locations together. Manage territory, rosters, and reputation axes.
*   **Tasks:** Time-bound operations (BUILD, FIGHT, TRAVEL, CRAFT). Connects to the Time-Keeping System.
*   **Quests:** Event-driven state machines. They passively listen to the global event bus. Use the `conditions` schema to create heavily branching narratives.

### 5.7. Localized String Tables
Move all hardcoded text into your mod's `localization/` folder to support multi-language mods easily. Instead of writing `"display_name": "Sword"`, use `"display_name": "item_sword_name"` and define the translation in your CSV or JSON localization files.

### 5.8. Mod Config (Global Settings)
File: `data/config.json`

Deep-merge into the base game config. Change UI text, balance variables, or default fallback sprites without touching core files.

---

## 6. Advanced Modding: Script Hooks

If you need unique logic that the Universal Logic Evaluator can't handle, attach a **Script Hook**.
1. Create a script extending `ScriptHook` (`res://mods/my_name/my_mod/scripts/my_hook.gd`).
2. Link it in your JSON using `"script_path": "res://mods/my_name/my_mod/scripts/my_hook.gd"`.

---

## 7. The Art Pipeline & Sprite Fallbacks

The engine uses a 4-step hierarchy to find sprites:
1.  **Explicit JSON Link:** `"sprite": "res://mods/my_name/my_mod/assets/image.png"`
2.  **Magic Filename Match:** Searches `res://assets/generated/` for the ID.
3.  **Config Default Tags:** Checks `config.json` for default sprites assigned to tags.
4.  **Global Fallback:** Renders a generic placeholder.

---

## 8. Modding Checklist

*   [ ] Did I put my files in `mods/<author_id>/<mod_id>/`?
*   [ ] Did I define my mod dependencies (`"dependencies": ["author:other_mod"]`) in `mod.json`?
*   [ ] Are my custom IDs properly namespaced (`author_id:mod_id:name`)?
*   [ ] Did I define my game's physical laws (Stats/Currencies) in `definitions.json`?
*   [ ] Are my Locations structured hierarchically using `sub_nodes` if needed?
*   [ ] Did I use the Global Blackboard (`WorldEntity`) to store global flags?
*   [ ] Did I leverage the `conditions` schema for complex logic instead of writing GDScript?
*   [ ] Did I move hardcoded strings to the `localization/` folder?
*   [ ] Did I use tag-based auto-injection (Dynamic Anchors) instead of manually patching every single shop?

Happy modding!