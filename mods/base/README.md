# Vanguard University Base Mod

This is the minimal playable base game for Omni-Framework.

The base mod is intentionally small. It demonstrates how to build a real game loop with existing data systems before addon mods expand the content.

## What This Teaches

- `definitions.json`: stat groups, resource/capacity pairs, and a single money currency.
- `parts.json`: body sockets, transformation parts, custom fields, equippable keepsakes, consumable items, and inventory components.
- `entities.json`: player setup, inventory instances, socket maps, NPCs, containers, vendor stock, and entity interactions.
- `locations.json`: location graph, map positions, location screens, entity presence, and backend payload examples.
- `activities.json`: scheduled activities, repeat rules, requirements, weighted outcomes, stat changes, reputation, currency, item rewards, and event records.
- `quests.json`: activity-history objectives, stat objectives, location objectives, rewards, and repeatable flags.
- `factions.json`: reputation thresholds, territories, rosters, and quest pools.
- `recipes.json`: crafting inputs, stations, required stats, instant recipes, and timed recipes.
- `status_effects.json`: buffs, debuffs, stack modes, and condition-gated effects.
- `config.json`: game identity, time buttons, stat group display, activity labels, theme colors, lifecycle rules, and AI toggles.

## Core Loop

1. Start in `base:dorm_room`.
2. Review your student record.
3. Prepare or use the ritual circle to change owned body parts.
4. Attend lecture, study, work, socialize, or recover through activities.
5. Earn cash, course progress, ritual chalk, stress, and reputation.
6. Sleep to restore mana and let the day settle.

## How The Loop Works

The player starts with five equipped body sockets: `cognitive`, `sensory`, `manipulator`, `locomotion`, and `framework`. The dorm ritual circle is the only base location that opens `AssemblyEditorBackend`, so body choices are made at home before travelling to scheduled activities. The starter identity is intentionally neutral; presentation options should be handled as player-facing choice, not as statted transformation parts.

Activities are the main day-spending surface. `base:attend_arcana_lecture`, `base:study_at_library`, `base:warehouse_shift`, and `base:student_mixer` use stat-gated outcomes so different bodies produce different rewards and stress pressure. `base:prepare_ritual_circle` spends mana and ritual chalk through normal activity actions, while `base:sleep_in_dorm` restores mana, reduces stress, clears the ritual-prepared flag, and records the day-end event.

The first quest spine is intentionally compact: `base:orientation` teaches travel, lecture, and sleep; `base:first_assignment` teaches course progress plus study; and `base:tuition_pressure` teaches cash pressure and physical work. Addons should extend these patterns with additions and patches.

## Design Boundaries

- This base game uses no combat and no `health` stat.
- Pressure comes from `mana`, `stress`, cash, and `arcana_101_grade`.
- Ritual components are inventory parts, not currencies.
- The current ritual circle uses existing `AssemblyEditorBackend` behavior. Mana and ritual chalk are demonstrated through preparation activities and surrounding loops rather than custom assembly-cost engine code.
- Addon mods should expand content through additions and patches instead of replacing the base loop.

## Addon Direction

Suggested tutorial/content addon order:

1. `mods/omni/primal_lineage/`
2. `mods/omni/course_arcana_101/`
3. `mods/omni/occult_market/`
4. `mods/omni/fae_lineage/`
5. `mods/omni/nightlife/`
