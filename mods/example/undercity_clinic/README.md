# Undercity Clinic

Adds **Dr. Mira**, a rogue combat medic operating from a hidden clinic beneath the Undercity.

## What this mod demonstrates

- **Location access conditions**: The clinic is locked behind an `entry_condition` that checks the `example:undercity_clinic:clinic_unlocked` flag. The flag is set by passing a `ChallengeBackend` stat check (armor >= 2) added to the base Undercity location via a patch.
- **Location patching**: Adds a connection and a new screen to `base:undercity` without replacing the existing location data.
- **Crafting with a custom station**: Two recipes require `example:undercity_clinic:mira_bench`, only available at the clinic. One is instant, one is timed.
- **NPC with inventory-based assembly**: Dr. Mira's "Install Implants" interaction uses `AssemblyEditorBackend` with `option_source_entity_id: "player"`, meaning the player installs from their own inventory at no currency cost.
- **Multi-stage quest**: The `find_the_clinic` quest chains stat requirements, flag checks, and location objectives across three stages.
- **Timed tasks**: The `organ_salvage` task uses `WAIT` type with a 5-tick duration and item rewards.
- **Hidden achievement**: `House Call` is hidden until unlocked.

## Content added

| Type | ID | Description |
|---|---|---|
| Location | `example:undercity_clinic:clinic` | Mira's Clinic (gated) |
| Entity | `example:undercity_clinic:dr_mira` | Dr. Mira (medic NPC) |
| Part | `example:undercity_clinic:combat_stim` | Combat Stimulant (consumable) |
| Part | `example:undercity_clinic:trauma_patch` | Trauma Patch (consumable) |
| Part | `example:undercity_clinic:recycled_plating` | Recycled Bone Plating (craftable armor) |
| Part | `example:undercity_clinic:nerve_splice` | Nerve Splice (craftable implant) |
| Part | `example:undercity_clinic:synth_blood` | Synthetic Blood Pack (crafting material) |
| Recipe | `example:undercity_clinic:recycled_plating` | Craft armor from scrap + blood |
| Recipe | `example:undercity_clinic:nerve_splice` | Craft implant from chips + blood |
| Quest | `example:undercity_clinic:find_the_clinic` | Underground Medicine |
| Task | `example:undercity_clinic:blood_run` | Deliver blood to clinic |
| Task | `example:undercity_clinic:organ_salvage` | Assist with salvage operation |
| Achievement | `example:undercity_clinic:found_the_doctor` | House Call (hidden) |

## Gameplay flow

1. Player gets armor >= 2 (buy Kevlar Weave from Theta or craft Improvised Plating).
2. In the Undercity, the "Sealed Door" challenge screen appears. Pass the armor check.
3. The `clinic_unlocked` flag is set and the clinic connection opens.
4. Visit the clinic to complete the quest and meet Dr. Mira.
5. Trade for medical supplies, craft at the surgical workbench, or install implants.
