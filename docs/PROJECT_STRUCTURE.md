# Omni-Framework — Project Structure

This document is the canonical reference for the engine's folder layout, autoloads, core systems, UI framework, and theme architecture. It is a living outline: some sections describe the target architecture that the current repository is growing toward, and those future-facing constraints are documented here intentionally so implementation hardens in the right direction.

---

## What We Are Building

**Omni-Framework** is a single-player game engine built on Godot 4. The goal is a fully modular, JSON-driven platform where the *engine provides systems* and *data provides content*. No game genre is baked in. The same engine can run a sci-fi colony sim, a cyberpunk trading game, or a fantasy RPG without code changes.

The engine ships with:
- A **data loading pipeline** that processes JSON templates and mod patches at startup.
- A set of **core runtime systems** (stats, quests, tasks, factions, etc.) driven entirely by that data.
- A **UI framework** composed of engine-owned routed screens plus reusable backend-driven screens wired to backend classes.
- A **centralized Godot Theme** that can be reskinned at runtime via `config.json`.
- A **mod loader** that handles discovery, dependency resolution, and two-phase patching.

### Current Implementation Snapshot

As of this revision, the repository already contains the autoload, core, loader, stat, task, quest, and AI provider scaffolding, plus the Phase 1-4 UI foundation: engine-owned routed screens, the shared component library, `BackendContractRegistry`, the backend/screen split for `AssemblyEditorBackend`, and the first round of moddable backend screens (`DialogueBackend`, `ExchangeBackend`, `CatalogListBackend`, `ListBackend`, `ChallengeBackend`, `TaskProviderBackend`). The full target tree is still not implemented end-to-end, though, and later read-only backends plus world-map/crafting support remain future-facing in this document.

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

Phase 4 note: the first round of moddable backend scenes now exists under `ui/screens/backends/` for exchange, catalog vending, generic list rendering, challenge checks, faction task boards, and dialogue. Some comments in the legacy tree diagram still say "planned", but the routed scene files, backend scripts, and route registrations are now present in the repository.

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
│   │   ├── main_menu/           # ✅ Engine-owned boot/menu route
│   │   │   ├── main_menu_screen.tscn
│   │   │   └── main_menu_screen.gd
│   │   ├── gameplay_shell/      # ✅ Engine-owned in-game shell / HUD route built from shared summary/loadout components
│   │   │   ├── gameplay_shell_screen.tscn
│   │   │   └── gameplay_shell_screen.gd
│   │   ├── settings/            # ✅ Engine-owned settings route with persisted app settings
│   │   ├── save_slot_list/      # ✅ Engine-owned autosave + manual save/load/delete browser
│   │   ├── pause_menu/          # ✅ Engine-owned pause route layered through the router stack
│   │   ├── credits/             # ✅ Engine-owned attribution and loaded-mod route
│   │   ├── world_map/           # ⚠️ PLANNED
│   │   │   ├── world_map_screen.tscn
│   │   │   └── world_map_screen.gd
│   │   ├── location_view/       # ✅ Engine-owned hub screen — shows location name, description, and interactive screens as buttons
│   │   │   ├── location_view_screen.tscn
│   │   │   └── location_view_screen.gd
│   │   └── backends/        # One scene per backend_class type
│   │       ├── assembly_editor_screen.tscn   # ✅ AssemblyEditorBackend — implemented
│   │       ├── assembly_editor_screen.gd
│   │       ├── exchange_screen.tscn          # ✅ ExchangeBackend — implemented
│   │       ├── list_screen.tscn              # ✅ ListBackend — implemented
│   │       ├── challenge_screen.tscn         # ✅ ChallengeBackend — implemented
│   │       ├── task_provider_screen.tscn     # ✅ TaskProviderBackend — implemented
│   │       ├── catalog_list_screen.tscn      # ✅ CatalogListBackend — implemented
│   │       ├── dialogue_screen.tscn          # ✅ DialogueBackend — implemented (wraps Dialogue Manager)
│   │       ├── backend_base.gd               # ✅ Base class for all backend implementations
│   │       ├── phase4_backend_helpers.gd     # ✅ Shared utilities used by Phase 4 backend screens
│   │       └── [backend_*.gd files]          # Backend implementation classes (one per backend_class type)
│   ├── components/          # Reusable UI widgets (used inside screens)
│   │   ├── currency_summary_panel.tscn  # ✅ Budget display used by AssemblyEditor
│   │   ├── part_detail_panel.tscn       # ✅ Part preview sidebar used by AssemblyEditor
│   │   ├── stat_delta_sheet.tscn        # ✅ Before/after stat diff used by AssemblyEditor
│   │   ├── assembly_slot_row.tscn       # ✅ Reusable AssemblyEditor slot selector row
│   │   ├── part_card.tscn               # ✅ Generic part display card for shops, crafting, and inventory lists
│   │   ├── entity_portrait.tscn         # ✅ Generic entity card used by gameplay_shell and future dialogue/task surfaces
│   │   ├── currency_display.tscn        # ✅ Generic currency value + symbol/icon panel
│   │   ├── stat_bar.tscn                # ✅ Generic labeled stat display with optional capacity bar
│   │   ├── stat_sheet.tscn              # ✅ Grouped stat renderer built from stat_bar instances
│   │   ├── tab_panel.tscn               # ✅ Generic tab host for multi-surface backend layouts
│   │   ├── notification_popup.tscn      # ✅ Global toast popup mounted under ScreenLayer
│   │   ├── recipe_card.tscn             # ✅ Crafting recipe summary card with requirement/status rendering
│   │   ├── quest_card.tscn              # ✅ Quest summary card with objective checklist rendering
│   │   └── faction_badge.tscn           # ✅ Faction identity badge with reputation tier/value
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

