# Vanguard University Implementation Guide

Purpose:
Build Vanguard University as a minimal playable base game, then expand it through addon mods that are both real game content and tutorial examples for future modders.

This guide assumes the existing starter base data can be deleted and rebuilt from scratch. Use old files only as schema references while authoring new content.

Current status:

- Phase 0 preflight is complete.
- A first data-only pass of Phases 1-4 exists in `mods/base/`.
- Phase 5 documentation is underway: the base README now explains the playable loop. Automated tests intentionally avoid asserting against live mod data while Vanguard content is still changing quickly.
- Addon Phase A has a first data-only slice in `mods/omni/primal_lineage/`: new primal parts, Industrial Ward activities, an addon achievement, and README guidance.
- Addon Phase B has a first data-only slice in `mods/omni/fae_lineage/`: social/perceptive fae parts, Student Union activities, Lark NPC dialogue, a stat-gated relationship challenge, local placeholder assets, and README guidance. Dialogue Manager stat/flag helpers are not exposed yet, so conditional gating currently lives in JSON conditions.
- Addon Phase C has a first data-only slice in `mods/omni/course_arcana_101/`: a TA NPC, scheduled seminar/study/practical activities, a short assignment quest chain, local placeholder assets, and README guidance.
- Addon Phase D has a first data-only slice in `mods/omni/occult_market/`: a component vendor, ritual components, market recipes, a recipe unlock activity/item, High Street screen patches, local placeholder assets, and README guidance.
- Addon Phase E has a first data-only slice in `mods/omni/nightlife/`: a Nightlife District location, High Street connection patch, late-night recovery/social/work activities, temporary status effects, an NPC challenge, an addon achievement, local placeholder assets, and README guidance.
- Required images and sounds are listed in `docs/TODO/VANGUARD_ASSET_REQUIREMENTS.md`.
- Legacy `mods/example/*` packs are disabled because they target the previous starter base.
- Remaining work is validation in Godot, asset creation/import, tuning, and addon implementation.

-----------
Implementation Principles

- Keep `mods/base/` small, complete, and readable.
- Put expansion content in separate mods under `mods/omni/<mod_id>/`.
- Each addon should teach one primary modding pattern.
- Prefer data additions and patches over engine changes.
- Add engine code only when a real missing capability blocks multiple content goals.
- Keep every phase playable before moving to the next phase.
- Update docs as content patterns stabilize.

-----------
Target Content Structure

Base mod:

`mods/base/`

- Minimal playable Vanguard University core loop.
- Defines the canonical stat, currency, socket, time, and location foundations.
- Includes a tiny transformation set and one playable day/week loop.
- Must remain playable with all addon mods disabled.

Addon mod examples:

- `mods/omni/primal_lineage/`
- `mods/omni/fae_lineage/`
- `mods/omni/course_arcana_101/`
- `mods/omni/occult_market/`
- `mods/omni/nightlife/`

Every addon should include:

- `mod.json`
- `README.md`
- `data/` files with additions or patches
- Optional `dialogue/`, `scripts/`, and `assets/`
- A short "What this teaches" section in its README

-----------
Base Game Design Lock

Core loop:

1. Wake in the dorm.
2. Review the day and current body configuration.
3. Use the ritual circle if spending mana/components is worth it.
4. Choose one or two scheduled activities.
5. Gain or lose cash, course progress, stress, reputation, knowledge, or components.
6. Sleep to restore mana and lock in day-end consequences.

Core stats:

- Physical: `strength`, `dexterity`, `endurance`
- Mental: `intelligence`, `willpower`, `perception`
- Social: `charisma`, `intimidation`, `normalcy`
- Resources: `mana` + `mana_max`, `stress` + `stress_max`

Base progress/currencies:

- `cash`
- ritual components as inventory parts/items, not currencies
- one course-specific grade/progress value for the starter course

Base sockets:

- `cognitive`
- `sensory`
- `manipulator`
- `locomotion`
- `framework`

Base locations:

- `base:dorm_room`
- `base:dorm_common_area`
- `base:lecture_hall`
- `base:library`
- `base:student_union`
- `base:industrial_ward`
- `base:high_street`

Optional in base only if the first loop needs it:

- `base:nightlife_district`

-----------
Phase 0 - Preflight - Complete

Goal:
Confirm the base game can be rebuilt cleanly without needing engine architecture work first.

Tasks:

