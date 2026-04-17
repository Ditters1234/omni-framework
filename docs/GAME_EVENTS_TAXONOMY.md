# Omni-Framework GameEvents Taxonomy

This document defines how `GameEvents` should be organized, named, and used as the engine grows. It complements the signal-bus role described in `docs/PROJECT_STRUCTURE.md`.

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

The event surface should stay grouped by domain.

### Boot And Mod Loading

- `mod_loaded(mod_id)`
- `all_mods_loaded()`
- `mod_load_error(mod_id, message)`
- `data_validation_failed(mod_id, file_path, issue_count)`

### Time

- `tick_advanced(tick)`
- `day_advanced(day)`

### Game State

- `game_started()`
- `game_paused()`
- `game_resumed()`
- `game_over()`
- `location_changed(old_id, new_id)`
- `entity_stat_changed(entity_id, stat_id, old_value, new_value)`
- `flag_changed(entity_id, flag_id, value)`

### Inventory And Assembly

- `part_acquired(entity_id, part_id)`
- `part_removed(entity_id, part_id)`
- `part_equipped(entity_id, part_id, slot)`
- `part_unequipped(entity_id, part_id, slot)`

### Economy

- `entity_currency_changed(entity_id, currency_id, old_amount, new_amount)`
- `transaction_completed(buyer_id, seller_id, part_id, price)`

### Quests And Tasks

- `quest_started(quest_id)`
- `quest_stage_advanced(quest_id, stage_index)`
- `quest_completed(quest_id)`
- `quest_failed(quest_id)`
- `task_started(task_id, entity_id)`
- `task_completed(task_id, entity_id)`

### Achievements

- `achievement_unlocked(achievement_id)`

### UI

- `ui_screen_pushed(screen_id)`
- `ui_screen_popped(screen_id)`
- `ui_notification_requested(message, level)`

### AI

- `ai_response_received(context_id, response)`
- `ai_token_received(context_id, token)`
- `ai_error(context_id, error)`

Current implementation note:

- `ai_token_received` is part of the public event surface now, even though some providers currently fall back to whole-response delivery instead of true token streaming.

### Save And Load

- `save_started(slot)`
- `save_completed(slot)`
- `load_started(slot)`
- `load_completed(slot)`
- `save_failed(slot, reason)`
- `load_failed(slot, reason)`

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

## Debugging Recommendations

The eventual debug overlay should support:

- Filtering by event domain
- Filtering by entity ID or quest ID
- Time-ordered event history
- Highlighting errors and warnings
- Clicking through to the originating system

## Suggested Near-Term Cleanup

Based on the current docs direction, these are worth standardizing early:

- Prefer `entity_currency_changed` over a global `currency_changed` when the owner matters.
- Prefer `ui_screen_pushed` / `ui_screen_popped` over ambiguous UI names.
- Add `quest_stage_advanced` explicitly since quest progression is a first-class system.
- Add validation-related events only if the engine will surface them in tools or logs.
