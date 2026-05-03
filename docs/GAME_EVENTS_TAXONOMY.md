# Omni-Framework GameEvents Taxonomy

> **See also:** [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for the signal-bus architecture, [`DEBUGGING_AND_TESTING_GUIDELINES.md`](DEBUGGING_AND_TESTING_GUIDELINES.md) for inspecting events at runtime, and [`modding_guide.md`](modding_guide.md) for script hooks that respond to events.

This document defines how `GameEvents` should be organized, named, and used as the engine grows. It complements the signal-bus role described in `PROJECT_STRUCTURE.md`.

## Purpose

`GameEvents` is the cross-system communication spine of the engine. If signal naming drifts or signal meaning stays vague, debugging and tooling get expensive quickly.

This taxonomy exists to keep events:

- Specific
- Observable
- Stable
- Easy to filter in logs and debug tools

## Event Design Rules

- Prefer explicit domain events over generic catch-all signals.
- A signal name should describe one thing that happened, not a whole workflow.
- Emit events for meaningful state transitions, not for every internal helper call.
- Event payloads should be small, typed, and stable.
- If a consumer must parse free-form strings to use an event, the event is underspecified.
- Keep one canonical signal catalog in `autoloads/game_events.gd` so declared signals, domains, deprecations, and debug metadata cannot drift apart.

## Naming Pattern

Use `snake_case` signal names with a domain-first pattern:

```text
<domain>_<subject>_<action>
```

Examples:

- `entity_stat_changed`
- `entity_currency_changed`
- `quest_stage_advanced`
- `ui_screen_pushed`
- `save_completed`

Avoid names like:

- `changed`
- `updated`
- `data_modified`
- `event_fired`

## Domain Groups

The event surface should stay grouped by domain. The authoritative catalog lives in `autoloads/game_events.gd` under `SIGNAL_CATALOG`.

### Boot And Mod Loading

- `mod_loaded(mod_id)` after the loader finishes both JSON phases and script-hook preloading for the current boot
- `all_mods_loaded()`
- `mod_load_error(mod_id, message)`

Note: `data_validation_failed` is described in earlier planning docs but is not currently declared in the signal catalog. Use `mod_load_error` for validation issues until that signal is added.

### Time

- `tick_advanced(tick)`
- `day_advanced(day)`

### Game State

- `game_started()`
- `game_paused()`
- `game_resumed()`
- `game_over()`
- `location_changed(old_id, new_id)`
- `player_stat_changed(stat_key, old_value, new_value)` — convenience signal for the player entity specifically
- `entity_stat_changed(entity_id, stat_key, old_value, new_value)` — preferred general form
- `entity_reputation_changed(entity_id, faction_id, old_value, new_value)`
- `flag_changed(entity_id, flag_id, value)`

### Inventory And Assembly

- `part_acquired(entity_id, part_id)`
- `part_removed(entity_id, part_id)`
- `part_equipped(entity_id, part_id, slot)`
- `part_unequipped(entity_id, part_id, slot)`
- `part_custom_value_changed(entity_id, part_id, field_id, value)`

### Economy

- `entity_currency_changed(entity_id, currency_key, old_amount, new_amount)` — preferred form
- `transaction_completed(buyer_id, seller_id, part_id, price)`
- ~~`currency_changed(currency_key, old_amount, new_amount)`~~ — **deprecated**, use `entity_currency_changed`

### Quests And Tasks

- `quest_started(quest_id)`
- `quest_stage_advanced(quest_id, stage_index)`
- `quest_completed(quest_id)`
- `quest_failed(quest_id)`
- `task_started(task_id, entity_id)`
- `task_completed(task_id, entity_id)`
- `dialogue_started(entity_id, dialogue_resource)`
- `dialogue_ended(entity_id, dialogue_resource)`

### Encounters

- `encounter_started(payload)` when an encounter backend initializes with resolved participants
- `encounter_round_advanced(encounter_id, round)` after a full unresolved round advances
- `encounter_action_resolved(payload)` after a player or opponent action applies its success/failure effects
- `encounter_resolved(payload)` when an outcome fires through automatic resolution, a manual resolve effect, max rounds, or cancel

Encounter payload dictionaries include stable primitive fields such as `encounter_id`, `round`, `actor`, `action_id`, `success`, `outcome_id`, and `reason` depending on the signal.

### Achievements

- `achievement_unlocked(achievement_id, unlock_vfx)`

### UI

- `ui_screen_pushed(screen_id)` — preferred form
- `ui_screen_popped(screen_id)` — preferred form
- `ui_notification_requested(message, level)` — preferred form
- ~~`screen_pushed(screen_id)`~~ — **deprecated**, use `ui_screen_pushed`
- ~~`screen_popped(screen_id)`~~ — **deprecated**, use `ui_screen_popped`
- ~~`notification_requested(message, level)`~~ — **deprecated**, use `ui_notification_requested`

New consumers should use the `ui_`-prefixed forms. Deprecated signals remain declared for backwards compatibility but should not be referenced in new code.

### AI

- `ai_response_received(context_id, response)`
- `ai_token_received(context_id, token)`
- `ai_error(context_id, error)`

`ai_token_received` is part of the public event surface. Some providers fall back to whole-response delivery instead of true token streaming; consumers should handle both.

### Save And Load

- `save_started(slot)`
- `save_completed(slot)`
- `load_started(slot)`
- `load_completed(slot)`
- `save_failed(slot, reason)`
- `load_failed(slot, reason)`

## Event History

`GameEvents` maintains a bounded in-memory event history (max 200 entries) in `_event_history`. Debug surfaces and test assertions should read from this shared history. Do not build separate partial event logs in individual systems.

## When To Add A New Event

Add a new event when:

- Another system genuinely needs to react to the transition.
- The transition matters for debugging or analytics.
- The transition is stable enough to become part of your engine surface.

Do not add a new event when:

- The information is purely internal to one class.
- It duplicates a clearer existing event.
- It exists only to avoid a normal function call within one subsystem.

## Payload Rules

- Prefer IDs and primitive values over whole dictionaries.
- Include both old and new values when the transition matters.
- Avoid sending mutable template dictionaries through events.
- Runtime instances may be referenced indirectly by ID instead of passed whole.

## Stability Rules

- Once gameplay or UI depends on an event, treat its name and payload as a public contract.
- If an event must change, deprecate it intentionally and document the replacement.
- Do not reuse an old event name for a new meaning.
- Deprecated signals remain declared in `game_events.gd` until all internal consumers are migrated. Mark them with `"deprecated": true` in `SIGNAL_CATALOG`.