- Review `docs/modding_guide.md` sections for definitions, parts, entities, locations, activities, config, quests, exchanges, and assembly editor payloads.
- Snapshot current base content if desired outside the active data files.
- Decide exact ids for starter course progress and ritual component. Complete: `arcana_101_grade` and `base:ritual_chalk`.
- Define the first ritual component parts/items and their tags. Complete: `base:ritual_chalk` should use `ritual_component` and `ritual_basic`.
- Decide whether `health` remains in base or waits for encounter-heavy addons. Complete: defer `health` until injury/death pressure is needed.

Definition of done:

- The content id vocabulary is settled enough to author JSON.
- No required v1 feature depends on a new engine system.

-----------
Phase 1 - Fresh Base Skeleton

Goal:
Boot a new Vanguard University base mod with no legacy Neon Threshold content.

Files:

- `mods/base/mod.json`
- `mods/base/README.md`
- `mods/base/data/definitions.json`
- `mods/base/data/config.json`
- `mods/base/data/entities.json`
- `mods/base/data/locations.json`
- `mods/base/data/parts.json`
- Empty or minimal placeholder data files for other registries required by the loader.

Tasks:

- Replace base identity with Vanguard University.
- Define stats, resources, currencies, and UI stat groups.
- Define `base:player` with the five body sockets.
- Define dorm, campus, and city starter locations.
- Define a tiny starter inventory.
- Configure new game to enter the gameplay shell or starter assembly flow.
- Remove references to old starter ids from config, quests, tasks, locations, entities, and assets.

Definition of done:

- New game boots.
- Player starts in `base:dorm_room`.
- Gameplay shell displays player stats and location.
- No data validation errors reference old base ids.

-----------
Phase 2 - Ritual Circle And Body Loadout

Goal:
Make body configuration the first meaningful interaction.

Files:

- `mods/base/data/parts.json`
- `mods/base/data/entities.json`
- `mods/base/data/locations.json`
- `mods/base/data/config.json`

Tasks:

- Add one human baseline part for each socket.
- Add one small alternate set, preferably primal or fae, but not both unless needed.
- Give each part clear stat tradeoffs.
- Add ritual component and mana costs to the assembly flow where current backend contracts allow it.
- Add a dorm interaction that opens `AssemblyEditorBackend`.
- Ensure outside locations do not expose body editing.

Definition of done:

- Player can enter the ritual circle from the dorm.
- Player can change at least one body slot.
- Stat deltas clearly communicate the tradeoff.
- The body choice affects at least one activity or challenge.

Risk note:
If `AssemblyEditorBackend` cannot currently charge both mana and components cleanly, keep v1 cost simple and document the missing capability before adding engine code.

-----------
Phase 3 - Minimal Daily Activity Loop

Goal:
Create a small playable day with scheduled pressures.

Files:

- `mods/base/data/activities.json`
- `mods/base/data/locations.json`
- `mods/base/data/config.json`
- `mods/base/data/status_effects.json`
- `mods/base/data/tasks.json` if sleep/rest uses task completion actions.

Starter activities:

- Attend Intro Lecture
- Study at Library
- Warehouse Shift
- Student Mixer
- Sleep

Tasks:

- Add activity board interactions to relevant locations.
- Add schedule windows for class, work, and sleep.
- Add outcomes that check stats and apply rewards/consequences.
- Make sleep restore mana and lock in day-end consequences.
- Add stress increase/reduction through normal actions or status effects.

Definition of done:

- A player can spend a day.
- Body choices change at least two activity outcomes.
- Sleep advances the loop and restores mana.
- The player can see meaningful progress or consequences after one day.

-----------
Phase 4 - First Quest Spine

Goal:
Give the minimal loop a player-facing structure.

Files:

- `mods/base/data/quests.json`
- `mods/base/data/activities.json`
- `mods/base/data/entities.json`
- Optional `mods/base/dialogue/`

Starter quests:

- Orientation
- First Assignment
- Tuition Pressure

Tasks:

- Add a guide NPC in the dorm common area.
- Add an intro professor or TA.
- Add objectives for travel, ritual use, activity completion, and day-end follow-up.
- Use activity-history objectives where possible.
- Add rewards that teach cash, components, course progress, or part unlocks.

Definition of done:

- Player has a clear first objective.
- Completing the first day advances at least one quest.
- Failing or underperforming an activity still produces a coherent result.

-----------
Phase 5 - Base Documentation And Tests

Goal:
Make the base game useful as a modding reference, not just playable content.

Files:

- `mods/base/README.md`
- `docs/TODO/PLANNING_STAGE_NEW_BASE_GAME`

Tasks:

- Document what each base data file demonstrates.
- Add a compact "how this base loop works" section to `mods/base/README.md`.
- Verify no base doc describes old Neon Threshold content.

Definition of done:

- A future modder can inspect the base pack and understand the loop.
- Automated framework tests avoid live mod data while Vanguard content is still changing quickly.
- Base remains small enough to read in one sitting.

