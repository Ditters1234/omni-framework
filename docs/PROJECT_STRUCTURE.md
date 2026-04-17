# Omni-Framework — Project Structure

This document is the canonical reference for the engine's folder layout, autoloads, core systems, UI framework, and theme architecture. It is a living outline: some sections describe the target architecture that the current repository is growing toward, and those future-facing constraints are documented here intentionally so implementation hardens in the right direction.

---

## What We Are Building

**Omni-Framework** is a single-player game engine built on Godot 4. The goal is a fully modular, JSON-driven platform where the *engine provides systems* and *data provides content*. No game genre is baked in. The same engine can run a sci-fi colony sim, a cyberpunk trading game, or a fantasy RPG without code changes.

The engine ships with:
- A **data loading pipeline** that processes JSON templates and mod patches at startup.
- A set of **core runtime systems** (stats, quests, tasks, factions, etc.) driven entirely by that data.
- A **UI framework** composed of reusable screen components wired to backend classes.
- A **centralized Godot Theme** that can be reskinned at runtime via `config.json`.
- A **mod loader** that handles discovery, dependency resolution, and two-phase patching.

### Current Implementation Snapshot

As of this revision, the repository already contains the autoload, core, loader, stat, task, quest, and AI provider scaffolding, but the full target folder tree in this document is not implemented end-to-end yet. In particular, UI scenes, content mods, test coverage, schema tooling, and debug tooling are documented here as required architecture rather than fully landed code.

Use this document as the "where we are going and what rules we must preserve" reference, not as a claim that every folder and subsystem below is feature-complete today.

### Architecture Guardrails

The key theme for this project is clear: the engine is already flexible, so the next phase is about making that flexibility hard to misuse.

These rules now belong to the canonical architecture:

