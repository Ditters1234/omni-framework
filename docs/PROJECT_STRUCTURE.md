# Omni-Framework — Project Structure

This document is the canonical reference for the engine's folder layout, autoloads, core systems, UI framework, and theme architecture. It is a living outline — implementation details will be fleshed out as each system is built.

---

## What We Are Building

**Omni-Framework** is a single-player game engine built on Godot 4. The goal is a fully modular, JSON-driven platform where the *engine provides systems* and *data provides content*. No game genre is baked in. The same engine can run a sci-fi colony sim, a cyberpunk trading game, or a fantasy RPG without code changes.

The engine ships with:
- A **data loading pipeline** that processes JSON templates and mod patches at startup.
- A set of **core runtime systems** (stats, quests, tasks, factions, etc.) driven entirely by that data.
- A **UI framework** composed of reusable screen components wired to backend classes.
- A **centralized Godot Theme** that can be reskinned at runtime via `config.json`.
- A **mod loader** that handles discovery, dependency resolution, and two-phase patching.

### Key Dependency: Any-JSON (`A2J`)

The engine uses the **[Any-JSON](https://github.com/phosxd/Any-JSON)** addon (v2.0.1) by phosxd for all runtime JSON serialization. Installed at `addons/A2J/`, it exposes a global autoload named `A2J` with two core methods:

```gdscript
A2J.to_json(item: Variant, ruleset: Dictionary = {}) -> Dictionary
A2J.from_json(ajson: Dictionary, ruleset: Dictionary = {}) -> Variant
```

It supports every serializable Godot Variant type (all vectors, colors, transforms, packed arrays, custom objects, etc.) with no data loss. Custom classes are registered once at startup via `A2J.object_registry`.

**Two distinct JSON layers exist in this project:**

| Layer | What it handles | Tool used |
|---|---|---|
| **Template data** (parts, entities, locations, etc.) | Human-authored mod files read at boot | `FileAccess` + built-in `JSON.parse_string()` → plain `Dictionary` |
| **Save data** (runtime state, entity instances, inventories) | Typed GDScript objects serialized to `user://saves/` | `A2J.to_json()` / `A2J.from_json()` |

Template files stay as plain, human-readable JSON Dictionaries — modders write them by hand and the registries parse them as dicts. Save files use `A2J` so that typed runtime objects (`EntityInstance`, `PartInstance`, `GameState`, etc.) round-trip perfectly without losing type information.

**Rulesets** can be passed to either call to control serialization per-class, per-depth, or globally — for example, excluding private properties from saves, or blocking `GDScript` class deserialization for security:

```gdscript
var safe_ruleset := {
    "@global": { "exclude_private_properties": true },
    "EntityInstance@des": { "class_exclusions": ["GDScript"] }
}
var state = A2J.from_json(raw_data, safe_ruleset)
```

---

## Folder Structure

```
res://
├── autoloads/              # Global singletons (registered in Project Settings)
│   ├── game_events.gd      # Signal bus
│   ├── mod_loader.gd       # Mod discovery, ordering, and loading
│   ├── data_manager.gd     # Central template registry (populated at boot)
│   ├── game_state.gd       # Runtime state (player, location, tick)
│   ├── save_manager.gd     # JSON save/load (user://saves/)
│   ├── time_keeper.gd      # Tick clock and time event dispatch
│   ├── audio_manager.gd    # Sound effect and music playback
│   ├── ui_router.gd        # Screen navigation stack
│   └── ai_manager.gd       # AI provider abstraction — routes to configured backend
│
├── systems/                # Core runtime systems (instantiated by autoloads)
│   ├── loaders/            # Data loaders — parse JSON, apply patches
│   │   ├── definition_loader.gd
│   │   ├── parts_registry.gd
│   │   ├── entity_registry.gd
│   │   ├── location_graph.gd
│   │   ├── faction_registry.gd
│   │   ├── quest_registry.gd
│   │   ├── task_registry.gd
│   │   ├── achievement_registry.gd
│   │   └── config_loader.gd
│   ├── ai/                     # AI-related systems
│   │   ├── limboai/            # LimboAI resources — internal engine use only
│   │   │   ├── states/         # HSM GDScript state classes (e.g. quest_stage_state.gd)
│   │   │   └── behaviors/      # Behavior tree .tres resources for scripted NPCs
│   │   └── providers/          # AIManager backend implementations
│   │       ├── openai_provider.gd      # OpenAI-compatible REST (covers Ollama, LM Studio, OpenAI)
│   │       ├── anthropic_provider.gd   # Anthropic Claude REST API
│   │       └── nobodywho_provider.gd   # Embedded local inference via NobodyWho node
│   ├── stat_manager.gd         # Stat calculation, clamping, modifier stacking
│   ├── condition_evaluator.gd  # Evaluates JSON condition blocks (AND/OR trees)
│   ├── action_dispatcher.gd    # Executes action_payload objects
│   ├── quest_tracker.gd        # Quest HSM — built on LimboAI, driven by quests.json
│   ├── task_runner.gd          # Tick-driven task execution
│   └── script_hook_loader.gd   # Loads and caches GDScript mod hooks
│
├── ui/                     # All scenes and scripts for the UI layer
│   ├── main.tscn            # Root scene — top-level layout shell
│   ├── theme/
│   │   ├── omni_theme.tres  # Centralized Godot Theme resource (THE source of truth)
│   │   └── theme_applier.gd # Reads config.json ui.theme overrides, patches the .tres at runtime
│   ├── screens/             # Full-screen views (managed by UIRouter)
│   │   ├── world_map/
│   │   │   ├── world_map_screen.tscn
│   │   │   └── world_map_screen.gd
│   │   ├── location_view/
│   │   │   ├── location_view_screen.tscn   # Shows location name, bg, and tab list
│   │   │   └── location_view_screen.gd
│   │   └── backends/        # One scene per backend_class type
│   │       ├── assembly_editor_screen.tscn   # AssemblyEditorBackend
│   │       ├── exchange_screen.tscn          # ExchangeBackend
│   │       ├── list_screen.tscn              # ListBackend
│   │       ├── challenge_screen.tscn         # ChallengeBackend
│   │       ├── task_provider_screen.tscn     # TaskProviderBackend
│   │       ├── catalog_list_screen.tscn      # CatalogListBackend
│   │       └── dialogue_screen.tscn          # DialogueBackend — wraps Dialogue Manager
│   └── components/          # Reusable UI widgets (used inside screens)
│       ├── part_card.tscn           # Part display: icon, name, stats, price
│       ├── entity_portrait.tscn     # Entity avatar, name, description
│       ├── currency_display.tscn    # Currency value + symbol/icon
│       ├── stat_bar.tscn            # Labeled progress bar (health, mana, etc.)
│       ├── stat_sheet.tscn          # Full stat list for an entity
│       ├── tab_panel.tscn           # Reusable tabbed container (used by location_view)
│       └── notification_popup.tscn  # Achievement / quest update popups
│
├── core/                   # Base classes and shared utilities
│   ├── script_hook.gd      # Base class all mod script hooks extend
│   ├── part_instance.gd    # Runtime part instance (wraps template + instance data)
│   ├── entity_instance.gd  # Runtime entity instance
│   └── constants.gd        # Engine-wide string constants, enums
│
├── mods/                   # ALL game content lives here — including the base game
│   ├── base/               # The base game mod — load_order: 0, always required
│   │   ├── mod.json        # { "id": "base", "load_order": 0, "dependencies": [] }
│   │   ├── data/           # Base game JSON — the "base:" namespace
│   │   │   ├── definitions.json
│   │   │   ├── parts.json
│   │   │   ├── entities.json
│   │   │   ├── locations.json
│   │   │   ├── factions.json
│   │   │   ├── quests.json
│   │   │   ├── tasks.json
│   │   │   ├── achievements.json
│   │   │   └── config.json
│   │   ├── dialogue/       # Base game .dialogue files
│   │   ├── scripts/        # Base game ScriptHook extensions (if any)
│   │   └── assets/         # fonts/, icons/, sfx/, music/
│   │
│   └── <author_id>/        # Third-party and user mods
│       └── <mod_id>/
│           ├── mod.json
│           ├── data/
│           ├── dialogue/
│           ├── scripts/
│           └── assets/
│
├── tests/                  # ⚠️ DEV ONLY — GUT test suites, excluded from export
│   ├── unit/               # Tests for isolated systems (StatManager, ConditionEvaluator, etc.)
│   └── integration/        # Tests for full pipelines (mod loading, save/load, etc.)
│
└── addons/                 # Third-party plugins
    ├── A2J/                # Any-JSON v2.0.1 — lossless variant serialization (phosxd)
    ├── gut/                # GUT — Godot Unit Testing framework ⚠️ DEV ONLY
    ├── limboai/            # LimboAI — HSM for quests, behavior trees for NPCs (limbonaut)
    ├── dialogue_manager/   # Dialogue Manager v3.x — branching NPC dialogue (nathanhoad)
    ├── nobodywho/          # NobodyWho — embedded local LLM inference (no server needed)
    └── ziva_agent/         # ⚠️ DEV ONLY — AI assistant integration, remove before release
```

---

## Autoloads

All autoloads are registered as global singletons in **Project Settings → Autoload**. They are accessible from anywhere without imports.

### `GameEvents` (`autoloads/game_events.gd`)
The global signal bus. All cross-system communication goes here. No system should hold a direct reference to another — instead, emit and listen to signals on `GameEvents`.

Key signals (non-exhaustive):
```gdscript
signal tick_advanced(tick: int)
signal day_started(day: int)
signal player_location_changed(location_id: String)
signal part_equipped(entity_id: String, socket_id: String, instance_id: String)
signal part_unequipped(entity_id: String, socket_id: String, instance_id: String)
signal quest_stage_advanced(quest_id: String, stage_index: int)
signal quest_completed(quest_id: String)
signal task_completed(task_id: String, entity_id: String)
signal achievement_unlocked(achievement_id: String)
signal currency_changed(entity_id: String, currency_id: String, new_amount: float)
signal flag_changed(entity_id: String, flag_id: String, value: bool)
signal dialogue_started(entity_id: String, dialogue_resource: String)
signal dialogue_ended(entity_id: String, dialogue_resource: String)
signal ai_response_received(request_id: String, response: String)
signal ai_token_received(request_id: String, token: String)
signal ai_error(request_id: String, message: String)
signal mod_load_error(mod_id: String, message: String)
```

### `ModLoader` (`autoloads/mod_loader.gd`)
Scans `res://mods/` at startup. Reads each `mod.json`, resolves dependencies, builds a load order, then drives the two-phase loading pipeline via `DataManager`.

Responsibilities:
- Discover mod folders and validate manifests.
- Topological sort by `load_order` and dependency graph.
- Phase 1: Pass all `data/*.json` addition files to `DataManager`.
- Phase 2: Pass all `patches` blocks to `DataManager` for merging.
- Emit `mod_load_error` on `GameEvents` for any failures (non-fatal).

### `DataManager` (`autoloads/data_manager.gd`)
The central template registry. After `ModLoader` runs, `DataManager` holds the final merged state of all loaded data. All runtime systems query `DataManager` for templates.

Key methods:
```gdscript
func get_part(id: String) -> Dictionary
func get_entity_template(id: String) -> Dictionary
func get_location(id: String) -> Dictionary
func get_faction(id: String) -> Dictionary
func get_quest(id: String) -> Dictionary
func get_task_template(id: String) -> Dictionary
func get_achievement(id: String) -> Dictionary
func get_config() -> Dictionary
func get_definitions() -> Dictionary
```

### `GameState` (`autoloads/game_state.gd`)
Holds the active runtime state of the game session. This is what gets serialized to a save file by `SaveManager` via `A2J.to_json()`.

Contains:
- `player: EntityInstance` — the active player entity (with live stats, inventory, flags).
- `entity_instances: Dictionary` — all live NPC/entity instances keyed by entity_id.
- `current_location_id: String` — where the player currently is.
- `tick: int` — current game tick counter.
- `day: int` — current in-game day.
- `active_quests: Dictionary` — quest_id → current stage index.
- `active_tasks: Array` — in-progress task instances.
- `achievement_stats: Dictionary` — global tracking stats (gold_spent, etc.).

### `SaveManager` (`autoloads/save_manager.gd`)
Reads and writes `GameState` as human-readable JSON to `user://saves/`. Uses `A2J` for lossless typed serialization of all runtime objects. Handles schema versioning so old saves can be migrated forward.

All custom runtime classes that appear in save data (`EntityInstance`, `PartInstance`, `GameState`, etc.) must be registered in `A2J.object_registry` during `_ready()` before any save/load can occur.

Key methods:
```gdscript
func save_game(slot: int) -> void
func load_game(slot: int) -> void
func list_save_slots() -> Array[Dictionary]  # Returns slot metadata (date, playtime, etc.)
func delete_save(slot: int) -> void
func _register_types() -> void  # Registers all serializable classes with A2J.object_registry
```

Usage pattern:
```gdscript
# Saving
var raw: Dictionary = A2J.to_json(GameState, _save_ruleset)
FileAccess.open("user://saves/slot_%d.json" % slot, FileAccess.WRITE).store_string(
    JSON.stringify(raw, "\t")
)

# Loading
var raw: Dictionary = JSON.parse_string(
    FileAccess.get_file_as_string("user://saves/slot_%d.json" % slot)
)
A2J.from_json(raw, _save_ruleset)  # Populates GameState in place
```

### `TimeKeeper` (`autoloads/time_keeper.gd`)
The tick clock. Exposes methods for advancing time (manually or via UI buttons). Dispatches `tick_advanced` and `day_started` signals on `GameEvents`. Drives `TaskRunner` to advance in-progress tasks.

Key methods:
```gdscript
func advance_ticks(amount: int) -> void
func advance_to_next_day() -> void
func get_current_tick() -> int
func get_current_day() -> int
func get_time_string() -> String  # e.g., "Day 3, 14:00"
```

### `AudioManager` (`autoloads/audio_manager.gd`)
Wraps Godot `AudioStreamPlayer` pools for SFX and a dedicated player for music. Reads default sound paths from `config.json ui.sounds`. One-shot SFX calls from anywhere in the engine go here.

Key methods:
```gdscript
func play_sfx(path: String) -> void
func play_music(path: String, crossfade: bool = true) -> void
func stop_music() -> void
```

### `UIRouter` (`autoloads/ui_router.gd`)
Manages the screen navigation stack. Screens push and pop; the router handles transitions and keeps history for back-navigation. All screen changes go through here — no scene switches happen directly.

Key methods:
```gdscript
func push_screen(screen_id: String, params: Dictionary = {}) -> void
func pop_screen() -> void
func replace_screen(screen_id: String, params: Dictionary = {}) -> void
func get_current_screen() -> String
```

### `AIManager` (`autoloads/ai_manager.gd`)
Abstracts all LLM calls behind a single interface. Reads the `ai` block from the merged `config.json` at startup and instantiates the appropriate provider. Modders and script hooks call `AIManager` directly — they never reference a specific provider.

If `ai.enabled` is `false` or the `ai` block is absent, all calls silently no-op and return empty strings. This means games that don't use AI work without any configuration.

Supported providers (set via `config.json ai.provider`):

| Value | Backend | Notes |
|---|---|---|
| `"openai_compatible"` | `OpenAIProvider` | Covers Ollama, LM Studio, Jan, OpenAI, and any OpenAI-compatible endpoint |
| `"anthropic"` | `AnthropicProvider` | Anthropic Claude REST API |
| `"nobodywho"` | `NobodyWhoProvider` | Embedded local inference via NobodyWho GDExtension node — no server required |
| `"disabled"` | — | All calls no-op silently |

Key methods:
```gdscript
# Fire-and-forget with callback
func generate(prompt: String, context: Array = [], callback: Callable = Callable()) -> String

# Awaitable
func generate_async(prompt: String, context: Array = []) -> String

# Streaming — emits ai_token_received on GameEvents per token, then ai_response_received when done
func generate_streaming(prompt: String, context: Array = []) -> String  # returns request_id

func is_available() -> bool   # Returns false if disabled or provider failed to init
func get_provider_name() -> String
```

Usage from a script hook or dialogue script:
```gdscript
# Simple one-shot call
var response = await AIManager.generate_async("Describe this merchant in one sentence.", [
    {"role": "system", "content": "You are an NPC in a gritty cyberpunk trading game."}
])

# Streaming (typewriter effect)
var request_id = AIManager.generate_streaming(prompt, context)
GameEvents.ai_token_received.connect(func(id, token):
    if id == request_id: label.text += token
)
```

---

## Core Systems

These are not autoloads — they are classes instantiated and owned by the autoloads above.

| Class | Owner | Purpose |
|---|---|---|
| `DefinitionLoader` | DataManager | Parses `definitions.json`, validates stat pairs |
| `PartsRegistry` | DataManager | Part template storage and patch application |
| `EntityRegistry` | DataManager | Entity template storage and patch application |
| `LocationGraph` | DataManager | Graph of locations; exposes pathfinding |
| `FactionRegistry` | DataManager | Faction data + reputation threshold queries |
| `QuestRegistry` | DataManager | Quest template storage |
| `TaskRegistry` | DataManager | Task template storage |
| `AchievementRegistry` | DataManager | Achievement template storage |
| `ConfigLoader` | DataManager | Deep-merges `config.json` across all mods |
| `StatManager` | Systems utility | Stat calculation, modifier stacking, clamping |
| `ConditionEvaluator` | Systems utility | Evaluates JSON `conditions` blocks (AND/OR trees) |
| `ActionDispatcher` | Systems utility | Executes `action_payload` objects, emits events |
| `QuestTracker` | GameState | Quest HSM built on LimboAI — reads `quests.json`, creates `LimboHSM` nodes dynamically; JSON schema is unchanged |
| `TaskRunner` | TimeKeeper | Advances active tasks on each tick |
| `ScriptHookLoader` | ModLoader | Loads, validates, and caches GDScript mod hooks |

### Base Classes (in `core/`)

**`ScriptHook` (`core/script_hook.gd`)**
The base class all mod script hooks must extend. Provides empty virtual methods; the engine calls into them at the appropriate moments.

```gdscript
class_name ScriptHook
extends RefCounted

func on_equip(entity: Dictionary, instance: Dictionary) -> void: pass
func on_unequip(entity: Dictionary, instance: Dictionary) -> void: pass
func on_part_attached(assembly: Dictionary, socket_id: String, instance: Dictionary) -> void: pass
func on_tick(entity: Dictionary, tick: int) -> void: pass
func on_day_start(entity: Dictionary, day: int) -> void: pass
func get_buy_price(instance: Dictionary, buyer: Dictionary) -> int: return -1  # -1 = use default
```

---

## UI Framework

The UI is built as a set of composable scenes. `UIRouter` loads and unloads screens; screens are composed from reusable components.

### Navigation Flow

```
main.tscn (root, always present)
 ├── WorldMapScreen      (default view — shows the location graph)
 └── LocationViewScreen  (shows when player enters a location)
      └── TabPanel       (one tab per screen defined in the location's `screens` array)
           └── [Backend Screen]  (AssemblyEditorScreen, ExchangeScreen, etc.)
```

### Backend Screen → Backend Class Mapping

| `backend_class` in JSON | Scene | Functionality |
|---|---|---|
| `AssemblyEditorBackend` | `assembly_editor_screen.tscn` | Attach/detach parts into sockets |
| `ExchangeBackend` | `exchange_screen.tscn` | Buy/sell part instances from entity inventory |
| `ListBackend` | `list_screen.tscn` | Display lists (inventory, fleet, etc.) |
| `ChallengeBackend` | `challenge_screen.tscn` | Stat-check attempt with pass/fail outcomes |
| `TaskProviderBackend` | `task_provider_screen.tscn` | Job board — shows faction task pool |
| `CatalogListBackend` | `catalog_list_screen.tscn` | Infinite vendor — sells part templates |
| `DialogueBackend` | `dialogue_screen.tscn` | NPC conversation — wraps Dialogue Manager; plays `dialogue_blip` audio per line |

Each backend screen receives a `params` dictionary from `UIRouter` containing the screen's JSON definition block (including `tab_id`, `backend_class`, `faction_id`, etc.).

### Reusable Components

| Component | Purpose |
|---|---|
| `PartCard` | Displays a single part: sprite, name, stat summary, price |
| `EntityPortrait` | Entity avatar image, display name, brief description |
| `CurrencyDisplay` | Shows a currency amount with symbol; updates live |
| `StatBar` | Labeled progress bar for current/max resource stats |
| `StatSheet` | Full tabular stat list for an entity |
| `TabPanel` | Tabbed container driven by a `screens` array |
| `NotificationPopup` | Floating pop-up for achievement unlocks and quest updates |

---

## Theme System

### The Centralized Theme

All UI styling lives in a **single Godot `Theme` resource**: `res://ui/theme/omni_theme.tres`.

Every UI `Control` node in the engine inherits from this theme. There are no inline `StyleBox` overrides scattered across scenes — everything flows from the one `.tres` file. This is what makes runtime reskinning via `config.json` possible.

The `.tres` defines:
- **Color constants** — `primary_color`, `secondary_color`, `bg_color`, `text_color`, `accent_color`, `danger_color`
- **StyleBoxes** — `panel`, `button_normal`, `button_hover`, `button_pressed`, `input_normal`, `card_bg`, `tab_selected`, `tab_unselected`, `progress_bar_fg`, `progress_bar_bg`
- **Font overrides** — `font_main` (body text), `font_mono` (numeric/code values), `font_heading`
- **Icons** — fallback icon, currency symbols, navigation arrows

### Runtime Theme Patching (`theme_applier.gd`)

At startup, after `ConfigLoader` finishes, `ThemeApplier` reads the `ui.theme` block from the merged config and patches the live `Theme` resource in memory. This means a mod author only needs to add a `ui.theme` block to their `config.json` — they do not ship a `.tres` file.

```gdscript
# theme_applier.gd — called by DataManager after config is fully merged
func apply_theme_overrides(theme_config: Dictionary) -> void:
    var theme: Theme = preload("res://ui/theme/omni_theme.tres")
    
    if "primary_color" in theme_config:
        theme.set_color("primary_color", "Global", Color(theme_config["primary_color"]))
    
    if "font_main" in theme_config:
        var font = load(theme_config["font_main"]) as Font
        if font:
            theme.set_font("font_main", "Global", font)
    # ... etc.
```

### Adding a New Theme Variable

1. Define the constant/font/StyleBox in `omni_theme.tres`.
2. Reference it in the relevant scene using `theme_override_*` or `get_theme_*()`.
3. Add the key to `ThemeApplier.apply_theme_overrides()` if it should be mod-overridable.
4. Document the key in the `ui.theme` section of the Modding Guide.

---

## Data Layer

### The Base Game Is a Mod

There is no privileged `data/` folder at the project root. The base game content is simply the first mod loaded — `mods/base/` — with `load_order: 0` and no dependencies. This keeps the engine entirely content-free: it ships only systems, and every piece of game data (including the base game's) flows through the same mod pipeline.

A game built on Omni-Framework ships a `mods/base/` folder containing all its core content. Community mods are added alongside it. The engine itself never needs to change.

**`mods/base/mod.json`:**
```json
{
  "name": "Base Game",
  "id": "base",
  "version": "1.0.0",
  "load_order": 0,
  "enabled": true,
  "dependencies": []
}
```

**`ModLoader` treats a missing or invalid `base` mod as a fatal boot error** — unlike all other mods, which fail non-fatally. Nothing can function without it.

### Base Game Data Files (`mods/base/data/`)

| File | Purpose |
|---|---|
| `definitions.json` | Valid stat names and currency IDs |
| `parts.json` | Part templates (items, gear, skill nodes, etc.) |
| `entities.json` | Entity templates (player, NPCs, vendors, abstract containers) |
| `locations.json` | Location graph nodes with connections and UI screens |
| `factions.json` | Faction definitions, rosters, quest pools, reputation tiers |
| `quests.json` | Quest state machine definitions |
| `tasks.json` | Repeatable time-bound task templates |
| `achievements.json` | Achievement definitions and tracking stat requirements |
| `config.json` | Global game settings, balance, UI strings, theme defaults |

### Save Data (`user://saves/`)

Save files are human-readable JSON, one file per save slot. Schema version is stored in each file header to support migration. `SaveManager` is responsible for versioning and forward-compatibility.

```
user://saves/
├── slot_0.json
├── slot_1.json
└── slot_2.json
```

---

## Mod Loading Pipeline (Detailed)

```
1. ModLoader.scan_mods()
      → Find all res://mods/*/mod.json  (base) and res://mods/*/*/mod.json  (user mods)
      → Parse and validate each manifest
      → FATAL ERROR if res://mods/base/mod.json is missing or invalid
      → Topological sort: dependencies first, then load_order, then alpha
        (base mod always sorts first — load_order: 0)

2. ModLoader.load_phase_one()  [Additions]
      For each mod in sorted order (base first, then user mods):
        → Load data/<system>.json if present
        → Pass "additions" arrays to DataManager registries
        → Register any dialogue/*.dialogue files with Dialogue Manager

3. ModLoader.load_phase_two()  [Patches]
      For each mod in sorted order:
        → Load data/<system>.json if present
        → Pass "patches" arrays to DataManager registries
        → Each registry applies patches to its merged dataset

4. DataManager → ConfigLoader.merge_configs()
      → Deep-merge all mods' config.json into base config
      → ThemeApplier.apply_theme_overrides(config["ui"]["theme"])

5. GameState.initialize_from_templates()
      → Instantiate player entity from template
      → Place entities at their starting locations
      → Initialize quest/task/achievement state

6. UIRouter.push_screen("world_map")
      → Game is ready
```

---

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| GDScript files | `snake_case.gd` | `stat_manager.gd` |
| Class names | `PascalCase` | `class_name StatManager` |
| Autoload names | `PascalCase` | `GameEvents`, `DataManager` |
| Signal names | `snake_case` | `tick_advanced` |
| Scene files | `snake_case.tscn` | `exchange_screen.tscn` |
| JSON data IDs | `author:mod:name` | `base:iron_sword` |
| Save keys | `snake_case` | `"current_location_id"` |
| Constants | `UPPER_SNAKE_CASE` | `const MAX_SAVE_SLOTS = 5` |