-----------
Addon Phase A - Primal Lineage

Goal:
Teach body-part expansion and physical tradeoffs.

Mod:
`mods/omni/primal_lineage/`

Teaches:

- Adding new parts
- Required tags and socket compatibility
- Part stat modifiers
- Activity outcome branches based on stats/tags

Content:

- Primal cognitive, manipulator, locomotion, and framework parts.
- Physical job variants in the Industrial Ward.
- Intimidation/social consequences.
- One quest or achievement for completing a day in a mostly primal body.

Definition of done:

- Mod can be enabled independently on top of base.
- Player gains new viable physical builds.
- README points to the exact files that demonstrate the pattern.

-----------
Addon Phase B - Fae Lineage

Goal:
Teach social tradeoffs, normalcy checks, and dialogue branching.

Mod:
`mods/omni/fae_lineage/`

Teaches:

- Adding a second transformation lineage
- Dialogue conditions
- Reputation or relationship flags
- Normalcy as a social stat

Content:

- Fae sensory, cognitive, and framework parts.
- Student Union social activity branches.
- One NPC relationship path.
- One dialogue file with stat/flag-gated branches.

Definition of done:

- Fae parts create strong social/perceptive builds with normalcy costs.
- Social content reacts to normalcy and charisma.
- README explains how to add conditional dialogue/activity outcomes.

-----------
Addon Phase C - Arcana 101 Course

Goal:
Teach course-specific progress and quest chains.

Mod:
`mods/omni/course_arcana_101/`

Teaches:

- Course-specific grade/progress ids
- Scheduled activities
- Quest stages and activity-history objectives
- Professor/TA NPC interactions

Content:

- Arcana 101 lecture/study/exam activities.
- A professor or TA.
- A short assignment quest chain.
- Rewards that unlock study knowledge or blueprint access.

Definition of done:

- Course progress is separate from base/global progress.
- A modder can copy this pattern to add another course.

-----------
Addon Phase D - Occult Market

Goal:
Teach economy, components, recipes, and unlocks.

Mod:
`mods/omni/occult_market/`

Teaches:

- Vendors and exchange screens
- Ritual components
- Crafting recipes
- Unlocking parts through study, purchases, or quests

Content:

- Occult shopkeeper.
- Component catalog.
- Simple recipe chain.
- One blueprint unlock path.

Definition of done:

- Player can acquire transformation support materials through multiple data-authored paths.
- README separates buying, crafting, and quest reward examples.

-----------
Addon Phase E - Nightlife

Goal:
Teach late-day schedules, stress relief, and consequence-heavy social content.

Mod:
`mods/omni/nightlife/`

Teaches:

- Time-gated activities
- Stress recovery
- Reputation consequences
- Risk/reward activity outcomes

Content:

- Nightlife District location.
- Decompression activities.
- Social encounters with cash/stress/reputation tradeoffs.
- Optional status effects for tiredness or inspiration.

Definition of done:

- Night activities provide meaningful alternatives to sleep/study/work.
- Stress becomes more than a passive penalty.

-----------
Recommended Work Order

1. Phase 0: Preflight.
2. Phase 1: Fresh Base Skeleton.
3. Phase 2: Ritual Circle And Body Loadout.
4. Phase 3: Minimal Daily Activity Loop.
5. Phase 4: First Quest Spine.
6. Phase 5: Base Documentation And Tests.
7. Addon Phase A: Primal Lineage.
8. Addon Phase C: Arcana 101 Course.
9. Addon Phase D: Occult Market.
10. Addon Phase B: Fae Lineage.
11. Addon Phase E: Nightlife.

This order gets the playable base stable first, then adds the most mechanically useful tutorial mods before deeper social and schedule content.

-----------
Decision Log

- Existing base data will be deleted and rebuilt, not converted.
- Base game should be minimal, not content-complete.
- Addons are the long-term content model.
- Each addon is also a tutorial.
- Ritual components are inventory parts/items, not currencies, so the system can support many component types over time.
- Part swapping spends mana and ritual components; cash is usually indirect through buying components.
- `normalcy` is a social stat in v1, not a global risk meter.
- Grades/progress should ultimately be course-specific.
- Sleep restores mana and locks in day-end consequences.
- Parts can be bought, crafted, unlocked through study, or awarded by quests, with separate addons teaching those paths.
- Starter course progress id is `arcana_101_grade`.
- Starter ritual component is `base:ritual_chalk`, tagged `ritual_component` and `ritual_basic`.
- `health` is deferred from base v1; the initial game should avoid death/injury pressure and use `stress` and `mana` instead.