- **Schema validation is mandatory** for every template file. Loaders should reject bad field names, bad types, missing required keys, unknown enums, and invalid references before data reaches runtime systems.
- **Contracts beat conventions.** Every backend class, action payload, and cross-system data object should define the fields it requires instead of relying on informal expectations.
- **Template data is immutable at runtime.** JSON definitions are static truth; mutation belongs on runtime instances only.
- **Queries must scale beyond direct ID lookups.** `get_part(id)` and friends stay useful, but the engine also needs higher-level query helpers for tags, filters, and UI feeds.
- **Debuggability is a feature.** Event inspection, loaded-mod summaries, patch results, and live runtime state should be observable without hand-instrumenting the game.
- **Versioning is explicit.** Template schemas and save schemas need version markers plus migration points so the mod ecosystem can evolve without permanent breakage.

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
│   │   ├── omni_theme.tres  # ✅ Centralized Godot Theme resource (the UI source of truth)
│   │   └── theme_applier.gd # ✅ Reads config.json ui.theme overrides and patches the theme at runtime
│   ├── screens/             # Full-screen views (managed by UIRouter)
│   │   ├── world_map/           # ⚠️ PLANNED
│   │   │   ├── world_map_screen.tscn
│   │   │   └── world_map_screen.gd
│   │   ├── location_view/       # ✅ Hub screen — shows location name, description, and interactive screens as buttons
│   │   │   ├── location_view_screen.tscn
│   │   │   └── location_view_screen.gd
│   │   └── backends/        # One scene per backend_class type
│   │       ├── assembly_editor_screen.tscn   # ✅ AssemblyEditorBackend — implemented
│   │       ├── assembly_editor_screen.gd
│   │       ├── exchange_screen.tscn          # ⚠️ PLANNED — ExchangeBackend
│   │       ├── list_screen.tscn              # ⚠️ PLANNED — ListBackend
│   │       ├── challenge_screen.tscn         # ⚠️ PLANNED — ChallengeBackend
│   │       ├── task_provider_screen.tscn     # ⚠️ PLANNED — TaskProviderBackend
│   │       ├── catalog_list_screen.tscn      # ⚠️ PLANNED — CatalogListBackend
│   │       └── dialogue_screen.tscn          # ⚠️ PLANNED — DialogueBackend (wraps Dialogue Manager)
│   ├── components/          # Reusable UI widgets (used inside screens)
│   │   ├── currency_summary_panel.tscn  # ✅ Budget display used by AssemblyEditor
│   │   ├── part_detail_panel.tscn       # ✅ Part preview sidebar used by AssemblyEditor
│   │   ├── stat_delta_sheet.tscn        # ✅ Before/after stat diff used by AssemblyEditor
│   │   ├── part_card.tscn               # ⚠️ PLANNED — part display: icon, name, stats, price
│   │   ├── entity_portrait.tscn         # ⚠️ PLANNED — entity avatar, name, description
│   │   ├── currency_display.tscn        # ⚠️ PLANNED — currency value + symbol/icon
│   │   ├── stat_bar.tscn                # ⚠️ PLANNED — labeled progress bar
│   │   ├── stat_sheet.tscn              # ⚠️ PLANNED — full stat list for an entity
│   │   ├── tab_panel.tscn               # ⚠️ PLANNED — tabbed container (used by location_view)
│   │   └── notification_popup.tscn      # ⚠️ PLANNED — achievement / quest update popups
│   └── debug/               # Dev-only debug tooling (excluded from export)
│       └── dev_debug_overlay.gd         # ✅ Runtime overlay for registry/state inspection
│
├── core/                   # Base classes and shared utilities
│   ├── script_hook.gd      # Base class all mod script hooks extend
│   ├── part_instance.gd    # Runtime part instance (wraps template + instance data)
│   ├── entity_instance.gd  # Runtime entity instance (stats, inventory, sockets, equip/unequip)
│   ├── assembly_session.gd # Transactional draft wrapper used by AssemblyEditorBackend
│   └── constants.gd        # Engine-wide string constants, enums (OmniConstants)
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
    ├── imgui-godot/        # imgui-godot — runtime debug overlay and developer tooling ⚠️ DEV ONLY
    ├── limboai/            # LimboAI — HSM for quests, behavior trees for NPCs (limbonaut)
    ├── dialogue_manager/   # Dialogue Manager v3.x — branching NPC dialogue (nathanhoad)
    ├── nobodywho/          # NobodyWho — embedded local LLM inference (no server needed)
    └── ziva_agent/         # ⚠️ DEV ONLY — AI assistant integration, remove before release
```

---

## Autoloads

In the target runtime configuration, these autoloads are registered as global singletons in **Project Settings → Autoload**. They are intended to be accessible from anywhere without imports once the full boot pipeline is wired in.

### `GameEvents` (`autoloads/game_events.gd`)
The global signal bus. All cross-system communication goes here. No system should hold a direct reference to another — instead, emit and listen to signals on `GameEvents`.

Signal naming should stay specific and domain-oriented. Prefer names that encode the subject and action (`entity_currency_changed`, `quest_stage_advanced`, `ui_screen_opened`) over ambiguous catch-all signals. A larger signal surface is acceptable if it keeps tooling, filtering, and debugging clear.

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
func get_entity(id: String) -> Dictionary
func get_location(id: String) -> Dictionary
func get_faction(id: String) -> Dictionary
func get_quest(id: String) -> Dictionary
func get_task(id: String) -> Dictionary
func get_achievement(id: String) -> Dictionary
func get_definitions(category: String) -> Array      # e.g. get_definitions("stats")
func get_config_value(key_path: String, default: Variant = null) -> Variant  # e.g. get_config_value("game.ticks_per_day", 24)

# Query helpers
# PartsRegistry.get_by_category(tag: String) -> Array  — all parts with the given tag
```

Hardening rules for `DataManager`:

