# Omni-Framework — Codex Context

## Rules
- Edit files in-place only. Never rewrite entire files.
- This is a Godot 4.6 GDScript project. No C#.
- All code follows the naming conventions below.
- Always check docs/ before making architectural decisions.
- Treat Godot warnings as errors when writing GDScript. Avoid relying on implicit typing when values come from `Dictionary.get()`, autoload properties typed as `Object`, JSON data, or other `Variant` sources.
- Keep our docs/ updated as edits happen

### GDScript Typing Rules
- Prefer explicit types for locals when a value may come from a `Variant`.
- After `Dictionary.get()`, store into `Variant` first if needed, type-check it, then cast/narrow to the expected type.
- When reading autoload fields like `GameState.player` that are stored as generic `Object`, cast them with `as` before calling methods on them.
- When pulling Controls or Arrays back out of untyped dictionaries, cast them explicitly instead of depending on inference.
- For helper methods that return structured collections from dynamic data, give the return type explicitly and normalize the contents before returning.

---

## What This Project Is

**Omni-Framework** is a single-player game engine built on Godot 4.6. It is a fully data-driven, genre-agnostic platform — the engine provides systems, JSON provides content. No hardcoded genres, stats, or currencies. The same engine runs a fantasy RPG, sci-fi sim, or cyberpunk trading game without code changes.

Core pillars:
- **Data-first:** JSON templates define content; GDScript instances are runtime objects.
- **Moddable by default:** Two-phase loading (additions then patches) ensures mods layer non-destructively.
- **Genre-agnostic:** All systems use abstract names (Parts, Entities, Locations) not genre-specific ones.

---

## Key Documentation

| File | Purpose |
|---|---|
| `docs/PROJECT_STRUCTURE.md` | Canonical folder layout, all autoloads, core systems, UI framework, theme system, AI architecture |
| `docs/MODDING_GUIDE.md` | Full modder reference — data schemas, JSON examples, patching, backend classes, script hooks |
| `docs/STAT_SYSTEM_IMPLEMENTATION.md` | Stat + capacity stat system, clamping rules, GDScript patterns |

**Always read the relevant doc section before editing architecture.**

---

## Folder Layout (abbreviated — see docs/PROJECT_STRUCTURE.md for full annotated tree)

```
res://
├── autoloads/       # Global singletons
├── systems/         # Core runtime systems + loaders + AI providers
│   ├── loaders/     # One file per data type (parts_registry.gd, etc.)
│   └── ai/          # LimboAI states/behaviors + AI provider scripts
├── ui/              # All scenes — main.tscn, theme/, screens/, components/
├── core/            # Base classes: ScriptHook, EntityInstance, PartInstance, AssemblySession, constants
├── mods/            # ALL content — base game and user mods
│   ├── base/        # The base game mod (load_order: 0, always required)
│   │   ├── mod.json
│   │   ├── data/    # Base game JSON (the "base:" namespace)
│   │   ├── dialogue/
│   │   ├── scripts/
│   │   └── assets/
│   └── <author>/<mod>/  # User/community mods
├── tests/           # GUT test suites (DEV ONLY)
└── addons/          # Third-party plugins (see below)
```

**There is no `data/` folder at the project root.** The engine is content-free — all game data, including the base game, flows through the mod pipeline. `ModLoader` treats a missing `mods/base/` as a fatal boot error.

---

## Autoloads (all global singletons)

| Name | File | Purpose |
|---|---|---|
| `GameEvents` | `autoloads/game_events.gd` | Global signal bus — ALL cross-system comms go here |
| `ModLoader` | `autoloads/mod_loader.gd` | Scans mods/, two-phase load pipeline |
| `DataManager` | `autoloads/data_manager.gd` | Central template registry after load |
| `GameState` | `autoloads/game_state.gd` | Active runtime state (player, location, tick) |
| `SaveManager` | `autoloads/save_manager.gd` | A2J-based JSON save/load to user://saves/ |
| `TimeKeeper` | `autoloads/time_keeper.gd` | Tick clock, dispatches tick/day signals |
| `AudioManager` | `autoloads/audio_manager.gd` | SFX pools + music playback |
| `UIRouter` | `autoloads/ui_router.gd` | Screen navigation stack |
| `AIManager` | `autoloads/ai_manager.gd` | LLM abstraction over local/remote providers |

