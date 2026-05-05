# Gameplay TODO

Current high-value gameplay gaps identified from the implemented systems:

- **Owned entities and assignment UI**: first-class pass implemented. Roster filtering, generic sorting, data-configured summary stats, and queued assignment dispatch are in place for larger rosters. Follow-up polish should add richer queue editing/reordering tools if larger owned-entity content needs them.
- **Direct task assignment workflows**: assignment flow implemented. Owned-entity contract assignment can now accept a quest and auto-dispatch the entity through each assignee reach-location stage as the quest advances.
- **Inventory action polish**: direct equip from the character menu is implemented through data-derived socket/tag compatibility. Continue expanding item actions beyond use/equip/discard toward compare, favorite/lock, and stack splitting if stack semantics become first-class.
- **Status effects**: first-class data-driven timed effects are implemented with stat modifiers, tick/expire actions, stacking modes, dispatcher actions, and save/load persistence. Follow-up polish should add richer UI surfacing and condition checks when content needs them.
- **Rest/recovery actions**: provide generic time-cost recovery loops for sleeping, resting, repair bays, clinics, or waiting until a resource recovers.
- **World objects**: add a data-driven interaction layer for containers, terminals, doors, harvest nodes, loot piles, switches, and traps without forcing each object to be a full NPC-style entity.
- **Loot review flows**: add a dedicated loot/container backend for take-all, selective transfer, and reward review outside quests and encounters.
- **Incapacitation/death lifecycle**: formalize what happens when an entity reaches zero health or another failure threshold.
- **Save/load risk UX**: add autosave notices, dangerous-action save prompts, and clearer mod/content mismatch recovery.
- **Autonomous activity visibility**: surface what NPCs and owned entities are currently doing, where they are, and when their jobs will finish.

Immediate implementation focus: rest/recovery actions, status-effect UI surfacing, or world objects depending on which gameplay loop needs pressure next.