- Template dictionaries returned from `DataManager` are read-only by convention and should be treated as immutable snapshots.
- Every loader should validate additions and patches before mutating the merged registry.
- `DataManager` should eventually expose query helpers for common lookups (`query_parts`, `query_entities`, `query_locations`) so systems and UI do not re-implement filtering logic ad hoc.
- Unknown references should fail fast during loading rather than surfacing as null lookups later in gameplay.

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
func push(screen_id: String, params: Dictionary = {}) -> void
func pop() -> void
func replace_all(screen_id: String, params: Dictionary = {}) -> void
func current_screen_id() -> String
func is_registered(screen_id: String) -> bool
func register_screen(screen_id: String, scene_path: String) -> void
```

Registered screens (see `ui/main.gd`):

| screen_id | Scene | Status |
|---|---|---|
| `main_menu` | `main_menu_screen.tscn` | ✅ |
| `assembly_editor` | `assembly_editor_screen.tscn` | ✅ |
| `character_creator` | `assembly_editor_screen.tscn` (alias) | ✅ |
| `gameplay_shell` | `gameplay_shell_screen.tscn` | ✅ |
| `location_view` | `location_view_screen.tscn` | ✅ |
| `exchange` | `exchange_screen.tscn` | ⚠️ PLANNED |
| `list_view` | `list_screen.tscn` | ⚠️ PLANNED |
| `challenge` | `challenge_screen.tscn` | ⚠️ PLANNED |
| `task_provider` | `task_provider_screen.tscn` | ⚠️ PLANNED |
| `catalog_list` | `catalog_list_screen.tscn` | ⚠️ PLANNED |
| `dialogue` | `dialogue_screen.tscn` | ⚠️ PLANNED |

`UIRouter` is also the boundary where the UI should evolve from simple screen navigation into a state router:

- Navigation always carries explicit context (`screen_id` + params), never hidden global assumptions.
- Backends build view models from params and runtime state.
- Screens render those view models without reaching back into unrelated systems.
- Future dynamic layouts should still pass through the router so mod-defined UI stays inspectable and debuggable.

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

AI output is treated as untrusted input. The target architecture assumes:

- Prompt templates are owned by the calling system, not duplicated ad hoc in random hooks.
- Structured output should be schema-checked before it mutates gameplay state.
- Every AI-assisted flow has a deterministic fallback when the provider is unavailable or returns malformed output.
- Mods should never require online AI to keep core progression functional.

---

## Core Systems

These are not autoloads — they are classes instantiated and owned by the autoloads above.

| Class | Owner | Purpose |
|---|---|---|
| `DefinitionLoader` | DataManager | Parses `definitions.json`, validates stat pairs |
| `PartsRegistry` | DataManager | Part template storage and patch application |
| `EntityRegistry` | DataManager | Entity template storage and patch application |
| `LocationGraph` | DataManager | Location template storage; `get_location(id)`, `get_connections(id)`, `get_all_locations()` |
| `FactionRegistry` | DataManager | Faction data + reputation threshold queries |
| `QuestRegistry` | DataManager | Quest template storage |
| `TaskRegistry` | DataManager | Task template storage |
| `AchievementRegistry` | DataManager | Achievement template storage |
| `ConfigLoader` | DataManager | Deep-merges `config.json` across all mods |
| `AssemblySession` | `AssemblyEditorBackend` | Transactional draft wrapper for assembly edits — clones the target entity, tracks build cost against a budget, computes projected stats, and commits on confirm. Supports a separate payer entity when the budget source differs from the target. |
| `StatManager` | Systems utility | Stat calculation, modifier stacking, clamping |
| `ConditionEvaluator` | Systems utility | Evaluates JSON `conditions` blocks (AND/OR trees) |
| `ActionDispatcher` | Systems utility | Executes `action_payload` objects, emits events |
| `QuestTracker` | GameState | Quest HSM built on LimboAI — reads `quests.json`, creates `LimboHSM` nodes dynamically; JSON schema is unchanged |
| `TaskRunner` | TimeKeeper | Advances active tasks on each tick |
| `ScriptHookLoader` | ModLoader | Loads, validates, and caches GDScript mod hooks |

### Planned Hardening Systems

The following support systems are important enough to be part of the documented architecture, even if they are still being implemented:

- **SchemaValidator**: lightweight per-file schema checks for required fields, primitive types, enums, and reference validity.
- **BackendContractRegistry**: maps `backend_class` values to required JSON fields and validates screens/interactions before UI construction.
- **QueryService**: shared filtered lookup helpers used by UI, tasks, generators, and AI-safe content discovery.
- **DebugOverlay / DebugPanel**: live inspection for loaded mods, emitted events, active quests/tasks, view models, and patch results.

### Debug And Test Tooling

Development-time tooling is part of the architecture, not an afterthought.

- **`imgui-godot` is the preferred runtime debug layer** for inspecting mods, registries, GameState, event flow, backend params, and save/migration behavior.
- **GUT is the preferred automated test layer** for unit, integration, and content invariant tests.
- Debug and testing tools are dev-only and must not become required for normal gameplay.
- New systems should ideally arrive with both:
  - at least one useful debug inspection surface
  - at least one automated test surface

See `docs/DEBUGGING_AND_TESTING_GUIDELINES.md` for the working rules.

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

Target UI data flow:

```text
JSON definition -> Backend -> ViewModel -> Screen -> Components -> Theme
```

That flow is the missing scalability layer between "backend-driven screens" and a truly moddable UI system. The rules are:

- **Backends own logic and data gathering.**
- **View models are pure dictionaries/resources prepared for rendering.**
- **Screens are shells that render a view model and host reusable widgets.**
- **Components are dumb widgets.** They should not query `DataManager`, `GameState`, or unrelated autoloads on their own.
- **Themes style semantics, not business logic.**
- The shared `ui/theme/omni_theme.tres` resource is applied to routed screens after mod config loads, so `ui.theme` overrides propagate across menu and backend screens without per-scene palette edits.

### Navigation Flow

Menu system requirements:

- Boot should land in a routed `main_menu` screen after mods and config finish loading.
- `main_menu` is a normal `UIRouter` destination, not a separate boot scene.
- A pre-world creator flow is a valid routed step between `New Game` and the first gameplay screen.
- That flow should be a configured `AssemblyEditorBackend`/assembly editor screen, not a one-off scene contract.
- If a `character_creator` route id exists, treat it as a convenience alias for a configured assembly editor, not a unique UI species.
- The creator should render the currently reachable assembly sockets from the player entity and equipped parts, not assume a fixed humanoid slot list.
- Starting a new game should initialize runtime state first, then replace the current stack with the first gameplay screen.
- Loading a save should complete `SaveManager.load_game(slot)` first, then replace the current stack with gameplay.
- A lightweight `gameplay_shell` screen is an acceptable early routed gameplay destination while world-map and location flows are still being built.
- Main menu presentation can be influenced by `config.json ui.main_menu`, but actions like `new_game`, `continue`, `load_slot`, and `quit` remain engine-owned commands.

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
| `AssemblyEditorBackend` | `assembly_editor_screen.tscn` ✅ | Attach/detach parts into sockets. Supports catalog mode (infinite stock from `PartsRegistry`) and inventory mode (`option_source_entity_id` draws from a live entity's inventory and depletes it on confirm). Supports entity-to-entity transactions via `budget_entity_id` (who pays) and `payment_recipient_id` (who earns). |
| `ExchangeBackend` | `exchange_screen.tscn` ⚠️ planned | Buy/sell part instances from entity inventory |
| `ListBackend` | `list_screen.tscn` ⚠️ planned | Display filtered data lists |
| `ChallengeBackend` | `challenge_screen.tscn` ⚠️ planned | Stat-check pass/fail |
| `TaskProviderBackend` | `task_provider_screen.tscn` ⚠️ planned | Faction job board |
| `CatalogListBackend` | `catalog_list_screen.tscn` ⚠️ planned | Infinite template vendor |
| `DialogueBackend` | `dialogue_screen.tscn` ⚠️ planned | Branching NPC dialogue via Dialogue Manager |