**Boot sequence:**

1. `GameEvents` — Signal bus initialized first; all other systems depend on it.
2. `ModLoader` — Discovers and loads mods, applies patches, registers backend contracts via `BackendContractRegistry`.
3. `DataManager` — Populates registries (PartsRegistry, EntityRegistry, etc.) and calls loaders for all JSON data.
4. `GameState` — Initializes player, location, and active runtime state; calls `SaveManager` to load existing saves if present.
5. `SaveManager` — Registers A2J runtime classes, loads autosave or boots a new game.
6. `TimeKeeper` — Starts tick clock; dispatches tick signals every frame.
7. `AudioManager` — Initializes SFX pools and music channels.
8. `UIRouter` — Pushes initial screen (main menu or gameplay) onto the stack. Requires a `CanvasLayer` container — `UIRouter.initialize()` will error if passed anything other than a `CanvasLayer`.
9. `AIManager` — Initializes configured AI provider (OpenAI, Anthropic, NobodyWho, or disabled).

**Helper systems availability:**
- `ActionDispatcher`, `ConditionEvaluator`, `StatManager` — Stateless; available immediately after DataManager.
- `RewardService`, `TransactionService`, `ScriptHookService` — Available after SaveManager (depend on GameState).
- `BackendContractRegistry` — Locked after ModLoader phase completes; no new contracts can be registered after boot.
- `AppSettings` — Loaded and available after UIRouter initializes.

---

## Addons

| Addon | Path | Purpose | Release? |
|---|---|---|---|
| Any-JSON | `addons/A2J/` | Lossless variant serialization (`A2J` autoload) | ✅ Ship |
| LimboAI | `addons/limboai/` | GDExtension — HSM for quests, behavior trees | ✅ Ship |
| Dialogue Manager | `addons/dialogue_manager/` | Branching NPC dialogue (`DialogueManager` autoload) | ✅ Ship |
| NobodyWho | `addons/nobodywho/` | GDExtension — embedded local LLM inference | ✅ Ship |
| ImGui | `addons/imgui-godot/` | In-game debug overlay and dev tooling | ❌ DEV ONLY |
| GUT | `addons/gut/` | Unit testing | ❌ DEV ONLY |
| ziva_agent | `addons/ziva_agent/` | AI dev assistant | ❌ DEV ONLY — remove before release |

GDExtensions (LimboAI, NobodyWho) load automatically — no plugin.cfg needed.
Plugins requiring enable: A2J, dialogue_manager, gut — already set in project.godot `[editor_plugins]`.

---

## Two JSON Layers

| Layer | Tool | Notes |
|---|---|---|
| Template data (parts.json, entities.json, etc.) | `FileAccess` + `JSON.parse_string()` → `Dictionary` | Human-authored, plain JSON |
| Save data (GameState, EntityInstance, etc.) | `A2J.to_json()` / `A2J.from_json()` | Typed, lossless round-trip |

Never use A2J for template parsing. Never use plain JSON for save data.

**A2J registration:** Every runtime class that participates in save/load must be registered with A2J. Currently registered: `EntityInstance` and `PartInstance`. If you introduce a new first-class runtime class (e.g. `QuestInstance`, `TaskInstance`), add it to `SaveManager`'s A2J registration block and write a save/load round-trip test before shipping.

---

## Data Systems & JSON Schemas

Each system has a JSON file in `mods/base/data/` and a registry in `systems/loaders/`:

| System | Data File | Registry | Key ID Field |
|---|---|---|---|
| Definitions | `definitions.json` | `DefinitionLoader` | — (arrays only) |
| Parts | `parts.json` | `PartsRegistry` | `id` |
| Entities | `entities.json` | `EntityRegistry` | `entity_id` |
| Locations | `locations.json` | `LocationGraph` | `location_id` |
| Factions | `factions.json` | `FactionRegistry` | `faction_id` |
| Quests | `quests.json` | `QuestRegistry` | `quest_id` |
| Tasks | `tasks.json` | `TaskRegistry` | `template_id` |
| Achievements | `achievements.json` | `AchievementRegistry` | `achievement_id` |
| AI Personas | `ai_personas.json` | `AIPersonaRegistry` | `persona_id` |
| Config | `config.json` | `ConfigLoader` | — (deep-merged) |

