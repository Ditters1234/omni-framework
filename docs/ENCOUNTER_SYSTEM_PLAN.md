# Omni-Framework — Encounter System Plan

> **See also:** [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for autoload and backend architecture, [`modding_guide.md`](modding_guide.md) for backend payloads, condition syntax, and `RewardService` shapes, [`SYSTEM_CATALOG.md`](SYSTEM_CATALOG.md) for the registry of helper systems, and [`STAT_SYSTEM_IMPLEMENTATION.md`](STAT_SYSTEM_IMPLEMENTATION.md) for resource/capacity stat semantics.

This document is a planning reference for the encounter system — a turn-based, multi-round, data-driven framework for handling combat, negotiation, persuasion, seduction, political confrontation, and any other genre of back-and-forth challenge. The existing `ChallengeBackend` is a one-shot stat gate. The encounter system is its multi-round generalization.

It is written to be revised. Treat it as the current best thinking, not a frozen spec.

Decisions this document assumes:

- **Encounters are pure data, not pure code.** Every encounter is a JSON template loaded through the existing mod pipeline. No GDScript per-encounter logic; modders compose encounters from a fixed vocabulary of actions, effects, conditions, and outcomes.
- **The encounter system reuses the existing primitives.** `ConditionEvaluator` handles availability and resolution checks. `RewardService` handles outcome payouts. `ActionDispatcher` handles outcome side effects. `EntityInstance` holds participant stats. We do not invent parallel systems for things that already exist.
- **Genre-agnostic.** A combat encounter, a sex encounter, a political debate, and an interrogation should all use the same backend with different action sets and resolution conditions. If the schema needs a genre-specific field, the schema is wrong.
- **Encounter state is encounter-local, real entity state is real.** Damage to `health` mutates the real `EntityInstance` round-by-round (so fleeing keeps the wound). Encounter-local progress meters (persuasion progress, intimidation, arousal, suspicion) live entirely in the backend's working memory and disappear on resolve.
- **One encounter at a time.** No nested or concurrent encounters in v1. Saving mid-encounter persists real entity changes only; encounter-local state is discarded on load and no outcome fires unless the player explicitly cancels through a configured abort/cancel outcome.

---

## 1. Guiding Principles

Encounters extend the same layered contract as the rest of the engine:

```
Encounter template (JSON) → EncounterRegistry → EncounterBackend → ConditionEvaluator / RewardService / ActionDispatcher → GameState
```

What each layer is responsible for:

| Layer | Responsibility | What it must not do |
|---|---|---|
| Template (JSON) | Declare default participants, action vocabulary, opponent strategy, resolution conditions, outcomes | Embed runtime state, embed GDScript, hardcode a reusable encounter to a single NPC when launch-time participant overrides are appropriate |
| `EncounterRegistry` | Validate, namespace, and serve templates | Hold runtime state |
| `EncounterBackend` | Hold the live state machine, apply actions, advance rounds, evaluate resolution | Bypass `ConditionEvaluator` or `ActionDispatcher` for behavior already covered there |
| `ConditionEvaluator` | Evaluate availability, action checks, resolution conditions | Mutate state |
| `RewardService` / `ActionDispatcher` | Apply outcome rewards and side effects | Know anything about encounters |

### Why a separate backend rather than extending `ChallengeBackend`

`ChallengeBackend` is a one-shot stat gate: build view model → confirm → branch. It owns no per-round state and exposes no mid-flow actions. Adding rounds, action vocabulary, opponent turns, encounter-local meters, and multi-outcome resolution to it would either break its contract or require enough new fields to make `ChallengeBackend` two backends in one. The encounter system is a clean addition: a new backend class, a new registered contract, a new screen scene, and a new JSON file. `ChallengeBackend` stays as-is for simple gates.

---

## 2. Current State Summary

### What the engine already provides

- `ChallengeBackend` — one-shot stat check with success/failure routing. Useful as a reference implementation; will not change.
- `ConditionEvaluator` — typed condition blocks (`stat_check`, `stat_greater_than`, `has_flag`, `has_part`, `has_currency`, `reputation_threshold`, `quest_complete`, etc.) with AND/OR/NOT logic blocks. The encounter system consumes this directly.
- `ActionDispatcher` — full vocabulary of side effects: `give_currency`, `modify_stat`, `set_flag`, `give_part`, `start_quest`, `travel`, `spawn_entity`, `unlock_achievement`, `emit_signal`, etc. Encounter outcomes dispatch through this.
- `RewardService.apply_reward()` — accepts a flat reward dictionary (`{ "credits": 50, "reputation": {...}, "items": [...], "flags": {...} }`) and applies it to an entity. Encounter outcomes use this shape unmodified.
- `BackendContractRegistry` — mod-load-time contract validation for backend payloads with `required`, `optional`, and `field_types`. Used by every existing backend.
- `BackendHelpers` — shared `resolve_entity_lookup`, `humanize_id`, portrait/sound resolution. The new backend uses these.
- `GameState.commit_entity_instance()` — the standard pattern for safely mutating an entity (`duplicate_instance` → modify → commit). The encounter backend uses this on every action that touches real entity stats.
- `GameEvents` — global signal bus. New encounter signals will be added here, not on the backend.

### What is missing

- **Multi-round state machine.** No backend currently maintains across-confirm-call state beyond `Dialogue Manager`. We need to hold `_round`, `_encounter_stats`, `_log`, `_active_modifiers`, etc. between `confirm`-equivalent calls.
- **Encounter-local stat namespace.** `ConditionEvaluator` only checks real `EntityInstance` stats and global flags. We need a way to express "the encounter's `persuasion_progress` is ≥ 80" without polluting any entity's stat dict.
- **Opponent action selection.** No system today picks an action from a weighted list with conditional modifiers. New helper module.
- **Effect formula evaluation.** Damage and similar deltas often want to scale with the actor's stats. We need a small, JSON-native formula model — not a string DSL.
- **Round-by-round event log surface.** Encounters need a per-action log feed visible to the player. No existing component renders this.
- **`encounters.json` data file, `EncounterRegistry`, `EncounterBackend`, `encounter_screen.tscn`.** None exist yet.

---

## 3. JSON Schema

This is the canonical authored shape. Every field below is named to match existing Omni conventions: `entity_id`, `template_id`, `screen_title`, `next_screen_id`, `action_payload`, `reward`, `condition`, etc.

### 3.1 Top-level file shape

`encounters.json` follows the same additions/patches pipeline as every other data file:

```json
{
  "encounters": [
    {
      "encounter_id": "my_name:my_mod:tavern_brawl",
      "display_name": "Tavern Brawl",
      "description": "A drunk regular swings on you.",
      "screen_title": "Tavern Brawl",
      "screen_description": "Settle this with fists or words.",

      "participants": { ... },
      "encounter_stats": { ... },
      "actions": { ... },
      "opponent_strategy": { ... },
      "resolution": { ... }
    }
  ],
  "patches": [ ... ]
}
```

`patches` reuses the same `target` / `set` / `add_*` / `remove_*` shape that entities and parts already use, registered in `EncounterRegistry`. See section 4.4 for the registry contract.

### 3.2 Participants

```json
"participants": {
  "player": {
    "entity_id": "player"
  },
  "opponent": {
    "entity_id": "my_name:my_mod:drunk_patron",
    "portrait_entity_id": "my_name:my_mod:drunk_patron"
  }
}
```

- `player` and `opponent` are **role keys** — fixed names the schema reserves. Future versions may add `ally_*` and `enemy_*` slots; v1 only uses `player` and `opponent`.
- `entity_id` accepts the same lookup forms as `BackendHelpers.resolve_entity_lookup`: `"player"` for `GameState.player`, `"entity:<id>"` or just `"<id>"` for a runtime entity.
- `portrait_entity_id` is optional; defaults to the participant's own `entity_id`. Same fallback rule as `ChallengeBackend`.
- Resolution at runtime: the backend resolves these to real `EntityInstance` references at `initialize()` time. If either resolves to `null`, the backend reports a setup error and the encounter aborts cleanly via the same routing fallback `ChallengeBackend` already uses.
- Launch payloads may override participant lookups without patching the template. `EncounterBackend` accepts `player_entity_id`, `opponent_entity_id`, and `participant_overrides` (`{ "opponent": "entity:..." }`) so one authored encounter can be reused by many NPC interactions. Template participants remain the defaults for direct launches and tests.

### 3.3 Encounter-local stats

```json
"encounter_stats": {
  "intimidation": { "default": 0, "min": 0, "max": 100 },
  "persuasion_progress": { "default": 0, "min": 0, "max": 100 },
  "round": { "default": 0, "kind": "counter" }
}
```

- Authored once per encounter. These are progress meters, not real entity stats. The engine does not write them to any save file; they exist only inside `EncounterBackend` while the encounter runs.
- `kind` defaults to `meter` (clamped to `min`/`max`). `counter` is unclamped and incremented automatically by the runtime each round.
- Referenced elsewhere by the namespace `encounter:<stat_id>`. Example: `{"type": "encounter_stat_check", "stat": "intimidation", "op": ">=", "value": 100}`.
- Why a separate namespace: it lets a single encounter type have meaningful per-instance progress without mutating any real `EntityInstance.stats` dict. The seduction encounter's "arousal", the negotiation encounter's "concession_level", and the brawl's "intimidation" all coexist without polluting the global stat definition list.

### 3.4 Actions

Actions are the verbs of the encounter. Both sides have action lists; the player's are picked by the user, the opponent's are picked by `opponent_strategy`.

```json
"actions": {
  "player": [
    {
      "action_id": "punch",
      "label": "Punch",
      "description": "A solid hook. Cheap, reliable, hurts.",
      "tags": ["physical", "melee"],

      "availability": {
        "type": "stat_check",
        "entity_id": "player",
        "stat": "stamina",
        "op": ">=",
        "value": 5
      },

      "cost": [
        { "effect": "modify_stat", "target": "player", "stat": "stamina", "base_delta": -5 }
      ],

      "check": {
        "type": "stat_check",
        "entity_id": "player",
        "stat": "power",
        "op": ">=",
        "value": 5
      },

      "on_success": [
        {
          "effect": "modify_stat",
          "target": "opponent",
          "stat": "health",
          "base_delta": -8,
          "stat_modifiers": { "user.power": -1.0 }
        },
        {
          "effect": "log",
          "text": "You connect cleanly."
        }
      ],

      "on_failure": [
        { "effect": "log", "text": "Your punch goes wide." }
      ]
    }
  ],

  "opponent": [
    {
      "action_id": "swing",
      "label": "Wild Swing",
      "weight": 3,
      "on_success": [
        { "effect": "modify_stat", "target": "player", "stat": "health", "base_delta": -8 }
      ]
    },
    {
      "action_id": "shove",
      "label": "Shove",
      "weight": 1,
      "weight_modifiers": [
        {
          "if": {
            "type": "stat_check",
            "entity_id": "encounter:opponent",
            "stat": "health",
            "op": "<",
            "value": 30
          },
          "weight": 5
        }
      ],
      "on_success": [
        { "effect": "modify_stat", "target": "player", "stat": "stamina", "base_delta": -10 }
      ]
    }
  ]
}
```

Action field reference:

| Field | Required | Notes |
|---|---|---|
| `action_id` | yes | Unique within this encounter |
| `label` | yes for player | UI button text |
| `description` | no | UI tooltip / detail text |
| `tags` | no | Arbitrary array of strings; consumed by future opponent counter-logic |
| `availability` | no | `ConditionEvaluator` block. If absent, action is always selectable. If present and false, the action is shown but disabled with the failing condition surfaced as a tooltip. |
| `cost` | no | Array of encounter effect entries applied **before** the check resolves. Costs apply only after availability is rechecked and the action is accepted; they still apply when the later check fails. |
| `check` | no | `ConditionEvaluator` block. If absent, action is treated as auto-success. |
| `on_success` | no | Array of effect entries (see 3.5). Applied if `check` is true. |
| `on_failure` | no | Array of effect entries. Applied if `check` is false. |
| `weight` | yes for opponent | Base weight for weighted-random selection |
| `weight_modifiers` | no for opponent | Conditional weight overrides; first matching `if` block wins |

Why `availability` is its own field rather than rolled into `check`: availability gates whether the player can pick the action this round at all (greyed out, no cost); `check` decides whether the accepted action succeeds (cost spent even on check failure). Conflating them collapses two distinct user-experience states.

### 3.5 Effects

Effects are the encounter system's mini-vocabulary of in-round consequences. They are deliberately a smaller surface than `ActionDispatcher` because most `ActionDispatcher` actions (start_quest, travel, give_part, push_screen, spawn_entity) are too heavy to fire mid-round. Outcome `action_payload` and `reward` blocks (section 3.7) handle those.

Effect types in v1:

| `effect` | Fields | Notes |
|---|---|---|
| `modify_stat` | `target` (`"player"` / `"opponent"`), `stat`, `base_delta`, optional `stat_modifiers` | Mutates the **real** `EntityInstance` via the `commit_entity_instance` pattern. `stat_modifiers` is a dict of `{"user.<stat>": multiplier, "target.<stat>": multiplier}` used to scale the delta. |
| `modify_encounter_stat` | `stat`, `base_delta`, optional `stat_modifiers` | Mutates the encounter-local meter. Clamped to `min`/`max`. |
| `set_encounter_stat` | `stat`, `value`, optional `clamp` | Direct assignment to an encounter-local meter. Clamps to `min`/`max` by default; set `clamp: false` only for counters or intentionally unbounded values. |
| `apply_tag` | `target`, `tag`, optional `duration` (rounds) | Adds a temporary tag to the participant for opponent counter-logic. Decremented at end-of-round. |
| `remove_tag` | `target`, `tag` | Removes a tag immediately. |
| `log` | `text` | Appends a line to the encounter log surface. Supports `{user_name}`, `{target_name}`, `{action_label}` substitutions. |
| `set_flag` | `flag_id`, `value`, optional `entity_id` | Same shape as `ActionDispatcher.set_flag`. Persists immediately. This is the only v1 in-round effect that writes non-stat persistent state. |
| `resolve` | `outcome_id` | Force-resolves the encounter to the named outcome (used by player "Flee" actions, opponent "Surrender" branches, etc.). |

Formula scaling (`stat_modifiers`):

```
final_delta = base_delta + Σ ( modifier_value * stat_value )
```

Concrete example:
```json
{
  "effect": "modify_stat",
  "target": "opponent",
  "stat": "health",
  "base_delta": -5,
  "stat_modifiers": {
    "user.power": -1.5,
    "target.armor": 0.5
  }
}
```
With `user.power = 6` and `target.armor = 2`, final_delta = `-5 + (-1.5 * 6) + (0.5 * 2) = -13`.

This is intentionally *not* a string DSL. Modders write JSON; the engine evaluates by table lookup. Avoids parsing, avoids injection, avoids the temptation to embed scripting.

### 3.6 Opponent strategy

```json
"opponent_strategy": {
  "kind": "weighted_random"
}
```

V1 supports `weighted_random` only. The runtime picks an opponent action by:

1. For each action: `effective_weight = action.weight`; for each `weight_modifiers` entry whose `if` evaluates true, `effective_weight = entry.weight`. The first matching modifier wins.
2. Discard actions where `availability` (if present) is false.
3. Roll a weighted random pick over the surviving list using an injected `RandomNumberGenerator` from the backend. Tests pass a seeded generator; runtime can use a fresh generator unless later save/resume support needs deterministic replay.

Future strategy kinds (v2+):

- `scripted` — predetermined sequence per round (`"sequence": ["swing", "swing", "shove", ...]`)
- `behavior_tree` — bind to a LimboAI tree on the opponent entity; the tree picks the action_id
- `ai_persona` — query `AIManager` with the encounter context to pick an action_id from the available list, with weighted_random fallback

The strategy field is wrapped in an object (`{"kind": "weighted_random"}`) rather than a bare string so future kinds can carry their own config payload without a schema break.

### 3.7 Resolution and outcomes

```json
"resolution": {
  "outcomes": [
    {
      "outcome_id": "victory",
      "conditions": {
        "type": "stat_check",
        "entity_id": "encounter:opponent",
        "stat": "health",
        "op": "<=",
        "value": 0
      },
      "reward": {
        "credits": 25,
        "reputation": { "my_name:my_mod:tavern_regulars": 5 }
      },
      "action_payload": null,
      "next_screen_id": "",
      "pop_on_resolve": true,
      "screen_text": "The drunk goes down hard."
    },
    {
      "outcome_id": "intimidated",
      "conditions": {
        "type": "encounter_stat_check",
        "stat": "intimidation",
        "op": ">=",
        "value": 100
      },
      "reward": { "credits": 10 },
      "action_payload": { "type": "set_flag", "flag_id": "tavern_drunk_intimidated", "value": true },
      "screen_text": "He drops his fists and backs off."
    },
    {
      "outcome_id": "defeat",
      "conditions": {
        "type": "stat_check",
        "entity_id": "encounter:player",
        "stat": "health",
        "op": "<=",
        "value": 1
      },
      "action_payload": { "type": "travel", "location_id": "my_name:my_mod:hospital" },
      "screen_text": "You black out on the sawdust floor."
    },
    {
      "outcome_id": "fled",
      "trigger": "manual",
      "screen_text": "You shoulder past the crowd and out the door."
    }
  ],
  "max_rounds": 12,
  "max_rounds_outcome": "fled",
  "evaluation_order": "first_match"
}
```

Outcome field reference:

| Field | Notes |
|---|---|
| `outcome_id` | Unique within this encounter |
| `conditions` | `ConditionEvaluator` block. Evaluated after the player action and again at end-of-round after the opponent action. The first automatic outcome whose conditions match resolves the encounter. Omit when `trigger: "manual"`. |
| `trigger` | Defaults to `"automatic"`. `"manual"` means the outcome only fires when an action's `resolve` effect names this `outcome_id`. |
| `reward` | Standard `RewardService.apply_reward()` shape. Applied on resolve to the player. |
| `action_payload` | Single `ActionDispatcher` action dict. Dispatched on resolve. |
| `next_screen_id` / `next_screen_params` | Push a screen on resolve. Same semantics as `ChallengeBackend`. |
| `pop_on_resolve` | Pop the encounter screen on resolve when no `next_screen_id` is set. Same semantics as `ChallengeBackend.pop_on_confirm`. |
| `screen_text` | Final status line shown to the player before they dismiss the resolved encounter. |

`max_rounds_outcome` references an `outcome_id` from the same array — the encounter resolves to that outcome if `max_rounds` elapses without any other outcome firing. Setup-time validation rejects an unknown id.

`cancel_outcome` is optional. If present, `cancel()` resolves to that manual outcome and applies its reward/action payload like any other outcome. If absent, `cancel()` simply returns a pop navigation result and does not fire an outcome. This keeps explicit authored consequences possible without surprising save/load or back-button behavior.

`evaluation_order` defaults to `first_match`. Optional `priority` field per outcome allows explicit ordering without depending on JSON array order; `evaluation_order: "priority"` switches to that mode.

### 3.8 Optional top-level fields

| Field | Notes |
|---|---|
| `intro_action_payload` | Single `ActionDispatcher` dispatched once at encounter start (e.g., `set_flag` to mark the opponent as engaged). |
| `entry_condition` / `entry_conditions` | Same pattern as `locations.json` location gates. If false, the encounter cannot be started; useful for conditional encounter list screens. |
| `cancel_outcome` | Optional manual outcome id used when the player cancels. If omitted, cancel pops without firing an outcome. |
| `tags` | Top-level tags for filtering and querying (e.g., `["combat", "tavern", "tutorial"]`). |
| `success_sound` / `failure_sound` / `default_sound` | Same convention as `ChallengeBackend`. The runtime maps outcomes to sounds via convention: any outcome with `health <= 0` opponent condition uses `success_sound`, etc. Or modders can attach `sound` directly per outcome. |

---

## 4. Engine Architecture

### 4.1 New files

| File | Purpose |
|---|---|
| `mods/base/data/encounters.json` | Base game encounter templates (initially empty array; reference encounters added during Phase 5). |
| `systems/loaders/encounter_registry.gd` | Registry class. Validates and stores templates. Two-phase patching support. |
| `ui/screens/backends/encounter_backend.gd` | The runtime backend class with the round state machine. |
| `ui/screens/backends/encounter_screen.gd` + `.tscn` | The player-facing screen. |
| `ui/components/encounter_action_button.gd` + `.tscn` | Single action button with availability state, cost preview, tooltip. Reused for both "select action" and "review last round" displays. |
| `ui/components/encounter_log_feed.gd` + `.tscn` | Scrolling per-round log surface. |
| `systems/encounter_runtime.gd` | Stateless helper: weighted random selection, formula evaluation, encounter context normalization, and condition context construction. |
| `tests/unit/test_encounter_backend.gd` | GUT suite. |
| `tests/unit/test_encounter_runtime.gd` | GUT suite for the helper. |
| `tests/integration/test_encounter_flow.gd` | End-to-end happy-path integration. |

### 4.2 New autoload entries

None. `EncounterRegistry` is instantiated by `DataManager` like every other registry. The backend is instantiated per-screen by `UIRouter`, like every other backend.

### 4.3 New `GameEvents` signals

```gdscript
signal encounter_started(payload: Dictionary)
signal encounter_round_advanced(encounter_id: String, round: int)
signal encounter_action_resolved(payload: Dictionary)
signal encounter_resolved(payload: Dictionary)
```

Payload signals avoid the four-argument recorder ceiling in `GameEvents` and leave room for fields such as `round`, `actor`, `action_id`, `success`, `outcome_id`, and `reason` without breaking signal signatures. `actor` is `"player"` or `"opponent"`. These follow the existing taxonomy (see `docs/GAME_EVENTS_TAXONOMY.md`); a corresponding entry is added there during Phase 1.

### 4.4 `EncounterRegistry` contract

Mirror of `QuestRegistry` and `TaskRegistry`:

- `add_encounter(template: Dictionary) -> bool` — Phase 1 addition path; validates required fields; rejects duplicates.
- `patch_encounter(patch: Dictionary) -> bool` — Phase 2 patching path; standard `target` / `set` / `add_*` shape.
- `get_encounter(encounter_id: String) -> Dictionary` — returns a deep copy.
- `has_encounter(encounter_id: String) -> bool`.
- `get_all_encounters() -> Array[Dictionary]`.

`DataManager` exposes the same surface it does for other registries: `DataManager.has_encounter()`, `DataManager.get_encounter()`.

### 4.5 `EncounterBackend` contract

Registered with `BackendContractRegistry` as `EncounterBackend`. Required and optional payload fields:

```gdscript
{
    "required": ["encounter_id"],
    "optional": [
        "screen_title",
        "screen_description",
        "cancel_label",
        "player_entity_id",
        "opponent_entity_id",
        "participant_overrides",
        "next_screen_id",
        "next_screen_params",
        "pop_on_resolve",
        "failure_next_screen_id",
        "failure_next_screen_params",
        "default_sound",
    ],
    "field_types": {
        "encounter_id": TYPE_STRING,
        "player_entity_id": TYPE_STRING,
        "opponent_entity_id": TYPE_STRING,
        "participant_overrides": TYPE_DICTIONARY,
        ...
    },
}
```

Unlike `ChallengeBackend`, the bulk of the configuration lives inside the encounter template referenced by `encounter_id`, not in the payload. The payload exists to let interactions, quest stages, and dialogue handoffs target a specific encounter, override participants, and override navigation routing without rewriting the template.

### 4.6 Backend state model

The backend holds these fields between calls (this is where it differs from every existing backend):

```gdscript
var _encounter_id: String
var _template: Dictionary           # Deep copy from the registry
var _round: int = 0
var _max_rounds: int
var _encounter_stats: Dictionary    # { stat_id → float } — the local meters
var _player_tags: Dictionary        # { tag → remaining_rounds }
var _opponent_tags: Dictionary
var _log: Array[Dictionary]         # Round-by-round event entries
var _resolved_outcome_id: String = ""   # Non-empty once the encounter ends
var _last_player_action: Dictionary
var _last_opponent_action: Dictionary
```

State is in-memory only. There is no A2J registration in v1 — see section 5 for the save/load discussion.

### 4.7 Public surface (called by `encounter_screen.gd`)

| Method | Purpose |
|---|---|
| `initialize(params: Dictionary)` | Load template, resolve participants, populate `_encounter_stats`. |
| `build_view_model() -> Dictionary` | Return the dict the screen renders: portraits, real-stat bars, encounter-stat bars, available player actions (with their availability/disabled state), log feed, status. |
| `select_action(action_id: String) -> Dictionary` | Recheck availability, apply player action cost, evaluate check, apply success/failure effects, check immediate resolution, then let the opponent act if still unresolved. Returns a navigation action if the encounter resolved, otherwise `{}`. |
| `is_resolved() -> bool` | True after a resolution outcome has fired. |
| `get_resolved_outcome_id() -> String` | The fired outcome, or `""`. |
| `cancel() -> Dictionary` | Manual abort. Resolves to `cancel_outcome` if configured, otherwise pops without firing any outcome. |

### 4.8 `ConditionEvaluator` extensions

Three minimal extensions, all backward-compatible:

1. **Explicit context parameter.** `ConditionEvaluator.evaluate(conditions: Dictionary, context: Dictionary = {})` and `evaluate_any(condition_list: Array, context: Dictionary = {})` gain an optional context dictionary. Existing callers keep working with the default empty context. Internal recursive calls pass the same context through `_evaluate_logic_block()` and `_evaluate_node()`.
2. **New entity-id prefix `encounter:`.** `ConditionEvaluator._resolve_entity(entity_id, context)` recognizes `encounter:player` and `encounter:opponent` from `context["encounter_entities"]`.
3. **New typed condition `encounter_stat_check`.** Reads from `context["encounter_stats"]`. Same shape as `stat_check` minus `entity_id`: `{"type": "encounter_stat_check", "stat": "intimidation", "op": ">=", "value": 50}`.

The encounter-specific extensions are guarded so condition evaluation outside an encounter context fails closed (returns `false`) rather than crashing. This means `encounter_stat_check` referenced from an unrelated quest objective is harmless — it just never passes.

---

## 5. Encounter Lifecycle

A round is the atomic unit of encounter time. The lifecycle:

```
initialize()
  ├── Resolve participants
  ├── Populate _encounter_stats from defaults
  ├── Dispatch intro_action_payload
  ├── Emit encounter_started
  └── _round = 1

loop until resolved:
    build_view_model()  ← screen renders

    select_action(player_action_id):
      ├── Recheck availability; reject without cost if unavailable
      ├── Apply cost effects
      ├── Evaluate check
      ├── Apply on_success or on_failure effects
      ├── Emit encounter_action_resolved (player)
      ├── Evaluate resolution outcomes immediately
      │     if any matches → resolve(outcome_id), return navigation dict
      ├── Pick opponent action via opponent_strategy
      ├── Apply opponent on_success effects
      ├── Emit encounter_action_resolved (opponent)
      ├── Decrement tag durations
      ├── Increment _round
      ├── Emit encounter_round_advanced
      └── Evaluate resolution outcomes (in order):
            if any matches → resolve(outcome_id), return navigation dict
            if _round > _max_rounds → resolve(max_rounds_outcome)
            else → return {}

resolve(outcome_id):
  ├── Apply outcome.reward via RewardService
  ├── Dispatch outcome.action_payload via ActionDispatcher
  ├── Set _resolved_outcome_id
  ├── Emit encounter_resolved
  └── Return navigation dict (push next_screen_id or pop)
```

### Real-stat mutation pattern

Effects that target real stats (`modify_stat` with `target: "player"` or `target: "opponent"`) follow the established `commit_entity_instance` pattern from `ChallengeBackend._apply_success`:

```gdscript
var clone := participant.duplicate_instance()
clone.modify_stat(stat_id, computed_delta)
GameState.commit_entity_instance(clone, participant.entity_id)
```

This means: damage persists to the save the moment it lands, the player's UI in other surfaces (HUD, entity sheet) sees the change immediately, and a save-game taken mid-encounter records the partial damage correctly. The encounter-local meters do not persist; they live on the backend instance.

### Saving mid-encounter

V1 behavior:

- A save taken mid-encounter persists all real entity state (already done).
- The encounter backend itself is not serialized.
- On reload, the encounter screen is not on the stack — the player resumes wherever the gameplay shell was rooted.
- This is acceptable because real damage already persists; the lost state is the round counter and encounter-local meters, which by design are throwaway.

No automatic outcome fires during save or load. Authored abort consequences happen only through `cancel_outcome` when the player explicitly cancels from the live encounter UI.

V2+ may add an `EncounterInstance` runtime class registered with A2J for persistent encounter resumption.

---

## 6. Opponent Strategy in Detail

### Weighted random selection (v1)

```gdscript
static func pick_opponent_action(
    actions: Array,
    encounter_context: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var candidates: Array[Dictionary] = []
    var total_weight := 0.0
    for action_dict in actions:
        if action_dict is Dictionary:
            var action: Dictionary = action_dict
            if not _is_available(action, encounter_context):
                continue
            var weight := _resolve_weight(action, encounter_context)
            if weight <= 0.0:
                continue
            candidates.append(action)
            total_weight += weight
    if candidates.is_empty():
        return {}
    var roll := rng.randf() * total_weight
    var running := 0.0
    for candidate in candidates:
        running += _resolve_weight(candidate, encounter_context)
        if roll <= running:
            return candidate
    return candidates[-1]
```

`_resolve_weight` walks `weight_modifiers` and returns the weight from the first `if` block that evaluates true, falling back to base `weight`. First-match behavior is intentional: authored order stays predictable and later compatibility patches can insert more specific modifiers ahead of broad fallback modifiers.

### Why not just LimboAI from day one?

The framework already ships LimboAI and we already use it for the quest tracker. Two reasons we don't lead with it for opponent strategy:

1. Authoring overhead. A weighted-random opponent is a JSON list. A LimboAI opponent is a `.tscn` resource the modder needs to build in the Godot editor. We want encounters to be writable in pure JSON.
2. Coverage. Weighted random with conditional weights covers the vast majority of "swing-style" encounter opponents. Reaching for behavior trees is appropriate when the opponent has memory, inhibitions, or chained tactics — the v2 tier.

The strategy slot is wrapped in `{"kind": "weighted_random"}` precisely so we can add `{"kind": "behavior_tree", "tree_path": "..."}` without breaking older templates.

---

## 7. UI Surface

The screen is a single layout with five regions:

```
┌──────────────────────────────────────────────────────────┐
│  TITLE                                                    │
│  Description                                              │
├──────────────┬───────────────────────────┬───────────────┤
│              │  Encounter stat bars       │               │
│  PLAYER      │  (intimidation, etc.)      │  OPPONENT     │
│  PORTRAIT    ├───────────────────────────┤  PORTRAIT     │
│              │                            │               │
│  HP / SP     │  ROUND LOG FEED            │  HP / SP      │
│              │                            │               │
│              │                            │               │
├──────────────┴───────────────────────────┴───────────────┤
│  ACTION ROW: [Punch] [Intimidate] [Defend] [Flee]         │
│              (disabled actions show greyed with tooltip)  │
├──────────────────────────────────────────────────────────┤
│  Status line / "Press to advance" / Resolution text       │
└──────────────────────────────────────────────────────────┘
```

Layout guidelines:

- Reuse `EntityPortrait` and `StatBar` components from `ChallengeBackend` — same patterns.
- Encounter-local meters render as a smaller variant of `StatBar` styled with a distinct color token (existing theme system supports this).
- Action buttons disable themselves when `availability` is false; tooltip shows the failing condition humanized (`"Requires Stamina ≥ 5"`).
- Log feed shows the last N entries (configurable, default 6); each round contributes one player line + one opponent line + any `log` effects.
- Resolution state hides the action row and shows a single "Continue" button that runs the navigation action.

---

## 8. Reference Encounters

Three built-in encounters under `mods/base/` to exercise the schema during Phase 5:

1. **`base:tutorial_brawl`** — Combat. One opponent. Player has Punch / Intimidate / Defend / Flee. Opponent has Swing / Shove. Two outcomes: defeat opponent, or reach 100 intimidation. Used in the smoke test integration suite.
2. **`base:tutorial_negotiation`** — No real-stat damage. Two encounter-local meters (`agreement`, `frustration`). Player has Argue / Concede / Empathize / Walk Away. Opponent never deals damage; instead, opponent actions modify `frustration`. Resolution: `agreement >= 100` (success), `frustration >= 100` (failure), or 8 rounds elapsed (timeout).
3. **`base:tutorial_endurance`** — Hybrid. Real stamina drain over rounds, encounter-local "resolve" meter. Demonstrates `cost` interacting with `availability`: actions become unavailable once stamina is too low, forcing the player into specific tactical paths.

These triple as the canonical examples in `modding_guide.md` once Phase 7 ships docs.

---

## 9. Phased Implementation Plan

Each phase is shippable in isolation. Phases 1–4 deliver a working but minimal encounter system; phases 5+ add polish and depth.

### Phase 1 — Schema, Registry, Data Pipeline (~2 days)

- Create `mods/base/data/encounters.json` with empty `encounters: []` array.
- Write `systems/loaders/encounter_registry.gd` with add/patch/get/has methods.
- Wire `DataManager` to instantiate `EncounterRegistry` and load `encounters.json`.
- Add `DataManager.has_encounter()` / `get_encounter()` accessors.
- Add `encounter_started` / `encounter_round_advanced` / `encounter_action_resolved` / `encounter_resolved` signals to `GameEvents` and the catalog.
- Update `docs/GAME_EVENTS_TAXONOMY.md` with the new entries.
- Add minimum encounter validation in Phase 1, not later: required `encounter_id`, duplicate encounter ids, required participant roles, `actions` object shape, duplicate action ids per side, resolution outcome ids, `max_rounds_outcome`, and `cancel_outcome`.
- Keep encounter template validation separate from `DataManager._validate_action_fields()` because encounter templates use `actions` as a `{ "player": [], "opponent": [] }` object, not as an array of `ActionDispatcher` payloads.
- Unit tests: `EncounterRegistry` validation, addition rejection on duplicates, patch round-trip.

**Acceptance:** Empty registry loads, signals are declared, `DataManager.has_encounter()` returns false for any id. No backend yet.

### Phase 2 — `EncounterBackend` Core State Machine (~3–4 days)

- `ui/screens/backends/encounter_backend.gd` extending `OmniBackendBase`.
- Register `EncounterBackend` contract with `BackendContractRegistry`.
- Implement `initialize` (template load, participant resolution, encounter_stats default population).
- Implement `select_action` happy path: availability recheck → cost effects → check → on_success/on_failure → immediate resolution check → opponent weighted random → end-of-round → resolution check.
- Implement effect handlers for `modify_stat`, `modify_encounter_stat`, `set_encounter_stat`, `log`, `set_flag`, `resolve`. (Defer `apply_tag` / `remove_tag` to Phase 6.)
- Implement `systems/encounter_runtime.gd` weighted-random helper with injectable RNG and stat-modifier formula evaluator.
- Extend `ConditionEvaluator` with explicit optional context, the `encounter:` entity prefix, and the `encounter_stat_check` typed condition.
- Implement `RewardService` and `ActionDispatcher` calls in resolve path.
- Unit tests: `EncounterBackend` state transitions across one full round, player-action immediate resolution before opponent action, formula evaluation, weighted random distribution with a seeded `RandomNumberGenerator`, `encounter_stat_check` evaluation in and out of encounter context.

**Acceptance:** Backend can run a full encounter end-to-end programmatically (via test harness), correctly applying stat mutations, encounter meters, and outcome rewards. No screen yet.

### Phase 3 — `encounter_screen.tscn` and Action UI (~3 days)

- Build `encounter_screen.tscn` and its `.gd`. Reuse existing `EntityPortrait` and `StatBar` for participants.
- Build `encounter_action_button.gd/tscn` with availability state and tooltip rendering.
- Build `encounter_log_feed.gd/tscn` with capped history and theme-aware styling.
- Wire `select_action` to UI buttons; wire navigation result on resolve to `UIRouter`.
- Surface encounter-local meters as a styled mini-`StatBar`.
- Smoke test: launch `base:tutorial_brawl` from a debug shell and play it through.

**Acceptance:** A real, playable encounter through the UI. Cancel button works. Resolution navigation works. Audio hooks are wired (sound on action / on resolve).

### Phase 4 — Reference Encounters and Mod Surface (~2–3 days)

- Author `base:tutorial_brawl`, `base:tutorial_negotiation`, `base:tutorial_endurance` in `mods/base/data/encounters.json`.
- Add a debug entry point (gameplay shell debug menu) to launch each one.
- Wire one of them into a base-game entity interaction so launch-from-NPC works.
- Integration test: full flow from interaction → encounter → resolution → screen pop.
- First pass on `docs/modding_guide.md` section 23 (encounters) and an entry in section 15 (registered backends).

**Acceptance:** Three reference encounters playable from gameplay. Modders have enough docs to author a fourth without engine changes.

### Phase 5 — Patches, Validation, Polish (~2 days)

- Two-phase patching for encounters: `add_player_action`, `remove_player_action`, `add_outcome`, `set` for top-level fields, etc. Mirror entity patch shape.
- Expand template validation beyond the Phase 1 minimum: reject unknown `stat_id` in `encounter_stats` references, unknown outcome ids referenced by `resolve` effects, invalid participant override role keys, malformed effect entries, invalid sounds/resources where they can be checked, and unsupported strategy kinds. Validation errors surface through `ModLoader` like every other load error.
- Friendly tooltip rendering for `availability` failures (humanize the failing condition, not a raw JSON dump).
- Sound on action resolve, sound on encounter resolve.

**Acceptance:** Invalid encounter templates fail load with a useful error. Patches work. Tooltips read like English.

### Phase 6 — Tags, Multi-Effect Sequencing, Edge Cases (~2–3 days)

- Implement `apply_tag` / `remove_tag` effects with round-decremented duration.
- Implement tag-aware availability checks (a `has_tag` typed condition extension on `ConditionEvaluator`).
- Effect ordering audit: costs apply only after backend availability recheck accepts the action, then still apply if the action's later check fails. Opponent actions do not resolve if the player's action or immediate automatic resolution ends the encounter. Codify and test these rules.
- Per-outcome `screen_text` rendering on resolve before navigation.
- Cancel-mid-action safety (defer to next paint frame to avoid double-resolve).

**Acceptance:** Tag-driven setups work (defensive stance, drunk, charmed, vulnerable). Edge cases match documented rules.

### Phase 7 — Documentation and Examples (~2 days)

- Full `modding_guide.md` section: top-level shape, every field, every effect, two complete example encounters with annotation.
- Cookbook entries: "How do I make an opponent that gets more aggressive when low on health" (`weight_modifiers`); "How do I make a non-combat encounter" (the negotiation reference); "How do I add a flee option" (`resolve` effect, manual outcome).
- Update `docs/SYSTEM_CATALOG.md` with `EncounterRegistry` and `EncounterBackend`.
- Update `docs/PROJECT_STRUCTURE.md` with the new files.

**Acceptance:** A modder can author a working encounter using only the docs.

### Phase 8 — Advanced Strategies (deferred)

- `scripted` opponent strategy.
- `behavior_tree` opponent strategy bound to a LimboAI tree on the opponent entity.
- `ai_persona` opponent strategy querying `AIManager` for action selection with weighted-random fallback.
- A2J-registered `EncounterInstance` for save/load mid-encounter.
- Multi-participant encounters (party combat, multi-NPC negotiation) — requires participant role schema rework.
- AI-generated round narration via `AITemplateRegistry` (analogous to existing world-gen hooks).

These ship when there is concrete demand. Don't pre-build them.

---

## 10. Testing and Verification

### 10.1 Unit Tests (GUT)

- `test_encounter_registry.gd` — addition, duplicate rejection, patch application, type validation.
- `test_encounter_runtime.gd` — weighted random distribution with injected seeded RNG, first-match weight modifiers, formula evaluation with edge cases (zero stats, negative modifiers, empty `stat_modifiers` dict).
- `test_encounter_backend.gd` — state transitions, no cost when availability fails, cost-spent-on-check-failure, real-stat commit pattern, encounter-stat clamping, immediate player-action resolution, resolution priority.
- `test_condition_evaluator_encounter.gd` — `encounter:player` resolution, `encounter_stat_check` in and out of encounter context.

### 10.2 Integration Tests

- `test_encounter_flow.gd` — end-to-end: open backend, play three rounds with deterministic action sequence, verify outcome fired, verify reward applied, verify navigation returned.
- `test_encounter_persistence.gd` — confirm real stat mutations persist through `SaveManager` round-trip mid-encounter.

### 10.3 Smoke Tests

Manual checklist Phase 4 onward:

- Launch each reference encounter from the debug menu and play it to each documented outcome at least once.
- Confirm portrait, stat bars, encounter meters, log feed, and resolution all render correctly.
- Confirm sounds fire on action and resolution.
- Confirm cancel button cleanly aborts.

### 10.4 Debug Surfaces

- ImGui overlay panel listing the active encounter's `_round`, `_encounter_stats`, `_player_tags`, `_opponent_tags`, `_log` — toggleable from the existing dev overlay.
- Debug action: "force resolve to outcome…" dropdown for QA.

---

## 11. Modder Surface Summary

After Phase 7, a modder building a new encounter writes:

1. One block in `encounters.json` defining the template.
2. Optionally, a new entry in an entity's `interactions` list with `backend_class: "EncounterBackend"` and `backend_config: { "encounter_id": "...", "opponent_entity_id": "entity:..." }` to launch it from the world.

That's the entire surface. No GDScript. No scenes. No registry boilerplate. Same authoring overhead as a quest or task.

---

## 12. Resolved Design Decisions

1. **`weight_modifiers` use first-match behavior.** Authored order is easier for modders to reason about, and compatibility patches can insert narrow rules before broad rules.
2. **`ConditionEvaluator` receives explicit context.** No thread-local/static encounter context. `evaluate()` and `evaluate_any()` gain optional context parameters and recursive evaluation threads that context through.
3. **Costs are encounter effects, not raw dispatcher actions.** Availability is rechecked inside `select_action()`; unavailable actions are rejected without cost. Accepted actions pay cost before the check, even when the check fails.
4. **Fractions stay as floats internally.** `EntityInstance.stats` already support float values. UI presentation may round to one decimal where needed.
5. **Cancel uses explicit `cancel_outcome` only.** If an encounter declares `cancel_outcome`, cancel resolves through that manual outcome. Otherwise cancel pops without outcome rewards/actions. Saving/loading never fires an abort outcome.
6. **Encounter stat names may overlap real stat names with a warning.** Namespaces keep behavior unambiguous; load validation should warn, not reject, if an encounter-local stat shares a known real stat id.
7. **Opponent intent is out of scope for v1.** The player sees opponent actions only after they resolve in the log. A future `show_intent` field can add preview behavior without changing v1 templates.

---

## 13. Out of Scope (and intentionally so)

- Real-time encounters. The system is turn-based; there is no time-pressure UI.
- Grid/tactical positioning. No movement, no range, no line-of-sight.
- Loot tables on opponents. Outcomes hand out fixed rewards; randomized loot is a future system, not an encounter responsibility.
- Combo / chain / cooldown mechanics. Achievable via tags + availability conditions in v2; no first-class support in v1.
- Cross-encounter persistent debuffs. Real stat changes persist via the existing entity model. Tags are encounter-local.
- Network or multiplayer encounters. Engine is single-player.
- Visual novel-style branching dialogue inside encounters. Use `DialogueBackend` before/after; encounters are mechanical.

These are all reasonable additions; none belong in a v1 of this system.
