# Gameplay TODO

Current high-value gameplay gaps identified from the implemented systems:

- **Owned entities and assignment UI**: first-class pass implemented. Roster filtering, generic sorting, data-configured summary stats, and queued assignment dispatch are in place for larger rosters. Follow-up polish should add richer queue editing/reordering tools if larger owned-entity content needs them.
- **Direct task assignment workflows**: assignment flow implemented. Owned-entity contract assignment can now accept a quest and auto-dispatch the entity through each assignee reach-location stage as the quest advances.
- **Inventory action polish**: direct equip from the character menu is implemented through data-derived socket/tag compatibility. Continue expanding item actions beyond use/equip/discard toward compare, favorite/lock, and stack splitting if stack semantics become first-class.
- **Status effects**: first-class data-driven timed effects are implemented with stat modifiers, tick/expire actions, stacking modes, dispatcher actions, save/load persistence, and entity sheet visibility. Follow-up polish should add condition checks when content needs them.
- **Rest/recovery actions**: first pass implemented through data-authored time buttons, task completion actions, and status effects. Follow-up polish should add location-specific rest/clinic/repair affordances as normal entity/location interactions once content needs them.
- **World objects**: do not add a separate engine primitive unless a future need proves entities cannot cover it. Containers, terminals, doors, harvest nodes, loot piles, switches, and traps should be modeled through the existing entity + interaction/backend/action systems first.
- **Loot review flows**: first pass implemented through `LootBackend`. Containers and loot piles are normal entities with inventory/currencies; the backend supports selected transfer, take-all, optional currency pickup, entity-validated source/destination routing, auto-pop on depletion, and gameplay-surface hiding for empty caches. Follow-up polish should add richer reward-review entry points from encounters/quests if those flows need a dedicated post-resolution screen instead of notifications.
- **Incapacitation/death lifecycle**: formalize what happens when an entity reaches zero health or another failure threshold.
- **Save/load risk UX**: add autosave notices, dangerous-action save prompts, and clearer mod/content mismatch recovery.
- **Autonomous activity visibility**: surface what NPCs and owned entities are currently doing, where they are, and when their jobs will finish.

Immediate implementation focus: richer autonomous activity visibility, save/load risk UX, or incapacitation/death lifecycle depending on which gameplay loop needs pressure next.