All data IDs use `author:mod:name` namespacing. Base game uses `base:`.

---

## UI Backend Classes

Each `backend_class` value in JSON maps to a scene in `ui/screens/backends/`:

| `backend_class` | Scene | What it does |
|---|---|---|
| `AssemblyEditorBackend` | `assembly_editor_screen.tscn` | Attach/detach parts |
| `ExchangeBackend` | `exchange_screen.tscn` | Buy/sell from entity inventory |
| `ListBackend` | `list_screen.tscn` | Display data lists |
| `ChallengeBackend` | `challenge_screen.tscn` | Stat-check pass/fail |
| `TaskProviderBackend` | `task_provider_screen.tscn` | Faction job board |
| `CatalogListBackend` | `catalog_list_screen.tscn` | Infinite template vendor |
| `DialogueBackend` | `dialogue_screen.tscn` | NPC branching dialogue |
| `EntitySheetBackend` | `entity_sheet_screen.tscn` | Read-only entity stats/equipment/inventory |
| `ActiveQuestLogBackend` | `active_quest_log_screen.tscn` | Active quest cards with stages and objectives |
| `FactionReputationBackend` | `faction_reputation_screen.tscn` | Faction badges and standing |
| `AchievementListBackend` | `achievement_list_screen.tscn` | Achievement unlock state and progress |
| `EventLogBackend` | `event_log_screen.tscn` | Recent GameEvents history |

### Backend Contract System

Each backend class is validated against a **contract** — a schema that defines which fields and action types it supports. Contracts are registered during the mod load phase and locked before gameplay starts.

**How it works:**
1. When `ModLoader` boots, it calls `mod.register_backend_contracts()` for each loaded mod.
2. Each backend registers its contract with `BackendContractRegistry.register(backend_class, contract)`.
3. After all mods load, `BackendContractRegistry.lock()` is called — no new contracts can be registered.
4. At runtime, when a screen uses a `backend_class`, the registry validates that the backend exists and the payload matches the contract.

**Important:** Backend payloads are strict load-time contract data. Optional fields should be omitted unless needed, and all provided values must match expected runtime types exactly. Type mismatches are hard failures at load time, not runtime warnings.

**Modders extending backends:**
- Backends are defined in JSON with a `backend_class` string and a `backend_config` dict.
- The backend config must match the contract registered for that class.
- Custom backends can be registered in mod scripts — see `docs/MODDING_GUIDE.md` for schema examples.
- Official backends use `backend_helpers.gd` for phase-neutral common operations. Backend-specific helpers should stay scoped to their backend, such as `assembly_editor_config.gd` and `assembly_editor_option_provider.gd`.

---

## AI Architecture

`AIManager` reads `config.json ai.provider` and routes to one of three providers:
- `"openai_compatible"` → `systems/ai/providers/openai_provider.gd` (covers Ollama, LM Studio, OpenAI)
- `"anthropic"` → `systems/ai/providers/anthropic_provider.gd`
- `"nobodywho"` → `systems/ai/providers/nobodywho_provider.gd` (embedded, no server)
- `"disabled"` → all calls silently no-op

Modders call `AIManager.generate_async(prompt, context)` from script hooks. Always guard with `AIManager.is_available()`.

AI persona data lives in `ai_personas.json` and loads through `AIPersonaRegistry` into `DataManager.ai_personas`. Entities bind to personas via the optional `ai_persona_id` field. See `docs/AI_INTEGRATION_PLAN.md` for the phased consumer integration plan.

---

## Runtime Helper Systems

These systems provide core runtime functionality but are not autoloads. They're instantiated or called by autoloads and other systems:

| System | File | Purpose |
|---|---|---|
| `ActionDispatcher` | `systems/action_dispatcher.gd` | Executes JSON action blocks from quests/tasks (give_currency, travel, spawn_entity, start_quest, etc.) |
| `BackendContractRegistry` | `systems/backend_contract_registry.gd` | Central registry managing backend screen contracts; validates `backend_class` IDs and contract schemas |
| `AssemblyCommitService` | `systems/assembly_commit_service.gd` | Handles assembly editor part attachment/detachment logic and state commits |
| `RewardService` | `systems/reward_service.gd` | Processes quest/task completion rewards and distributes currency, items, and unlocks |
| `ScriptHookService` | `systems/script_hook_service.gd` | Manages lifecycle of mod script hooks and their execution callbacks |
| `TransactionService` | `systems/transaction_service.gd` | Handles currency exchanges and transaction validation (buy/sell, exchanges, trades) |
| `ConditionEvaluator` | `systems/condition_evaluator.gd` | Evaluates JSON condition blocks (AND/OR trees) used in quests, tasks, and UI logic |
| `StatManager` | `systems/stat_manager.gd` | Calculates stat modifiers, applies stat changes, and enforces clamping rules |

