# Omni-Framework System Catalog

> **Quick Navigation:** This document is the complete catalog of all systems, subsystems, and their relationships in Omni-Framework. For details on any system, follow the linked documentation.

---

## Overview

Omni-Framework is a **data-driven, genre-agnostic game engine** built on Godot 4.6. All systems are composed of:

1. **Autoloads** — Global singletons managing boot sequence, state, persistence, UI, and events
2. **Runtime Helper Systems** — Stateless utilities instantiated by autoloads or called at runtime
3. **Data Loaders & Registries** — Parsing JSON templates and managing in-memory caches
4. **AI Providers** — Pluggable backends for LLM generation
5. **UI Framework** — Routed engine-owned screens + backend-driven modular screens

See [`AGENTS.md`](../AGENTS.md) for architecture rules and [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for the complete folder layout.

---

## Autoload Systems (Boot Phase Sequence)

These are **global singletons** initialized during engine boot in this order. All depend on `GameEvents` being available first.

| Autoload | Class | File | Boot Order | Purpose |
|---|---|---|---|---|
| `GameEvents` | `OmniGameEvents` | `autoloads/game_events.gd` | **1st** | Signal bus — ALL cross-system communication. See [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md) for all events. |
| `ModLoader` | `OmniModLoader` | `autoloads/mod_loader.gd` | **2nd** | Discovers, orders, and two-phase loads mods. Calls `register_backend_contracts()`. |
| `DataManager` | `OmniDataManager` | `autoloads/data_manager.gd` | **3rd** | Central template registry. Instantiates and populates all data loaders. |
| `GameState` | `OmniGameState` | `autoloads/game_state.gd` | **4th** | Runtime state container: active player, current location, tick clock reference. |
| `SaveManager` | `OmniSaveManager` | `autoloads/save_manager.gd` | **5th** | JSON save/load via A2J. Loads or boots new games to `user://saves/`. |
| `TimeKeeper` | `OmniTimeKeeper` | `autoloads/time_keeper.gd` | **6th** | Tick clock. Dispatches `tick_advanced` and `day_advanced` signals every frame. |
| `AudioManager` | `OmniAudioManager` | `autoloads/audio_manager.gd` | **7th** | SFX pools and music playback control. |
| `UIRouter` | `OmniUIRouter` | `autoloads/ui_router.gd` | **8th** | Screen navigation stack. Pushes initial screen (menu or gameplay). |
| `AIManager` | `OmniAIManager` | `autoloads/ai_manager.gd` | **9th** | AI provider abstraction. Routes to configured backend (OpenAI, Anthropic, NobodyWho, or disabled). |

**Availability timeline after boot:**
- Immediately after `DataManager`: `ActionDispatcher`, `ConditionEvaluator`, `StatManager`
- Immediately after `SaveManager`: `RewardService`, `TransactionService`, `ScriptHookService`
- After `ModLoader` completes: `BackendContractRegistry` is locked (no new contracts accepted)
- After `UIRouter` initializes: `AppSettings` (persistent UI preferences)

---

## Runtime Helper Systems

These **stateless utilities** are instantiated or called by autoloads, screens, and mod scripts. They are NOT autoloads.

### Core Runtime Services

| System | Class | File | Depends On | Purpose |
|---|---|---|---|---|
| `ActionDispatcher` | `ActionDispatcher` | `systems/action_dispatcher.gd` | DataManager | Executes JSON action blocks from quests/tasks: `give_currency`, `travel`, `spawn_entity`, `start_quest`, `learn_recipe`, `modify_reputation`, etc. See [`modding_guide.md`](modding_guide.md) for schema. |
| `ConditionEvaluator` | `ConditionEvaluator` | `systems/condition_evaluator.gd` | DataManager | Evaluates JSON condition blocks (AND/OR trees) used by quests, tasks, UI logic. See [`modding_guide.md`](modding_guide.md) for syntax. |
| `StatManager` | `StatManager` | `systems/stat_manager.gd` | DataManager | Calculates stat modifiers, applies stat changes, enforces clamping rules. See [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md). |
| `EncounterRuntime` | `EncounterRuntime` | `systems/encounter_runtime.gd` | ConditionEvaluator | Stateless encounter helper for weighted opponent action selection, encounter condition context, local-stat clamping, and JSON-native effect delta math. |
| `BackendContractRegistry` | `BackendContractRegistry` | `systems/backend_contract_registry.gd` | — | Validates `backend_class` IDs and their payload schemas. Locked after `ModLoader`. |
| `RewardService` | `RewardService` | `systems/reward_service.gd` | GameState, SaveManager | Distributes currency, items, unlocks when quests/tasks complete. |
| `TransactionService` | `TransactionService` | `systems/transaction_service.gd` | GameState, SaveManager | Handles buy/sell/exchange validation and currency movement. |
| `ScriptHookService` | `ScriptHookService` | `systems/script_hook_service.gd` | DataManager | Lifecycle manager for mod script hooks, including Phase 6 global world-generation hooks and cached task flavor text. |
| `AssemblyCommitService` | `AssemblyCommitService` | `systems/assembly_commit_service.gd` | GameState | Transactional part attachment/detachment for assembly editor. |

### AI & Quest Orchestration

| System | Class | File | Depends On | Purpose |
|---|---|---|---|---|
| `QuestTracker` | `QuestTracker` | `systems/quest_tracker.gd` | GameState, DataManager | Quest HSM built on LimboAI. Drives quest stages, objectives, and completion. |
| `TaskRunner` | `TaskRunner` | `systems/task_runner.gd` | GameState, DataManager | Tick-driven task execution and completion checking. |
| `TaskRoutineRunner` | `OmniTaskRoutineRunner` | `systems/task_routine_runner.gd` | GameState, DataManager, TaskRunner | Starts task templates from daily time windows for scheduled NPC/entity movement. Autoload singleton. |
| `LocationAccessService` | `LocationAccessService` | `systems/location_access_service.gd` | DataManager, ConditionEvaluator | Shared travel/entry gate checks using `entry_condition` and `entry_conditions` on locations. |
| `ScriptHookLoader` | `ScriptHookLoader` | `systems/script_hook_loader.gd` | ModLoader | Loads and caches GDScript mod hooks for lifecycle callbacks. |

### UI & Persistence Utilities

| System | Class | File | Depends On | Purpose |
|---|---|---|---|---|
| `AppSettings` | `AppSettings` | `core/app_settings.gd` | — | Persistent app-level preferences (audio, graphics, and engine-owned AI connection/dialogue/world-generation settings such as `chat_history_window`, `streaming_speed`, and `enable_world_gen`). |
| `BackendHelpers` | `OmniBackendHelpers` | `ui/screens/backends/backend_helpers.gd` | GameState, DataManager | Phase-neutral utilities shared by backend screens. |

---

## Data Loaders & Registries

These systems parse JSON templates and populate in-memory registries. All are instantiated by `DataManager` at boot.

| Loader | Registry Class | File | Input JSON | ID Field | Purpose |
|---|---|---|---|---|---|
| `DefinitionLoader` | — | `systems/loaders/definition_loader.gd` | `definitions.json` | — (arrays) | Loads arrays of reusable field definitions (e.g., stat templates). |
| `PartsRegistry` | `PartsRegistry` | `systems/loaders/parts_registry.gd` | `parts.json` | `id` | All attachable parts (equipment, upgrades, chassis). |
| `EntityRegistry` | `EntityRegistry` | `systems/loaders/entity_registry.gd` | `entities.json` | `entity_id` | All NPCs, creatures, vendors, and the player entity template. |
| `LocationGraph` | `LocationGraph` | `systems/loaders/location_graph.gd` | `locations.json` | `location_id` | Map nodes and interconnections; drives world navigation. |
| `FactionRegistry` | `FactionRegistry` | `systems/loaders/faction_registry.gd` | `factions.json` | `faction_id` | Faction definitions, reputation tiers, task boards. |
| `QuestRegistry` | `QuestRegistry` | `systems/loaders/quest_registry.gd` | `quests.json` | `quest_id` | Quest templates with branching objectives and rewards. |
| `TaskRegistry` | `TaskRegistry` | `systems/loaders/task_registry.gd` | `tasks.json` | `template_id` | Repeatable tasks issued by factions; includes difficulty, reward, objectives. |
| `RecipeRegistry` | `RecipeRegistry` | `systems/loaders/recipe_registry.gd` | `recipes.json` | `recipe_id` | Crafting recipes that consume inventory parts and produce part templates. |
| `EncounterRegistry` | `EncounterRegistry` | `systems/loaders/encounter_registry.gd` | `encounters.json` | `encounter_id` | Turn-based encounter templates with participants, player/opponent actions, encounter-local stats, and resolution outcomes. |
| `AchievementRegistry` | `AchievementRegistry` | `systems/loaders/achievement_registry.gd` | `achievements.json` | `achievement_id` | Achievements with unlock conditions and rewards. |
| `ConfigLoader` | — | `systems/loaders/config_loader.gd` | `config.json` | — (deep-merged) | Engine-owned gameplay/UI defaults from mod data. AI provider ownership is intentionally excluded and lives in `AppSettings`. |
| `AIPersonaRegistry` | `AIPersonaRegistry` | `systems/loaders/ai_persona_registry.gd` | `ai_personas.json` | `persona_id` | Mod-authored AI personas used by dialogue and future AI consumers. |
| `AITemplateRegistry` | `AITemplateRegistry` | `systems/loaders/ai_template_registry.gd` | `ai_templates.json` | `template_id` | Mod-authored reusable AI prompt templates for world-generation hooks. |
All loaders support **two-phase patching**:
1. **Phase 1:** Additions — new entries added to the registry
2. **Phase 2:** Patches — existing entries are updated non-destructively

See [`modding_guide.md`](modding_guide.md) for patch syntax and [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) for validation rules.

All data IDs use **namespacing:** `author:mod:name`. Base game uses `base:` prefix.

---

## AI Systems

The `AIManager` autoload routes all AI calls to one of four backends based on the AI provider setting in `user://settings.cfg`. AI provider configuration is engine-owned and not moddable via `config.json` — see [`modding_guide.md`](modding_guide.md) §3.10 ("AI Connection Ownership"). All `generate_async` and streaming requests pass through the manager's global FIFO queue so concurrent AI consumers do not overlap provider calls. This keeps single-generation providers such as NobodyWho safe while preserving one public API for dialogue, behavior trees, world narration, lore, task flavor, and encounter logs.

### AI Providers

| Provider | Class | File | Mode | Best For |
|---|---|---|---|---|
| **OpenAI-Compatible** | `OpenAIProvider` | `systems/ai/providers/openai_provider.gd` | REST API | OpenAI, Ollama, LM Studio |
| **Anthropic** | `AnthropicProvider` | `systems/ai/providers/anthropic_provider.gd` | REST API | Claude (latest) |
| **NobodyWho** | `NobodyWhoProvider` | `systems/ai/providers/nobodywho_provider.gd` | Embedded | Local inference (no server) |
| **Disabled** | — | — | No-op | Testing, offline mode |

`NobodyWhoProvider` accepts local `.gguf` paths and NobodyWho-supported remote model references (`huggingface:`, `hf://`, `http://`, `https://`). Local paths are validated before reporting availability; remote references are passed to the GDExtension so NobodyWho can download and cache them. The provider creates `NobodyWhoModel` and `NobodyWhoChat` nodes in-process, listens to `response_updated` for streaming chunks, `response_finished` for completed responses, and `worker_failed` for load failures. `max_tokens` remains part of the shared AI settings contract, but the current NobodyWho GDExtension surface does not expose a direct max-token setter.

**Usage:** Mod scripts call `AIManager.generate_async(prompt, context)` and listen to AI events. Always guard with `AIManager.is_available()`. Consumers should not call provider nodes directly or add their own provider-concurrency locks; `AIManager` owns request serialization and lifecycle tracking.

`systems/ai/ai_chat_service.gd` now provides the first engine-owned AI consumer helper. It is a `RefCounted` prompt builder that resolves persona placeholders from `GameState` and `DataManager`, keeps a bounded role-tagged conversation history, assembles the `context` dictionary expected by `AIManager`, and validates or deflects responses before a UI screen consumes them.

`systems/ai/bt_action_ai_query.gd` and `systems/ai/bt_condition_ai_check.gd` now provide the engine-owned LimboAI behavior-tree bridge for Phase 5. `BTActionAIQuery` resolves `{blackboard_var}` tokens, submits an async AI request, supports `"text"`, `"enum"`, and `"json"` parsing, and writes either the parsed value or a fallback value into the blackboard. `BTConditionAICheck` appends a yes/no instruction, waits asynchronously, and returns `SUCCESS` / `FAILURE` from the normalized answer while falling back to a configurable default result when AI is unavailable, times out, or responds ambiguously. Both tasks share `systems/ai/bt_ai_utils.gd` for prompt expansion and parser logic.

See [`AGENTS.md`](../AGENTS.md) for architecture constraints and [`modding_guide.md`](modding_guide.md) for script hook examples.

### AI Events

Defined in `GameEvents` (see [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md)):
- `event_narrated(source_signal, source_key, narration)` — World-generation update emitted when narration or task flavor text is stored
- `ai_response_received(context_id, response)` — Full response ready
- `ai_token_received(context_id, token)` — Streaming token (where supported)
- `ai_error(context_id, error)` — Generation failed

---

## UI Framework & Backend System

All screens are managed by `UIRouter` (see [`UI_IMPLEMENTATION_PLAN.md`](UI_IMPLEMENTATION_PLAN.md)).

### Engine-Owned Screens (Routed)

These are **always available**, navigation-owned by the engine.

| Screen | Route ID | Scene | Purpose |
|---|---|---|---|
| Main Menu | `main_menu` | `ui/screens/main_menu/main_menu_screen.tscn` | Boot/menu entry point. |
| Gameplay Shell | `gameplay_shell` | `ui/screens/gameplay_shell/gameplay_shell_screen.tscn` | In-game HUD. Displays player summary, location, available screens. |
| World Map | `world_map` | `ui/screens/backends/world_map_screen.tscn` | Shell top-menu surface for zoomable, pannable location graph navigation and fast travel. |
| Pause Menu | `pause_menu` | `ui/screens/pause_menu/` | Layered pause overlay with continue/settings/quit. |
| Settings | `settings` | `ui/screens/settings/` | Audio, graphics, accessibility options, and engine-owned AI connect/disconnect controls. |
| Save/Load Browser | `save_slot_list` | `ui/screens/save_slot_list/` | Autosave + manual save/load/delete. |
| Credits & Loaded Mods | `credits` | `ui/screens/credits/` | Attribution and mod manifest. |

### Backend-Driven Screens (Modular)

These are **data-driven**. A JSON `backend_class` field in locations or NPCs routes to one of these implementations. Each has a **contract** schema validated by `BackendContractRegistry`.

| Backend Class | Scene | Validated By | Purpose | Modder Docs |
|---|---|---|---|---|
| `AssemblyEditorBackend` | `ui/screens/backends/assembly_editor_screen.tscn` | Part attachment, slot limits, stat budget | Attach/detach parts, preview stat changes, and edit selected equipped-part `custom_fields` in the draft session before confirm. | [`modding_guide.md`](modding_guide.md) |
| `ExchangeBackend` | `ui/screens/backends/exchange_screen.tscn` | Inventory lists, pricing, currency type | Buy/sell items from NPC vendor. | [`modding_guide.md`](modding_guide.md) |
| `ListBackend` | `ui/screens/backends/list_screen.tscn` | Array of displayable items | Render a data list (journal, bestiary, etc.). | [`modding_guide.md`](modding_guide.md) |
| `ChallengeBackend` | `ui/screens/backends/challenge_screen.tscn` | Stat check rules, pass/fail actions | Stat-check pass/fail outcome. | [`modding_guide.md`](modding_guide.md) |
| `TaskProviderBackend` | `ui/screens/backends/task_provider_screen.tscn` | Faction ID, contract list | Faction contract board that starts quest templates from `faction.quest_pool`, with optional cached AI flavor text and owned-entity auto-dispatch to the first reach-location objective. | [`modding_guide.md`](modding_guide.md) |
| `CatalogListBackend` | `ui/screens/backends/catalog_list_screen.tscn` | Template vendor mode, catalog filter | Infinite vendor: buy from any part template. | [`modding_guide.md`](modding_guide.md) |
| `CraftingBackend` | `ui/screens/backends/crafting_screen.tscn` | Station ID, recipe filters, crafter/input/output entities | Recipe crafting with input status and timed production support. | [`modding_guide.md`](modding_guide.md) |
| `DialogueBackend` | `ui/screens/backends/dialogue_screen.tscn` | Dialogue Manager `.dialogue` ref plus optional `ai_mode` | NPC branching dialogue with optional hybrid/freeform AI chat handoff driven by `AIChatService`. | [`modding_guide.md`](modding_guide.md) |
| `EncounterBackend` | `ui/screens/backends/encounter_screen.tscn` | Encounter ID, participant overrides, navigation overrides | Data-authored, turn-based encounters with player actions, weighted opponent actions, real stat mutation, encounter-local meters, outcome rewards/actions, and optional AI-flavored action log text. | [`modding_guide.md`](modding_guide.md) |
| `EntitySheetBackend` | `ui/screens/backends/entity_sheet_screen.tscn` | Optional entity target and display flags | Entity stats, currency balances, equipment, inventory actions, and faction standing. | [`modding_guide.md`](modding_guide.md) |
| `OwnedEntitiesBackend` | `ui/screens/backends/owned_entities_screen.tscn` | Optional owner entity and assignment defaults | Owned-entity management surface with validated ownership, inspect, equipment, location dispatch, recall, task-state refresh, completion notifications, and contract-assignment handoffs. | [`modding_guide.md`](modding_guide.md) |
| `ActiveQuestLogBackend` | `ui/screens/backends/active_quest_log_screen.tscn` | Optional completed quest display | Active quest cards with stages, objectives, and rewards. | [`modding_guide.md`](modding_guide.md) |
| `FactionReputationBackend` | `ui/screens/backends/faction_reputation_screen.tscn` | Optional entity target and known-only filter | Faction badges, descriptions, territory, and standing. | [`modding_guide.md`](modding_guide.md) |
| `AchievementListBackend` | `ui/screens/backends/achievement_list_screen.tscn` | Optional locked/unlocked filters | Achievement unlock state and stat progress, with hidden achievements suppressed until unlocked. | [`modding_guide.md`](modding_guide.md) |
| `EventLogBackend` | `ui/screens/backends/event_log_screen.tscn` | Optional event limit/domain/signal filters | Recent `GameEvents` history with optional narrated flavor lines. | [`modding_guide.md`](modding_guide.md) |
| `WorldMapBackend` | `ui/screens/backends/world_map_screen.tscn` | Optional title/description and display filters | Location graph with faction-tinted nodes, adaptive zoom decluttering, route lines, zoom/pan/orientation controls, and travel-on-click that consumes the cheapest routed total `travel_cost` in ticks. | [`modding_guide.md`](modding_guide.md) |

**How it works:**
1. Modders define a location/NPC with a `backend_class` and `backend_config` dict in JSON.
2. `BackendContractRegistry` validates that the backend exists and the config matches its contract.
3. At runtime, `UIRouter` instantiates the backend screen and passes the config.
4. The backend renders its UI and handles user interactions.

See [`UI_IMPLEMENTATION_PLAN.md`](UI_IMPLEMENTATION_PLAN.md) for detailed backend catalog and phased implementation roadmap.

### Shared UI Components

These are **reusable widgets** used inside screens. Located in `ui/components/`.

| Component | Scene | Used By | Purpose |
|---|---|---|---|
| `stat_bar` | `stat_bar.tscn` | Multiple | Labeled stat display with optional capacity bar. |
| `stat_sheet` | `stat_sheet.tscn` | Multiple | Grouped stat renderer (multiple stat_bar instances). |
| `currency_display` | `currency_display.tscn` | Assembly Editor, Exchange | Currency value + icon. |
| `currency_summary_panel` | `currency_summary_panel.tscn` | Assembly Editor | Player currency budget overview. |
| `part_card` | `part_card.tscn` | Exchange, Catalog, Inventory | Part display card with stats and price. |
| `part_detail_panel` | `part_detail_panel.tscn` | Assembly Editor | Part preview sidebar with stat deltas plus dynamic editors for the selected part's custom fields. |
| `stat_delta_sheet` | `stat_delta_sheet.tscn` | Assembly Editor | Before/after stat diff. |
| `assembly_slot_row` | `assembly_slot_row.tscn` | Assembly Editor | Reusable slot selector row. |
| `entity_portrait` | `entity_portrait.tscn` | Gameplay Shell, Dialogue, Tasks | Entity card (NPC or player). |
| `tab_panel` | `tab_panel.tscn` | Tabbed backends | Generic tab host for multi-surface layouts. |
| `notification_popup` | `notification_popup.tscn` | Global (ScreenLayer) | Toast popup for transient messages. |
| `recipe_card` | `recipe_card.tscn` | Crafting surfaces | Recipe summary with requirement/status. |
| `quest_card` | `quest_card.tscn` | Quest surfaces | Quest summary with objective checklist. |
| `faction_badge` | `faction_badge.tscn` | Task boards, dialogue | Faction identity with reputation tier. |

### UI Theme System

| Component | File | Purpose |
|---|---|---|
| `omni_theme.tres` | `ui/theme/omni_theme.tres` | Centralized Godot Theme resource (the single source of truth). |
| `theme_applier.gd` | `ui/theme/theme_applier.gd` | Reads `config.json ui.theme` overrides and patches the theme at runtime. |

---

## Core Runtime Data Classes

These are **runtime instances** that wrap template data or hold game state.

| Class | File | Purpose |
|---|---|---|
| `EntityInstance` | `core/entity_instance.gd` | Runtime entity (player or NPC). Holds stats, inventory, equipped parts, flags. |
| `PartInstance` | `core/part_instance.gd` | Runtime part instance. Wraps template + instance data (durability, modifiers, etc.). |
| `AssemblySession` | `core/assembly_session.gd` | Transactional draft for assembly editor. Allows "cancel" without committing changes. |
| `ScriptHook` | `core/script_hook.gd` | Base class for mod script hooks. Extends with lifecycle callbacks. |
| `OmniConstants` | `core/constants.gd` | Engine-wide string constants and enums. |

---

## Game Events (Signal Bus)

`GameEvents` is the **spine of cross-system communication**. All events are defined in `autoloads/game_events.gd` and organized by domain.

See [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md) for:
- Complete event catalog
- Naming patterns and domain groups
- When to add new events
- Payload design rules
- Stability guarantees

**Domains:**
- **Boot & Mod Loading:** `mod_loaded`, `all_mods_loaded`, `mod_load_error`, `data_validation_failed`
- **Time:** `tick_advanced`, `day_advanced`
- **Game State:** `game_started`, `location_changed`, `entity_stat_changed`, `flag_changed`
- **Inventory:** `part_acquired`, `part_removed`, `part_equipped`, `part_unequipped`
- **Economy:** `entity_currency_changed`, `transaction_completed`
- **Quests/Tasks:** `quest_started`, `quest_stage_advanced`, `quest_completed`, `task_started`, `task_completed`
- **Encounters:** `encounter_started`, `encounter_round_advanced`, `encounter_action_resolved`, `encounter_resolved`
- **Achievements:** `achievement_unlocked`
- **UI:** `ui_screen_pushed`, `ui_screen_popped`, `ui_notification_requested`
- **AI:** `ai_response_received`, `ai_token_received`, `ai_error`
- **Save/Load:** `save_started`, `save_completed`, `load_started`, `load_completed`, `save_failed`, `load_failed`

---

## Mod System

The **mod pipeline** is the engine's content backbone. See [`modding_guide.md`](modding_guide.md) for full modder reference.

### Mod Structure

```
mods/base/                  # Base game (load_order: 0, required)
  ├── mod.json              # Manifest
  ├── data/                 # JSON templates
  ├── dialogue/             # .dialogue files
  ├── scripts/              # GDScript hooks
  └── assets/               # Fonts, icons, SFX, music

mods/<author>/<mod>/        # User/community mods
  ├── mod.json              # Manifest with load_order, dependencies
  ├── data/                 # Additions and patches
  ├── dialogue/
  ├── scripts/
  └── assets/
```

### Two-Phase Loading

1. **Phase 1 (Additions):** Each mod's `data/` files are parsed and merged into registries.
2. **Phase 2 (Patches):** Mods apply targeted patches to existing entries (non-destructive updates).

Patches ensure Mod B can extend or fix Mod A's content without rewriting it.

### Backend Contract Registration

During mod load, each mod calls `register_backend_contracts()` to define custom backend schemas. Contracts are locked after `ModLoader` completes — no new backends can be registered at runtime.

---

## Persistence & Save System

`SaveManager` handles game state serialization using **Any-JSON** (`A2J`).

### Two JSON Layers

| Layer | Tool | Use Case | Files |
|---|---|---|---|
| **Template data** | Plain `JSON.parse_string()` | Human-authored mod files | `parts.json`, `entities.json`, etc. |
| **Save data** | `A2J.to_json()` / `A2J.from_json()` | Typed runtime state | `user://saves/*.json` |

Never use A2J for templates. Never use plain JSON for save data.

### Save Format & Versioning

- **Format:** Lossless, typed round-trip via A2J
- **Location:** `user://saves/` (platform-dependent)
- **Versioning:** Explicit version markers + migration points
- **Migration:** See [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md)

See [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md) for schema design, versioning strategy, and migration order.

---

## Validation & Linting

**Schema validation is mandatory.** All loaders reject invalid JSON before data reaches runtime.

See [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) for:
- Per-system schema expectations
- Required vs. optional fields
- Enum validation
- Reference integrity checks
- Patch validation rules
- Content lint severity guidance

---

## Dependencies & Addons

All third-party integrations are in `addons/`.

### Shipped Addons (Release)

| Addon | Path | Class | Purpose | Release |
|---|---|---|---|---|
| **Any-JSON** | `addons/A2J/` | `A2J` (autoload) | Lossless variant serialization for save files. | ✅ |
| **LimboAI** | `addons/limboai/` | GDExtension | Hierarchical State Machine for quests, behavior trees. | ✅ |
| **Dialogue Manager** | `addons/dialogue_manager/` | `DialogueManager` (autoload) | Branching NPC dialogue. | ✅ |
| **NobodyWho** | `addons/nobodywho/` | Optional GDExtension | Embedded local LLM inference. | Ship when native extension is enabled |

### Dev-Only Addons (Excluded from Release)

| Addon | Path | Purpose | Remove Before Release |
|---|---|---|---|
| **ImGui** | `addons/imgui-godot/` | In-game debug overlay and dev tooling. | ✅ Remove |
| **GUT** | `addons/gut/` | Unit testing framework. | ✅ Exclude from export |
| **Ziva Agent** | `addons/ziva_agent/` | AI dev assistant (internal only). | ✅ Remove entirely |

---

## Coding Standards & Implementation Patterns

See [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) for:
- GDScript typing rules (explicit types for Variant sources)
- Loader/autoload boundaries
- Anti-patterns to avoid
- Testing expectations

See [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) for:
- Using `imgui-godot` for runtime inspection
- GUT for automated coverage
- Content invariants and assertions

---

## Stat System

All stats follow strict pairing rules. See [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) for:

- **Stat Pairs:** `health` + `health_max`, `mana` + `mana_max`, etc.
- **Clamping:** Base stats always clamped to capacity when capacity changes.
- **Parts Modification:** Multiple parts stack additively.
- **Validation:** StatManager enforces invariants.

---

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| GDScript files | `snake_case.gd` | `stat_manager.gd` |
| Class names | `PascalCase` | `class_name StatManager` |
| Autoload names | `PascalCase` | `GameEvents` |
| Autoload classes | `Omni` + PascalCase | `class_name OmniUIRouter` |
| Signal names | `snake_case` | `tick_advanced` |
| Scene files | `snake_case.tscn` | `exchange_screen.tscn` |
| JSON IDs | `author:mod:name` | `base:iron_sword` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_SAVE_SLOTS` |

**Critical:** Autoload singleton names and `class_name` identifiers must not be identical in Godot (causes parser errors). Keep singleton names ergonomic and prefix scripts with `Omni`.

---

## Architecture Constraints

**All systems must obey:**

1. **Schema validation is mandatory** — Reject invalid JSON at load time.
2. **Contracts beat conventions** — Every backend, action, and cross-system object defines required fields.
3. **Template data is immutable** — Mutations only on runtime instances.
4. **Queries must scale** — ID lookups plus higher-level filters and feeds.
5. **Debuggability is a feature** — Events, mod summaries, patch results, runtime state all observable.
6. **Versioning is explicit** — Template and save schemas versioned; migration points defined.

See [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for full architectural guardrails.

---

## Quick Reference: Finding Systems

| Goal | Start Here |
|---|---|
| **Boot sequence and system dependencies** | `AGENTS.md` → [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) |
| **All autoloads and their roles** | This doc → [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) section "Autoload Systems" |
| **Every runtime helper system** | This doc → "Runtime Helper Systems" section |
| **Data registries and loaders** | This doc → "Data Loaders & Registries" section |
| **All UI screens and backends** | This doc → "UI Framework" section → [`UI_IMPLEMENTATION_PLAN.md`](UI_IMPLEMENTATION_PLAN.md) |
| **Game events and signals** | [`GAME_EVENTS_TAXONOMY.md`](GAME_EVENTS_TAXONOMY.md) → `autoloads/game_events.gd` |
| **Stat math and validation** | [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) |
| **Schema rules and lint** | [`SCHEMA_AND_LINT_SPEC.md`](SCHEMA_AND_LINT_SPEC.md) |
| **Save versioning and migration** | [`SAVE_SCHEMA_AND_MIGRATION.md`](SAVE_SCHEMA_AND_MIGRATION.md) |
| **Modding contracts and data** | [`modding_guide.md`](modding_guide.md) |
| **Coding style and loader patterns** | [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) |
| **Debug tooling and testing** | [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) |

---

## Document Relationships

```
SYSTEM_CATALOG.md (this file)
  ├─→ PROJECT_STRUCTURE.md        (Complete folder layout, system descriptions)
  ├─→ AGENTS.md                   (Boot sequence, architecture rules)
  ├─→ UI_IMPLEMENTATION_PLAN.md    (UI rollout, backend catalog, components)
  ├─→ TASK_ROUTINES.md             (Daily routine runner for scheduled entity movement)
  ├─→ LOCATION_ACCESS.md           (Location entry gating with conditions)
  ├─→ RUNTIME_ENTITY_PRESENCE.md   (How entities appear at locations)
  ├─→ GAME_EVENTS_TAXONOMY.md      (Event naming, domains, stability rules)
  ├─→ STAT_SYSTEM_IMPLEMENTATION.md (Stat math, clamping, validation)
  ├─→ modding_guide.md             (Data schemas, patching, script hooks)
  ├─→ SCHEMA_AND_LINT_SPEC.md      (Validation rules, lint severity)
  ├─→ SAVE_SCHEMA_AND_MIGRATION.md (Persistence, versioning, migration)
  ├─→ CODING_STANDARDS_AND_LOADER_PATTERNS.md (Implementation habits)
  └─→ DEBUGGING_AND_TESTING_GUIDELINES.md (Dev tooling, coverage)
```

---

## Version History

| Date | Author | Change |
|---|---|---|
| 2026-04-18 | System | Initial catalog creation — comprehensive system inventory with all links. |
