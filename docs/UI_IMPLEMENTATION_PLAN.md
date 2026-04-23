# Omni-Framework — UI Implementation Plan & Recommendations

> **See also:** [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for the UI framework architecture, [`MODDING_GUIDE.md`](MODDING_GUIDE.md) for the data contracts that drive UI backends, and [`CODING_STANDARDS_AND_LOADER_PATTERNS.md`](CODING_STANDARDS_AND_LOADER_PATTERNS.md) for backend implementation patterns.

This document is a planning reference for the UI layer. It catalogs the backend screens, reusable components, engine-owned screens, new data schemas, and phased work required to bring the UI to parity with the data-first, genre-agnostic contract described in `PROJECT_STRUCTURE.md` and `MODDING_GUIDE.md`.

It is written to be revised. Treat it as the current best thinking, not a frozen spec.

UI implementation conventions currently live in this document and in `PROJECT_STRUCTURE.md`. If a dedicated design guide is added later, it should inherit these backend/screen/component contracts rather than replace them silently.

Decisions this document assumes:

- **Crafting is a first-class backend.** It gets its own `backend_class` (`CraftingBackend`), its own JSON data type (`recipes.json`), and its own registry (`RecipeRegistry`). It is not crammed into `AssemblyEditorBackend`.
- **Turn-based combat is deferred.** The architecture should not paint itself into a corner, but no combat backend ships in the initial UI rollout. The engine's current tick-and-location model is preserved.
- **Every UI screen either comes through the mod data pipeline (`backend_class`) or is an engine-owned fixed screen.** There is no third category.

---

## 1. Guiding Principles

The UI contract from `PROJECT_STRUCTURE.md §UI Framework` is the source of truth:

```
JSON definition → Backend → ViewModel → Screen → Components → Theme
```

What each layer is responsible for:

| Layer | Responsibility | What it must not do |
|---|---|---|
| **JSON definition** | Describe what the player sees and what `backend_class` handles it | Contain GDScript, reference runtime state |
| **Backend** | Validate params, query `DataManager` / `GameState`, produce a view model, commit side effects on confirm | Render UI, hold `@onready` refs |
| **ViewModel** | Pure `Dictionary` (or typed Resource) built once per refresh | Reference back into autoloads |
| **Screen** | Own a `.tscn`, receive the view model, distribute it to components | Query `DataManager` / `GameState` directly |
| **Component** | Accept a dictionary and render — dumb widget | Talk to autoloads, mutate runtime state |
| **Theme** | Style semantics via `omni_theme.tres` + `OmniSemantic` color tokens | Carry business logic |

Implications this document respects:

- Adding a new kind of screen means adding a new `backend_class`, a backend script, a screen script, and a scene — not a new global system.
- Adding a new data type (recipes, talents, etc.) means adding a loader under `systems/loaders/` and a matching `get_*` method on `DataManager`. The schema and patch shape follow the same two-phase pattern as parts/entities.
- Every `backend_class` the mod pipeline accepts has a registered contract (required fields, optional fields) that validation rejects at load time, not at first render.

---

## 2. Current State Summary

Recap of what exists today, so later sections can reference specific facts rather than re-deriving them.

### Implemented

- `UIRouter` (autoload) — screen stack, registration, theme propagation.
- `ui/main.tscn` / `ui/main.gd` — boots mods, applies theme, and registers the current runtime screen ids from `OmniUIRouteCatalog`.
- `omni_theme.tres` + `theme_applier.gd` — centralized theme with `OmniSemantic` color tokens driven by `config.json ui.theme`.
- Screens: `main_menu`, `settings`, `save_slot_list`, `pause_menu`, `credits`, `gameplay_shell`, `assembly_editor` (also aliased as `character_creator`). The earlier standalone `location_view` route is now represented by the gameplay shell's location surface.
- Components: `currency_summary_panel`, `part_detail_panel`, `stat_delta_sheet`, `assembly_slot_row`, `currency_display`, `stat_bar`, `stat_sheet`, `entity_portrait`, `part_card`, `tab_panel`, `notification_popup`, `recipe_card`, `quest_card`, `faction_badge`.
- `OmniBackendBase` (`ui/screens/backends/backend_base.gd`) as the shared backend surface for moddable UI backends.
- `OmniAssemblyEditorBackend` (`ui/screens/backends/assembly_editor_backend.gd`) as the extracted runtime/backend layer behind the assembly editor screen.
- `AssemblySession` in `core/` as the draft layer `AssemblyEditorBackend` operates on.
- `BackendContractRegistry` (`systems/backend_contract_registry.gd`) for load-time `backend_class` validation during mod loading.
- `OmniUIRouteCatalog` (`ui/ui_route_catalog.gd`) — the shared route catalog for `backend_class → screen_id` mapping, the runtime `screen_id → scene_path` registry used by `ui/main.gd`, and the known routed screen ids used by content validation.
- **Phase 4 Backend Implementation (completed for the current scope):** `AssemblyEditorBackend`, `DialogueBackend`, `ExchangeBackend`, `CatalogListBackend`, `ListBackend`, `ChallengeBackend`, and `TaskProviderBackend` are implemented as routed screens with backend scripts, contract registration, and route-catalog entries.
- **Backend helper strategy:** `backend_helpers.gd` contains phase-neutral helpers shared by multiple backends. Assembly-editor-only logic stays in `assembly_editor_config.gd` and `assembly_editor_option_provider.gd` so generic helpers do not become a junk drawer.
- **Phase 5 Backend Implementation (complete — basic pass):** `EntitySheetBackend`, `ActiveQuestLogBackend`, `FactionReputationBackend`, `AchievementListBackend`, and `EventLogBackend` are implemented as routed screens with backend scripts, contract registration, and route-catalog entries.

### Planned but not yet implemented

- Backend-driven screen plus data schema: `crafting` / `CraftingBackend` and `recipes.json` (Phase 6 initial pass complete).
- Backend-driven screen: `world_map` / `WorldMapBackend` (deferred to Phase 7).

---

## 3. Recommended Final Backend Catalog

Target end state once this plan is fully executed. Fourteen backends plus engine-owned screens.

Implementation note: the repository has completed the current Phase 4 backend scope. The older `AssemblyEditorBackend` is now explicitly part of Phase 4 maintenance and consistency passes, alongside `DialogueBackend`, `ExchangeBackend`, `CatalogListBackend`, `ListBackend`, `ChallengeBackend`, and `TaskProviderBackend`. Later phases describe the remaining new backend work rather than the already-landed route foundation.

### 3.1 Interactive Backends (moddable, selected via `backend_class`)

| `backend_class` | Screen id | Status | Purpose |
|---|---|---|---|
| `AssemblyEditorBackend` | `assembly_editor` | ✅ Implemented | Slot+part editor — character creator, workbench, ripperdoc, shipyard, cyberware install |
| `ExchangeBackend` | `exchange` | ✅ Implemented | Two-sided trade: move instances between two entity inventories with currency transfer |
| `CatalogListBackend` | `catalog_list` | ✅ Implemented | Infinite vendor — buy fresh `PartInstance`s minted from `PartsRegistry` |
| `CraftingBackend` | `crafting` | Implemented (Phase 6 initial pass) | Recipe-driven: consume N inputs from an inventory, produce 1 output template |
| `ListBackend` | `list_view` | ✅ Implemented | Generic filtered list with pluggable row templates and `action_payload` dispatch |
| `ChallengeBackend` | `challenge` | ✅ Implemented | Single stat check → branch to `reward` or `action_payload` |
| `TaskProviderBackend` | `task_provider` | ✅ Implemented | Faction job board — accept tasks from `faction.quest_pool` |
| `ActiveQuestLogBackend` | `quest_log` | Implemented (Phase 5 basic) | Read active quests + stages + objectives + rewards from `GameState` |
| `EntitySheetBackend` | `entity_sheet` | Implemented (Phase 5 pass 1) | Read-only full entity view: stats, modifiers, equipped parts, inventory summary, faction standings |
| `FactionReputationBackend` | `faction_rep` | Implemented (Phase 5 basic) | Grid/list of factions with reputation tier + emblem + territory summary |
| `AchievementListBackend` | `achievement_list` | Implemented (Phase 5 basic) | Browse achievement progress including locked/unlocked state and thresholds |
| `EventLogBackend` | `event_log` | Implemented (Phase 5 basic) | Rolling history from `GameEvents._event_history` |
| `DialogueBackend` | `dialogue` | ✅ Implemented | Wraps Dialogue Manager with entity portrait and `dialogue_blip` SFX |
| `WorldMapBackend` | `world_map` | ⚠️ Planned | Graph of discovered locations with faction-tinted nodes |

Notes on the new proposals:

**`CraftingBackend`** is fundamentally different from `AssemblyEditorBackend`. Assembly is "pick one part per socket from a filtered catalog." Crafting is "consume a multiset of inventory instances to produce a new template instance, gated on optional stat checks and discovered recipes." Forcing it into AssemblyEditor would require inventing socket semantics that don't exist (stack-count sockets, multi-instance sockets) and would make the modding JSON confusing. Separate backend.

**`ActiveQuestLogBackend`** is not just `ListBackend` with quest rows because it needs to render per-stage objective state (`"Deliver the package" ✓`, `"Return to Gina"` → active). That objective rendering reads from `QuestTracker` output, not just the quest template. A generic list cannot encode that shape cleanly.

**`EntitySheetBackend`** is the read-only complement to AssemblyEditor. Every genre needs this — "press C to open character sheet" is a universal UI idiom. It aggregates stats, per-part modifier breakdowns, inventory summary, and faction standings into one view.

**`FactionReputationBackend`** could in theory live inside EntitySheet, but factions in this engine are a first-class relational database (see `MODDING_GUIDE.md §3.6`). A dedicated view is cleaner, and it composes better with the faction emblem and territory data that already exist on faction templates.

**`AchievementListBackend`** + **`EventLogBackend`** both consume existing engine state that currently has no UI surface. `AchievementRegistry` has full templates. `GameEvents` already maintains a bounded `_event_history`. Both are near-free to build once `ListBackend` is robust, but their contracts are simple enough that distinct backends are easier to validate than overloading `ListBackend` with `data_source: "achievements"` magic strings.

### 3.2 Do we really need this many backends?

Reasonable question. Three of the new backends (`ActiveQuestLog`, `AchievementList`, `EventLog`) are list-shaped and could collapse into a richer `ListBackend` with pluggable row templates. That would look like:

```json
{
  "backend_class": "ListBackend",
  "data_source": "game_state.active_quests",
  "row_template": "quest_card",
  "empty_label": "No active quests."
}
```

The argument for collapsing: fewer backends to maintain, fewer contract registrations, modders learn one pattern.

The argument against collapsing: the data source strings become a DSL, and every valid source has to be documented somewhere. It trades backend proliferation for string proliferation. It also makes load-time validation harder — `BackendContractRegistry` can check "does this field exist" but not "is `game_state.active_quests` a legal source."

**Recommendation: start with distinct backends, converge only if maintenance pain materializes.** Each new backend is ~100–200 lines; none of them are expensive to keep separate. The distinct contract surface is also easier to document for modders, since they can look at §3.6 of the modding guide and see "AchievementListBackend takes these three fields" rather than chasing data-source strings.

### 3.3 Combat placeholder

No combat backend ships in this plan. See §6 for the deferral strategy.

---

## 4. Engine-Owned (Non-Moddable) Screens

These do not use `backend_class` because they do not interact with mod data. They are fixed engine screens registered directly in `ui/main.gd`.

| Screen id | Purpose | Notes |
|---|---|---|
| `main_menu` | Boot landing, new game / continue / load / quit / settings / credits | Implemented with continue/load routing through the current save surfaces |
| `settings` | Audio volumes, AI connection setup, resolution, keybinds, accessibility | Writes to `user://settings.cfg` via `ConfigFile`, independent of mod `config.json`; AI provider ownership lives here rather than in mod data |
| `save_slot_list` | Autosave + manual save/load/delete with playtime/day/location preview | Uses `SaveManager.get_slot_info(slot)` for engine autosave plus manual slots; destructive actions should require an in-screen confirmation step |
| `pause_menu` | In-game pause overlay (Resume / Settings / Save / Main Menu) | Listens to an `Escape` action binding; emits `game_paused` / `game_resumed` |
| `credits` | Attribution + mod list | Pulls from `ModLoader.loaded_mods` so loaded mods show up automatically |
| `gameplay_shell` | Persistent gameplay hub for time controls, autosave, loadout, and exploration routing | Implemented as the current post-load/post-new-game shell; now consumes shared components for profile, currencies, stats, and loadout snapshots |

Rationale for keeping these out of the mod pipeline: they are about the application, not the game. Modders should not be able to replace the save-slot browser or settings menu without invasive script hooks. Aesthetics (theme, strings) still flow through config, but the structure is fixed.

### 4.1 Gameplay Shell specifics

The gameplay shell is now the current engine-owned gameplay hub. Its current responsibilities are:

- **Session summary:** current location, description, interaction count, player identity, currencies, stats, inventory, and equipped loadout snapshot.
- **Location presence:** the shell-owned location surface shows local screens, entities present at the location, entity interaction buttons, and travel exits.
- **Time controls:** current time string, buttons derived from `config.ui.time_advance_buttons`, and a quick autosave surface.
- **Action hub:** "Explore Location", direct loadout access, save browser access, and pause routing.
- **Responsive hosting:** the shell scrolls as a whole on short viewports, and embedded backend/location surfaces are hosted in a scrollable surface area so full-screen-style routed scenes do not clip their top or bottom chrome inside the shell.
- **Hosted surface routing:** every backend screen mounted inside the shell, including an initial `game.new_game_flow` surface such as character creation, receives `opened_from_gameplay_shell` so pop/close actions dismiss the surface and reveal the location surface instead of popping the shell route.
- **Hosted assembly navigation:** assembly-editor cancel actions may reset the game state during character creation, so Begin/confirm flows must not rebuild or compare against the cancel action when deciding how to close the hosted surface.
- **Hosted surface inspection:** the shell title uses the hosted backend's `title` view-model value when available, and the shell debug snapshot includes the active surface's own debug snapshot for Phase 4/5 UI inspection.

The shell is where the engine-owned screens connect back into the moddable ones. Its buttons delegate to existing `UIRouter.push` calls; no new infrastructure required.

---

## 5. Component Library

Components are dumb widgets. Contract: `class_name`, `@onready` members, single `render(view_model: Dictionary) -> void`, no autoload access.

Prioritized by number of downstream consumers. Build in this order.

| Component | View model fields | Used by |
|---|---|---|
| `currency_display` | `{currency_id, amount, symbol, color_token}` | `gameplay_shell`, `exchange`, `catalog_list`, `part_card`, `crafting` |
| `stat_bar` | `{stat_id, label, value, max_value, color_token}` | `entity_portrait`, `stat_sheet`, `challenge`, gameplay shell |
| `stat_sheet` | `{groups: Dict[group_name → Array[stat_line]]}` | `entity_sheet`, `gameplay_shell`, `dialogue` |
| `part_card` | `{template, default_sprite_paths, price_text, badges, affordable}` | `exchange`, `catalog_list`, `list_view`, `crafting` (inputs and outputs) |
| `entity_portrait` | `{display_name, emblem_path, description, faction_badge, stat_preview}` | `dialogue`, `exchange`, `task_provider`, `entity_sheet` |
| `tab_panel` | `{tabs: Array[{id, label, content_scene}]}` | Future tabbed location surfaces, `entity_sheet`, modder-built multi-tab shops |
| `notification_popup` | `{message, level, icon, duration_ms}` | Global — mounts under `ScreenLayer` in `main.tscn` |
| `recipe_card` | `{recipe, input_status: [{template_id, required, have, satisfied}], output_template}` | `crafting` |
| `quest_card` | `{quest_id, display_name, current_stage, objectives: [{label, satisfied}], rewards}` | `quest_log`, potentially `dialogue` inline |
| `faction_badge` | `{faction_id, emblem_path, reputation_tier, reputation_value, color}` | `faction_rep`, `entity_portrait`, `dialogue` |

Each component gets a docstring at the top of its `.gd` file declaring its view model contract, matching the existing pattern in `currency_summary_panel.gd`.

### 5.1 Components already implemented

`currency_summary_panel`, `part_detail_panel`, and `stat_delta_sheet` stay as AssemblyEditor-specific widgets. They consume more specialized view models than the generic components above. `assembly_slot_row` is the reusable row-level component that keeps the editor's slot list inside the same render contract. Keep them; do not force them into the generic library.

The generic library itself is now fully landed for the current plan: `currency_display`, `stat_bar`, `stat_sheet`, `part_card`, `entity_portrait`, `tab_panel`, `notification_popup`, `recipe_card`, `quest_card`, and `faction_badge` all exist as reusable scenes/scripts with `render(view_model)` contracts. `gameplay_shell` now consumes the shared foundation widgets for profile, currencies, stats, and equipped-part snapshots, `entity_portrait` composes `faction_badge`, and `notification_popup` is mounted globally under `ScreenLayer`.

---

## 6. Combat Deferral Strategy

The goal is: build the UI layer today without combat, while preserving the ability to add a `CombatBackend` later without reworking the architecture.

### 6.1 What combat would eventually need

Whenever combat lands, the UI shape will be some combination of:

- A turn queue / initiative tracker.
- Per-combatant action selection (attack / ability / item / defend / flee).
- Target selection (single, area, self).
- Animated or discrete damage/heal/status resolution per action.
- Combat log (already handled by `EventLogBackend` if combat uses `GameEvents`).
- End-of-combat rewards screen (XP, loot, currency).

All of that is "another backend" in the mod pipeline, selected via `backend_class: "CombatBackend"` with params like `"encounter_id": "base:goblin_ambush"`. There is nothing in the current architecture that prevents this.

### 6.2 What we must not do now

To keep the door open:

- **Do not assume non-real-time everywhere in the UIRouter.** The router already takes params and pushes scenes; that's fine for combat later. Don't bake "turn" or "tick" assumptions into the router API.
- **Do not hardcode the stat system around non-combat semantics.** Stats are already pair-based (`health` / `health_max`) per `STAT_SYSTEM_IMPLEMENTATION.md`. Damage is a stat delta. Nothing needs to change.
- **Do not assume `ChallengeBackend` is how all uncertainty resolves.** `ChallengeBackend` is a single gated roll. Combat rolls repeatedly under a turn structure. Keep them as sibling backends when combat lands; resist the urge to make Challenge "do combat too."
- **Avoid `ActionDispatcher` coupling that assumes all actions resolve instantly.** `action_payload` types today are atomic (set_flag, add_currency, start_task). A future combat action payload (`"begin_encounter"`) may hand control to a combat backend that runs for many ticks. Treat action payloads as potentially asynchronous — ActionDispatcher should already tolerate that, but it's worth noting in comments when that file is next edited.

### 6.3 What to do when combat is ready

Sketch, not spec:

- New data type: `encounters.json` → `EncounterRegistry`. Template fields include enemy roster, environment conditions, starting stance, victory conditions, rewards.
- New backend: `CombatBackend` with `encounter_id` as the required field.
- New scene: `ui/screens/backends/combat_screen.tscn` with initiative tracker, action panels, target picker.
- New components: `combatant_card` (variant of `entity_portrait` with initiative indicator and HP bar), `action_button_grid`.
- Events: `combat_started`, `combat_turn_started`, `combat_action_resolved`, `combat_ended` on `GameEvents`.

None of that contradicts anything in this plan. It slots in alongside the other backends.

---

## 7. New Data Schemas Required

Crafting needs `recipes.json` today. Talent/skill trees are a separate follow-up (not in this plan) but would need `talents.json` by the same pattern.

### 7.1 `recipes.json`

Lives in `mods/<author>/<mod>/data/recipes.json`. Loaded by a new `RecipeRegistry` under `systems/loaders/`. Registered on `DataManager` as `get_recipe(id)` / `query_recipes(...)`.

Minimal schema sketch:

```json
{
  "recipes": [
    {
      "recipe_id": "base:iron_sword",
      "display_name": "Iron Sword",
      "description": "A plain but reliable blade.",
      "output_template_id": "base:iron_sword_part",
      "output_count": 1,
      "inputs": [
        { "template_id": "base:iron_ingot", "count": 2 },
        { "template_id": "base:leather_strip", "count": 1 }
      ],
      "required_stations": ["base:forge"],
      "required_stats": { "smithing": 5 },
      "required_flags": ["base:learned_iron_sword"],
      "craft_time_ticks": 4,
      "discovery": "learned_on_flag",
      "tags": ["weapon", "tier_1"],
      "sprite": "res://mods/base/assets/icons/iron_sword.png"
    }
  ],
  "patches": []
}
```

Schema notes:

- `inputs` is a multiset of `{template_id, count}`. The crafting backend consumes `count` instances per input.
- `required_stations` lets mods gate recipes to specific location screens — e.g. only craftable when `crafting` is opened from a `base:forge` location. Empty/absent = craftable anywhere.
- `required_stats` and `required_flags` reuse existing condition shapes.
- `discovery` is one of `"always"` (visible from the start), `"learned_on_flag"` (visible when `learned:<recipe_id>` flag is set on the player), or `"auto_on_ingredient_owned"` (visible once the player has all inputs at least once).
- `craft_time_ticks: 0` = instant (default); >0 routes through `TaskRunner` as a timed production task.
- Confirm-time hardening rechecks station filters, recipe allowlists, tags, discovery, and stat gates before any inputs are consumed.

### 7.2 `CraftingBackend` params

Mod JSON shape for placing a crafting station at a location:

```json
{
  "tab_id": "forge_crafting",
  "display_name": "Craft at Forge",
  "backend_class": "CraftingBackend",
  "station_id": "base:forge",
  "recipe_tags": ["weapon", "armor"],
  "recipe_ids": [],
  "crafter_entity_id": "player",
  "input_source_entity_id": "player",
  "output_destination_entity_id": "player",
  "screen_title": "Forge"
}
```

Contract:

| Param | Required | Default | Purpose |
|---|---|---|---|
| `station_id` | ✓ | — | Matches against `recipe.required_stations` |
| `recipe_tags` | optional | `[]` | Filter visible recipes by tag |
| `recipe_ids` | optional | `[]` | Explicit recipe whitelist (stacks with tags) |
| `crafter_entity_id` | optional | `"player"` | Whose stats are checked against `required_stats` |
| `input_source_entity_id` | optional | same as crafter | Inventory to consume from |
| `output_destination_entity_id` | optional | same as crafter | Inventory that receives the output |
| `screen_title` / `screen_description` | optional | defaults | Presentation |

The separate `crafter`, `input_source`, `output_destination` fields mirror the target/payer/recipient split already in AssemblyEditor, so a modder could model "apprentice crafts at master's forge using guild materials, output goes to guild stockpile."

### 7.3 Where crafting integrates with existing systems

- Consumes and produces via `TransactionService` (already planned in `PROJECT_STRUCTURE.md §Core Systems`) — no direct inventory mutation from the backend.
- Timed recipes create a task via `TimeKeeper.accept_task` with a synthetic task template — no new code path, just a `recipe_craft` task template type.
- Recipe discovery flags flow through existing `flag_changed` on `GameEvents`. Nothing new.

---

## 8. Backend Architecture Guardrails

This section describes the current backend pattern, not future scaffolding. Phase 1 established it with `AssemblyEditorBackend`, and Phase 4 extended it across the first round of moddable backends. Keep using this structure for every new backend so the UI layer stays boring in the best possible way.

### 8.1 Split Backend from Screen

Current flat file layout per backend:

```
ui/screens/backends/exchange_screen.tscn
ui/screens/backends/exchange_screen.gd      # @onready refs, signal forwarding, render dispatch
ui/screens/backends/exchange_backend.gd     # class_name OmniExchangeBackend extends OmniBackendBase
```

`OmniBackendBase` lives in `ui/screens/backends/backend_base.gd`:

```gdscript
class_name OmniBackendBase
extends RefCounted

func initialize(params: Dictionary) -> void: pass
func build_view_model() -> Dictionary: return {}
func confirm() -> Dictionary: return {"status": "ok"}
func get_required_params() -> Array[String]: return []
```

The `assembly_editor_screen.gd` refactor is complete: the screen now owns node references and input handlers, while `assembly_editor_backend.gd` owns runtime state, view-model assembly, and commit/cancel behavior. Keep `AssemblyEditorBackend` inside Phase 4 consistency work because it is the oldest backend and the easiest one to accidentally let drift from the newer pattern.

### 8.2 `BackendContractRegistry`

`systems/backend_contract_registry.gd` is implemented. The registry is populated by built-in backends at the start of `ModLoader.load_all_mods()`, then consulted during content validation. Given a dictionary containing a `backend_class` field, it returns precise required-field and type-validation issues for screens and interactions.

Contract entries are registered at engine boot by each backend script in a single `static func register_contract()` method. That keeps the contract next to the backend that enforces it.

```gdscript
# In exchange_backend.gd
static func register_contract() -> void:
    BackendContractRegistry.register("ExchangeBackend", {
        "required": ["source_inventory", "destination_inventory", "currency_id"],
        "optional": ["transaction_sound", "list_icon", "price_modifier"]
    })
```

Boot order: contracts register inside the content-loading pipeline before validation runs. That keeps headless tests, non-UI boot flows, and the main scene on the same path instead of making registration a `ui/main.gd` concern.

### 8.3 Helper Script Boundaries

Use helper scripts deliberately:

- `backend_helpers.gd` is for phase-neutral, cross-backend utilities such as entity lookup, display-name formatting, currency view models, part cards, and stat-preview lines.
- Backend-specific helpers keep the backend readable without pretending their logic is reusable. Current examples are `assembly_editor_config.gd` and `assembly_editor_option_provider.gd`.
- Do not add a helper just because a method is private. Extract when the code has a stable boundary, a testable responsibility, or at least two likely consumers.
- Do not name helpers after phases. Phases are planning history; helper filenames should describe their runtime role.

### 8.4 Typed view models (optional)

A `ViewModel` base resource with `to_dict()` / `from_dict()` would let tests snapshot backend output without instantiating scenes. This is a nice-to-have, not a blocker. Components still accept `Dictionary` at the render boundary; the typed resource is a backend-side convenience.

---

## 9. Phased Implementation Plan


### Phase 1 — Pattern establishment (~1–2 days)

Current status: complete. `OmniBackendBase`, `OmniAssemblyEditorBackend`, `BackendContractRegistry`, and load-time `AssemblyEditorBackend` contract validation are all in place, and `assembly_editor_screen.gd` now acts as a screen layer over the extracted backend. The backend has also been trimmed so parameter/navigation parsing and slot option sourcing live in dedicated helper scripts, reducing the amount of monolithic code future backend authors need to copy.

- Create `ui/screens/backends/backend_base.gd` with `OmniBackendBase`.
- In-place refactor `assembly_editor_screen.gd` to split into `assembly_editor_backend.gd` + the screen script. No behavior changes. Tests must still pass.
- Create `systems/backend_contract_registry.gd`.
- Register the `AssemblyEditorBackend` contract (mostly optional fields; validates parameter types).

Deliverable: one backend running the target pattern; the template for every subsequent backend is defined.

### Phase 2 — Component library (~2–3 days)

Build in the order listed in §5. Each component is a `.tscn` + `.gd` + view model docstring.

Current status: complete for the component set scoped by this plan. The shared library in §5 is implemented and already consumed by `gameplay_shell`, global notifications, and the refactored assembly/editor surfaces where appropriate.

Priority order:
1. `currency_display` (unblocks shell refactor)
2. `stat_bar` → `stat_sheet` (unblocks shell refactor and entity sheet)
3. `part_card` (unblocks exchange, catalog_list, crafting)
4. `entity_portrait` (unblocks dialogue, task_provider)
5. `notification_popup` (global — mounts in main.tscn)
6. `recipe_card`, `quest_card`, `faction_badge` (backend-specific; build alongside their backends)
7. `tab_panel` (lowest priority; reserved for future tabbed location surfaces if we want tabs instead of a button list)

### Phase 3 — Engine-owned screens (~2 days)

Current status: functionally complete. The engine-owned route set is built, wired through `main_menu` and `ui_cancel`, and covered by smoke tests plus targeted behavior tests for pause/cancel routing, settings persistence on back-navigation, save-slot delete confirmation, current-screen debug snapshots, the extracted `gameplay_shell_presenter`, and the shared runtime route catalog. The remaining work in this area is polish and future follow-on improvements, not missing Phase 3 route contracts.

- Refactor `gameplay_shell_screen.gd` in place to use components from Phase 2. Done.
- Extract the shell's view-model assembly into a presenter/helper so the screen renders strictly from a backend-style payload. Done.
- Build `settings_screen`, `save_slot_list_screen`, `pause_menu_screen`, `credits_screen`. Done.
- Wire them into `main_menu` and into an Escape-key pause handler in `main.gd`. Done.

Deliverable: full boot → menu → settings → save-slot → game shell loop using real components.

### Phase 4 — Backend consistency and moddable backends, round 1 (~4–5 days)

**Phase 4 completion note (April 2026):** The current Phase 4 scope is implemented. Treat `AssemblyEditorBackend` as part of Phase 4 for all remaining consistency passes, even though it first landed earlier, because it shares the same backend/screen/contract responsibilities as the six round-1 moddable backends.

- **Backend script** (`*_backend.gd`) — Extends `OmniBackendBase`, implements `initialize()`, `build_view_model()`, and `confirm()`.
- **Screen script** (`*_screen.gd`) — Thin controller layer; owns scene refs and dispatches to backend.
- **Scene file** (`*_screen.tscn`) — UI layout; components receive view model dicts from the screen controller.
- **Shared helper** (`backend_helpers.gd`) — Phase-neutral utility functions extracted from common patterns across backends to reduce duplication.
- **Route catalog entry** — Backend registered in `ui/ui_route_catalog.gd` with screen id mapping.
- **Contract registration** — Backend registers its param contract during `ModLoader` phase.

**Helper boundary for this phase:**

- `backend_helpers.gd` is generic and can be used by any current or future backend.
- Component view-model builders stay centralized in `backend_helpers.gd`; backends should use `build_part_card_view_model`, `build_quest_card_view_model`, `build_task_card_view_model`, `build_entity_portrait_view_model`, `build_stat_sheet_view_model`, and `build_faction_badge_view_model` instead of recreating those payload shapes locally.
- `assembly_editor_config.gd` — Configuration and state management helper.
- `assembly_editor_option_provider.gd` — Part option sourcing and filtering logic.
- Assembly editor helpers are intentionally specific. Do not move their logic into `backend_helpers.gd` unless another backend has the same concrete need.
- Inventory-backed assembly options are exact `PartInstance` selections, not template placeholders. Owned inventory installs are free moves from inventory to equipment; vendor/source installs stage source removal, payment, and target equipment as one commit.

Historical build order:

1. `AssemblyEditorBackend` consistency pass (backend/screen split, contract registration, config/helper extraction).
2. `DialogueBackend` (depends on `entity_portrait`; high modder priority since Dialogue Manager integration unblocks writable content).
3. `ExchangeBackend` (depends on `part_card`, `currency_display`).
4. `CatalogListBackend` (shares most of Exchange's shape).
5. `ListBackend` (generic, depends on `part_card` + pluggable row templates).
6. `ChallengeBackend` (depends on `stat_bar`, `entity_portrait`).
7. `TaskProviderBackend` (depends on `entity_portrait`, `quest_card`).

Each follows the Phase 1 pattern: scene, screen script, backend script, contract registration. Register backend-to-route mappings in `ui/ui_route_catalog.gd`; `ui/main.gd` consumes that catalog rather than owning backend registration itself.

### Phase 5 — Moddable backends, round 2 (~3–4 days)

The remaining read-only view backends depend on existing runtime state and the component library that is already in place.

1. `EntitySheetBackend` + `stat_sheet` integration. Implemented in Phase 5 pass 1 with `entity_sheet` routing, read-only entity stats/equipment/inventory/reputation view models, and screen smoke/unit coverage.
2. `ActiveQuestLogBackend` + `quest_card`. Implemented in the Phase 5 basic completion pass.
3. `FactionReputationBackend` + `faction_badge`. Implemented in the Phase 5 basic completion pass.
4. `AchievementListBackend`. Implemented in the Phase 5 basic completion pass.
5. `EventLogBackend`. Implemented in the Phase 5 basic completion pass.

### Phase 6 — Crafting (~3–4 days)

Current status: initial pass complete. The repository now has `recipes.json`, `RecipeRegistry`, recipe query/validation APIs on `DataManager`, `CraftingBackend`, `crafting_screen`, `recipe_card` integration, timed-craft handoff through `TaskRunner`, and a base diagnostic recipe/station.

1. New data type: `recipes.json` schema + `RecipeRegistry` loader + `DataManager.get_recipe` / `query_recipes` / `query_recipes_by_tag`. Done.
2. `CraftingBackend` + `crafting_screen` + `recipe_card` integration. Done.
3. Timed-craft task type wired through `TaskRunner` for `craft_time_ticks > 0`. Done via the generic `base:recipe_craft` task shell and runtime reward overrides.
4. Base mod ships at least one example recipe and one crafting station on a test location for the integration test. Done with the diagnostic crafting bench.

### Phase 7 — World Map (~2 days)

`WorldMapBackend` with a graph render of `LocationGraph.get_all_locations()`, faction-tinted nodes, travel-on-click. Keep it simple — no fog-of-war, no region overlays. Those can be later additions.

### Phase 8 — Combat placeholder (deferred)

Not built in this plan. When combat lands, it follows the same pattern as every other backend. See §6.

**Remaining estimated effort for Phase 7: ~2 engineering days.** The original Phase 1–6 foundation is now complete for the current scope, so future estimates should focus on world map and polish.

---

Phase 4 status update: `AssemblyEditorBackend`, `DialogueBackend`, `ExchangeBackend`, `CatalogListBackend`, `ListBackend`, `ChallengeBackend`, and `TaskProviderBackend` all have backend scripts, routed screen scenes, route-catalog entries, and load-time contract registration. Future Phase 4 cleanup should include assembly editor when checking helper boundaries, view-model shape, contract naming, tests, and route behavior.

## 10. Testing and Verification

Every phase produces testable surface. Tests land alongside implementation, not as a follow-up.

### 10.1 Unit tests (GUT)

- Each backend: given params X and a known `GameState`, `build_view_model()` returns dictionary Y. Backends are `RefCounted` and need no scene setup.
- `BackendContractRegistry`: fixtures with missing required fields fail validation; fixtures with all required fields pass.
- `RecipeRegistry`: recipe loading, patch application, reference validation (inputs reference real parts).
- `ConditionEvaluator` extensions for recipe gating (if any).

### 10.2 Integration tests

- Full mod load with a fixture mod that declares one of each backend_class — all must validate at load time.
- Save/load round-trip after pushing each backend screen and committing a side effect — no state corruption.
- Theme override — load a fixture mod that sets `ui.theme.primary_color`, verify `OmniSemantic.primary` matches on a freshly pushed screen.

### 10.3 Smoke tests

- GUT scene runner pushes each screen with canonical params and asserts no `push_error` during first render.
- Dialogue screen runs a fixture `.dialogue` file start-to-finish without errors.
- Shared route-catalog tests assert the engine-owned runtime registry still resolves to real scenes and known screen ids.

### 10.4 Debug surfaces

Per `PROJECT_STRUCTURE.md §Debug And Test Tooling`, every new system gets a debug inspection surface. The current overlay now shows the routed screen stack, current params, current-screen debug snapshots for the active screen when available, and the registered backend contract set. Continue growing that "UI State" surface toward:

- Current router stack.
- Each screen's most recently built view model (via a weakref — don't retain).
- Registered backend contracts.
- Backend contract validation failures from the last `ModLoader` run.

---

## 11. Open Questions

Items this plan cannot resolve without more information from the project owner.

**Q1. Should `tab_panel` replace the current button list in `LocationViewScreen`?**

**Answer (deferred):** The current button list is simpler and more modder-friendly (easier to reason about ordering, no hidden state). `tab_panel` is lower priority and best left for Phase 5 if needed. If a mod wants tabs, they can currently compose their own layout using a custom backend. Upgrade LocationViewScreen to optionally use `tab_panel` only if modders request it.