**Helper utilities:**
- `backend_helpers.gd` — Phase-neutral utility functions shared by backend screens (catalog, exchange, list, challenge, task provider, dialogue, and future reusable backend needs)
- `AppSettings` (`core/app_settings.gd`) — Persistent app-level settings (audio, graphics, accessibility)

---

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| GDScript files | `snake_case.gd` | `stat_manager.gd` |
| Class names | `PascalCase` | `class_name StatManager` |
| Autoload names | `PascalCase` | `GameEvents` |
| Autoload script class names | `Omni` + PascalCase | `class_name OmniUIRouter` |
| Signal names | `snake_case` | `tick_advanced` |
| Scene files | `snake_case.tscn` | `exchange_screen.tscn` |
| JSON IDs | `author:mod:name` | `base:iron_sword` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_SAVE_SLOTS` |

**Important:** autoload singleton names and `class_name` identifiers must not be identical in Godot. Keep the global singleton name ergonomic (`GameEvents`, `UIRouter`, etc.) and prefix the script class with `Omni` to avoid parser errors like `Class "UIRouter" hides an autoload singleton`.

---

## Stat System Rules

- Stats always come in pairs: `health` + `health_max`, `mana` + `mana_max`
- Base stats = current value. Capacity stats (`_max`) = ceiling.
- Always clamp base to capacity when capacity changes.
- Parts modify stats additively. Multiple parts stack.
- See `docs/STAT_SYSTEM_IMPLEMENTATION.md` for full patterns.

---

## Mod Structure

```
mods/base/                  # Base game — load_order: 0, fatal if missing
mods/<author_id>/<mod_id>/  # User/community mods
├── mod.json       # manifest: name, version, load_order, dependencies
├── data/          # JSON additions and patches
├── dialogue/      # .dialogue files (Dialogue Manager format)
├── scripts/       # GDScript hooks extending ScriptHook
└── assets/        # PNGs, WAV/OGG
```

Two-phase load: Phase 1 adds new content, Phase 2 applies patches. Patches run last so Mod B can patch Mod A's additions. Base mod always loads first.

**Base mod constraint:** `mods/base/mod.json` must NOT declare a `dependencies` array. The loader treats any dependencies on the base mod as a fatal validation error. All other mods may declare dependencies.

---

## Config Keys Reference

| Key | Type | Required | Notes |
|---|---|---|---|
| `game.starting_player_id` | string | **Required** | Must reference a valid entity id. No runtime fallback — missing or empty causes boot to abort. |
| `game.starting_location` | string | Optional | Must reference a valid location id when present. |
| `game.starting_discovered_locations` | array | Optional | Array of valid location ids. All entries are validated at load time. |
| `game.ticks_per_day` | int | Optional | Must be a positive integer. Default 24. |
| `game.ticks_per_hour` | int | Optional | Must be a positive integer. Used by `GameplayShellPresenter` to resolve "1 hour" time advance buttons. Default 0 (falls back to 1-tick increments for hour buttons). |
| `game.new_game_flow` | dict | Optional | Configures the initial screen/params pushed after a new game starts. |
| `ui.time_advance_buttons` | array | Optional | Labels ending in `tick(s)`, `hour(s)`, or `day(s)`. Example: `["1 hour", "1 day"]`. |

---

## Release Checklist (pre-ship)

- [ ] Remove `addons/ziva_agent/` entirely
- [ ] Exclude `addons/gut/` from export presets
- [ ] Exclude `tests/` from export presets
- [ ] Ensure no API keys are in any committed config files
- [ ] Verify `*.gguf` model files are not in repo (they're gitignored)
- [ ] Set `config/main_scene` in project.godot
- [ ] Register all runtime classes with `A2J.object_registry` in SaveManager