Implementation hardening notes:

- `GameEvents` should own the canonical signal catalog metadata used by tests and debug tools.
- `GameEvents` should retain a bounded event history so runtime inspection does not depend on ad hoc per-screen listeners.
- Legacy compatibility signals may exist temporarily, but they should be explicitly marked deprecated in the catalog rather than silently lingering.

Key signals (non-exhaustive):
```gdscript
signal tick_advanced(tick: int)
signal day_advanced(day: int)
signal location_changed(old_id: String, new_id: String)
signal part_equipped(entity_id: String, part_id: String, slot: String)
signal part_unequipped(entity_id: String, part_id: String, slot: String)
signal quest_stage_advanced(quest_id: String, stage_index: int)
signal quest_completed(quest_id: String)
signal task_started(task_id: String, entity_id: String)
signal task_completed(task_id: String, entity_id: String)
signal achievement_unlocked(achievement_id: String)
signal entity_currency_changed(entity_id: String, currency_id: String, old_amount: float, new_amount: float)
signal flag_changed(entity_id: String, flag_id: String, value: Variant)
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
- Enforce base-mod invariants (`id: "base"`, `load_order: 0`, not disabled, no dependencies).
- Topological sort by `load_order` and dependency graph.
- Phase 1: Pass all `data/*.json` addition files to `DataManager`.
- Phase 2: Pass all `patches` blocks to `DataManager` for merging.
- Emit `mod_load_error` on `GameEvents` for any failures (non-fatal).
- Emit `mod_loaded` only after both phases and script-hook preloading complete, then emit `all_mods_loaded`.
- Expose `get_debug_snapshot()` so debug tooling can inspect load status, timings, discovered-vs-loaded counts, and fatal/non-fatal error totals.

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

- Template dictionaries returned from `DataManager` should be treated as immutable snapshots. The current implementation returns defensive copies for direct getters and filtered query helpers.
- Every loader should validate additions and patches before mutating the merged registry.
- `DataManager` should expose query helpers for common lookups (`query_parts`, `query_entities`, `query_locations`) so systems and UI do not re-implement filtering logic ad hoc.
- Unknown references should fail fast during loading rather than surfacing as null lookups later in gameplay.
- `DataManager` should retain a debug snapshot of processed files, registry counts, and load issues so the dev overlay and tests can inspect data health without re-parsing mod files.

### `GameState` (`autoloads/game_state.gd`)
Holds the active runtime state of the game session. This is what gets serialized to a save file by `SaveManager` via `A2J.to_json()`.

Contains:
- `player: EntityInstance` — the active player entity (with live stats, inventory, flags).
- `entity_instances: Dictionary` — all live NPC/entity instances keyed by entity_id.
- `current_location_id: String` — where the player currently is.
- `tick: int` — current game tick counter.
- `day: int` — current in-game day.
- `active_quests: Dictionary` — quest_id → lightweight quest instance data (current stage, timestamps, transient quest state).
- `active_tasks: Dictionary` — runtime_id → in-progress task instance data.
- `completed_task_templates: Array[String]` — non-repeatable task templates already completed in this save.
- `achievement_stats: Dictionary` — global tracking stats (gold_spent, etc.).

### `SaveManager` (`autoloads/save_manager.gd`)
Reads and writes `GameState` as human-readable JSON to `user://saves/` by default. Uses `A2J` for lossless typed serialization of all runtime objects. Handles schema versioning so old saves can be migrated forward, validates runtime state before save, and revalidates runtime references after load. Failed loads must restore the previous live runtime state instead of leaving `GameState` partially mutated or reset. Debug/test code can temporarily redirect saves under `user://test_saves/`, but production and release flows should continue to use the default save directory.

All custom runtime classes that appear in save data (`EntityInstance`, `PartInstance`, `GameState`, etc.) must be registered in `A2J.object_registry` during `_ready()` before any save/load can occur.

Key methods:
```gdscript
func save_game(slot: int) -> void
func load_game(slot: int) -> bool
func get_slot_info(slot: int) -> Dictionary
func slot_exists(slot: int) -> bool
func get_slot_path(slot: int) -> String
func set_save_directory_for_testing(path: String) -> bool
func reset_save_directory_for_testing() -> void
func get_debug_snapshot() -> Dictionary
func _register_runtime_classes() -> void
```

Usage pattern:
```gdscript
# Saving
var raw: Dictionary = A2J.to_json(GameState, _save_ruleset)
FileAccess.open(SaveManager.get_slot_path(slot), FileAccess.WRITE).store_string(
    JSON.stringify(raw, "\t")
)

# Loading
var raw: Dictionary = JSON.parse_string(
    FileAccess.get_file_as_string(SaveManager.get_slot_path(slot))
)
A2J.from_json(raw, _save_ruleset)  # Populates GameState in place
```

### `TimeKeeper` (`autoloads/time_keeper.gd`)
The tick clock. Exposes methods for advancing time (manually or via UI buttons). Dispatches `tick_advanced` and `day_advanced` signals on `GameEvents`. Drives `TaskRunner` to advance in-progress tasks, falls back to a safe default when `game.ticks_per_day` is invalid, and resynchronizes its derived tick-within-day counter from `GameState` after load/reset. `current_tick` is treated as the authoritative time source during resync; `current_day` is normalized from that tick value so corrupted or stale save state does not keep drifting at runtime.

Key methods:
```gdscript
func advance_ticks(amount: int) -> void
func advance_to_next_day() -> void
func get_current_tick() -> int
func get_current_day() -> int
func get_time_string() -> String  # e.g., "Day 3, 14:00"
func get_debug_snapshot() -> Dictionary
```

### `AudioManager` (`autoloads/audio_manager.gd`)
Wraps Godot `AudioStreamPlayer` pools for SFX and a dedicated player for music. Reads default sound paths from `config.json ui.sounds`. One-shot SFX calls from anywhere in the engine go here.

Implementation hardening notes:

- Missing custom audio buses should degrade cleanly to `Master` with a visible warning rather than silently assuming `Music` / `SFX` exist in the bus layout.
- Music transitions must be interruption-safe. Starting a new crossfade while another is in flight must not let the older tween stop the newest track.
- Per-call SFX gain offsets should survive master/SFX volume changes during playback.
- The autoload should expose `get_debug_snapshot()` so the debug overlay and tests can inspect resolved buses, cached UI sounds, active transitions, and recent audio errors.

Key methods:
```gdscript
func play_sfx(path: String) -> void
func play_music(path: String, crossfade: bool = true) -> void
func stop_music() -> void
func play_ui_sound(sound_key: String) -> void
func reload_ui_sound_config() -> void
func get_debug_snapshot() -> Dictionary
```

### `UIRouter` (`autoloads/ui_router.gd`)

See [`UI_IMPLEMENTATION_PLAN.md`](UI_IMPLEMENTATION_PLAN.md) for the backend catalog and full UI surface rollout plan.

Manages the screen navigation stack. Screens push and pop; the router handles transitions and keeps history for back-navigation. All screen changes go through here — no scene switches happen directly.

Key methods:
```gdscript
func push(screen_id: String, params: Dictionary = {}) -> void
func pop() -> void
func replace_all(screen_id: String, params: Dictionary = {}) -> void
func current_screen_id() -> String
func current_screen_params() -> Dictionary
func is_registered(screen_id: String) -> bool
func register_screen(screen_id: String, scene_path: String) -> void
func get_debug_snapshot() -> Dictionary
```

Implementation hardening notes:

- `replace_all()` should instantiate the target route before tearing down the current stack so a bad route cannot blank the UI.
- Pushed screens should hide the previous top-of-stack screen and reveal it again on `pop()` so back-navigation is deterministic.
- Replacing a stack should emit the same pop events a manual unwind would emit, so debug tools and listeners do not miss route removals.
- The router should expose a structured debug snapshot containing registered routes, stack entries, current params, container health, and recent navigation errors.

Every routed screen should fall into exactly one of two categories:

- **Engine-owned screens**: fixed application routes registered directly by the engine. Mods may influence theme, strings, and the data rendered inside them, but they do not replace these route contracts through JSON.
- **Backend-driven screens**: routed views selected from mod data via `backend_class`. These are the moddable interaction surfaces.

Registered screens (see `ui/main.gd`):

Engine-owned routed screens:

| screen_id | Scene | Status |
|---|---|---|
| `main_menu` | `main_menu_screen.tscn` | ✅ |
| `settings` | `settings_screen.tscn` | ✅ |
| `save_slot_list` | `save_slot_list_screen.tscn` | ✅ |
| `pause_menu` | `pause_menu_screen.tscn` | ✅ |
| `credits` | `credits_screen.tscn` | ✅ |
| `gameplay_shell` | `gameplay_shell_screen.tscn` | ✅ |
| `location_view` | `location_view_screen.tscn` | ✅ |
 
Backend-driven routed screens:

| screen_id | Scene | Status |
|---|---|---|
| `assembly_editor` | `assembly_editor_screen.tscn` | ✅ |
| `character_creator` | `assembly_editor_screen.tscn` (alias) | ✅ |
| `exchange` | `exchange_screen.tscn` | ⚠️ PLANNED |
| `list_view` | `list_screen.tscn` | ⚠️ PLANNED |
| `challenge` | `challenge_screen.tscn` | ⚠️ PLANNED |
| `task_provider` | `task_provider_screen.tscn` | ⚠️ PLANNED |
| `catalog_list` | `catalog_list_screen.tscn` | ⚠️ PLANNED |
| `dialogue` | `dialogue_screen.tscn` | ⚠️ PLANNED |
| `world_map` | `world_map_screen.tscn` | ⚠️ PLANNED |

`UIRouter` is also the boundary where the UI should evolve from simple screen navigation into a state router:

- Navigation always carries explicit context (`screen_id` + params), never hidden global assumptions.
- Backends build view models from params and runtime state.
- Screens render those view models without reaching back into unrelated systems.
- Future dynamic layouts should still pass through the router so mod-defined UI stays inspectable and debuggable.

### `AIManager` (`autoloads/ai_manager.gd`)
Abstracts all LLM calls behind a single interface. Reads the engine-owned AI section from `user://settings.cfg` at startup and instantiates the appropriate provider. Modders and script hooks call `AIManager` directly — they never reference a specific provider or initiate the connection themselves.

If AI is disabled in app settings, all calls silently no-op and return empty strings. This means games that don't use AI work without any configuration.

Supported providers (set via engine settings):

| Value | Backend | Notes |
|---|---|---|
| `"openai_compatible"` | `OpenAIProvider` | Covers Ollama, LM Studio, Jan, OpenAI, and any OpenAI-compatible endpoint |
| `"anthropic"` | `AnthropicProvider` | Anthropic Claude REST API |
| `"nobodywho"` | `NobodyWhoProvider` | Embedded local inference via NobodyWho GDExtension node — no server required |
| `"disabled"` | — | All calls no-op silently |

Key methods:
```gdscript
# Fire-and-forget with callback
func generate(prompt: String, context: Variant = [], callback: Callable = Callable()) -> String  # returns request_id

# Awaitable
func generate_async(prompt: String, context: Variant = []) -> String

# Streaming — emits ai_token_received on GameEvents per token, then ai_response_received when done
func generate_streaming(prompt: String, context: Variant = []) -> String  # returns request_id

func is_available() -> bool   # Returns false if disabled, misconfigured, or provider failed to init
func get_provider_name() -> String
func get_debug_snapshot() -> Dictionary
```

`context` accepts either the documented message-history `Array` form or a `Dictionary` with fields like `history` and `system_prompt`.

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

Implementation hardening notes:

- `AIManager` owns request ids and emits `ai_response_received`, `ai_token_received`, and `ai_error` on `GameEvents`.
- `is_available()` reflects provider readiness rather than only whether a provider node exists.
- `AIManager.get_debug_snapshot()` exposes current provider state plus recent request metadata for the debug overlay and tests.

AI output is treated as untrusted input. The target architecture assumes:

- Prompt templates are owned by the calling system, not duplicated ad hoc in random hooks.
- Structured output should be schema-checked before it mutates gameplay state.
- Every AI-assisted flow has a deterministic fallback when the provider is unavailable or returns malformed output.
- Mods should never require online AI to keep core progression functional.

---

## Core Systems

These are not autoloads — they are classes instantiated and owned by the autoloads above.

See [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) for implementation patterns that all these loaders should follow.

| Class | Owner | Purpose |
|---|---|---|
| `DefinitionLoader` | DataManager | Parses `definitions.json`, validates stat pairs |
| `PartsRegistry` | DataManager | Part template storage and patch application |
| `EntityRegistry` | DataManager | Entity template storage and patch appli