# Gameplay TODO

Current status: the high-value gameplay todo list is complete for the present data-driven foundation. Keep this file as the lightweight audit trail for gameplay gaps found through playtesting, not as a speculative roadmap.

## Completed Foundation

- **Owned entities and assignment UI**: first-class pass implemented. Roster filtering, generic sorting, data-configured summary stats, queued assignment dispatch, visible task rows, queue reordering, and task cancellation are in place for larger rosters.
- **Direct task assignment workflows**: assignment flow implemented. Owned-entity contract assignment can accept a quest and auto-dispatch the entity through each assignee reach-location stage as the quest advances.
- **Inventory action polish**: direct equip from the character menu is implemented through data-derived socket/tag compatibility. The character menu also supports data-authored use actions, discard, per-instance favorite flags, and per-instance lock flags that protect items from consume/discard flows.
- **Status effects**: first-class data-driven timed effects are implemented with stat modifiers, conditional apply/tick/expire checks, tick/expire actions, stacking modes, dispatcher actions, save/load persistence, and entity sheet visibility.
- **Rest/recovery actions**: first-class pass implemented through data-authored time buttons, task completion actions, status effects, and location/entity interactions. Base content includes a clinic-style recovery affordance that applies a conditional status effect, and total conversions can replace the stats/effects without engine changes.
- **Loot/reward review flows**: first-class pass implemented through `LootBackend` and `RewardReviewBackend`. Containers and loot piles are normal entities with inventory/currencies; `LootBackend` supports selected transfer, take-all, optional currency pickup, entity-validated source/destination routing, auto-pop on depletion, and gameplay-surface hiding for empty caches. `RewardReviewBackend` reads generic runtime completion history from quests/encounters so players can review reward summaries after notifications clear.
- **Incapacitation/death lifecycle**: first-class pass implemented through data-authored `entity_lifecycle.rules`. Rules evaluate normal `ConditionEvaluator` blocks against any live entity, set configurable state flags, dispatch normal actions, emit lifecycle events, and show notifications. Base content maps `health <= 0` to `base:incapacitated`; total conversions can replace that with any stat or condition.
- **Save/load risk UX**: first-class pass implemented. Save slots expose diagnostics for incompatible/corrupt save files instead of treating them as empty, manual overwrite requires a confirmation click, and save/autosave/load operations surface UI notifications.
- **Autonomous activity visibility**: first-class pass implemented. Shared task activity summaries surface active/queued work, destination labels, and remaining ticks in owned-entity management and present-entity location rows. Owned-entity detail views can reorder queued work and cancel active or queued tasks through generic runtime task controls.

## Explicit Deferrals

- **World objects**: do not add a separate engine primitive unless a future need proves entities cannot cover it. Containers, terminals, doors, harvest nodes, loot piles, switches, and traps should be modeled through the existing entity + interaction/backend/action systems first.
- **Inventory stack splitting**: deferred until stack semantics become a first-class runtime concept. Current inventory uses distinct `PartInstance` objects grouped for display, so splitting a display group would be cosmetic rather than a real model operation.
- **Owned-entity bulk operations or priority presets**: deferred until larger owned-entity content proves they are needed. The current generic queue controls cover single-entity assignment, reorder, and cancellation without introducing fixed job categories.
- **Save repair flows**: deferred until a future migration can recover specific missing references. Current diagnostics are intentionally honest: they explain why a slot cannot load instead of pretending it is empty or repairable.

## Next Intake Rule

Add new items here only when playtesting exposes a concrete missing loop or a modding use case that cannot be expressed through existing data, entities, actions, tasks, quests, status effects, encounters, or backend payloads.
