# Vanguard University Asset Requirements

Purpose:
List the image and sound asset paths referenced by the fresh Vanguard base data. These files do not need engine work; they are content assets to create or replace.

Status:
- Image paths are filled with generated placeholder PNGs.
- Sound paths are filled with generated placeholder WAVs.

-----------
Image Assets

Entity portraits:

- `res://mods/base/assets/vanguard/entities/player_student.png`
- `res://mods/base/assets/vanguard/entities/dorm_cache.png`
- `res://mods/base/assets/vanguard/entities/mara_vale.png`
- `res://mods/base/assets/vanguard/entities/professor_ilex.png`
- `res://mods/base/assets/vanguard/entities/foreman_briggs.png`
- `res://mods/base/assets/vanguard/entities/shopkeeper_sel.png`

Body parts:

- `res://mods/base/assets/vanguard/parts/human_mind.png`
- `res://mods/base/assets/vanguard/parts/primal_hindbrain.png`
- `res://mods/base/assets/vanguard/parts/human_senses.png`
- `res://mods/base/assets/vanguard/parts/fae_sight.png`
- `res://mods/base/assets/vanguard/parts/human_hands.png`
- `res://mods/base/assets/vanguard/parts/clawed_grip.png`
- `res://mods/base/assets/vanguard/parts/human_stride.png`
- `res://mods/base/assets/vanguard/parts/bounding_legs.png`
- `res://mods/base/assets/vanguard/parts/human_frame.png`
- `res://mods/base/assets/vanguard/parts/hulking_frame.png`
- `res://mods/base/assets/vanguard/parts/student_id_lanyard.png`

Default/fallback part icons:

- `res://mods/base/assets/vanguard/parts/default_cognitive.png`
- `res://mods/base/assets/vanguard/parts/default_sensory.png`
- `res://mods/base/assets/vanguard/parts/default_manipulator.png`
- `res://mods/base/assets/vanguard/parts/default_locomotion.png`
- `res://mods/base/assets/vanguard/parts/default_framework.png`

Items:

- `res://mods/base/assets/vanguard/items/ritual_chalk.png`
- `res://mods/base/assets/vanguard/items/cafeteria_voucher.png`
- `res://mods/base/assets/vanguard/items/lecture_notes.png`
- `res://mods/base/assets/vanguard/items/default_ritual_component.png`
- `res://mods/base/assets/vanguard/items/default_consumable.png`
- `res://mods/base/assets/vanguard/items/default_study_aid.png`

Faction emblems:

- `res://mods/base/assets/vanguard/factions/vanguard_students.png`
- `res://mods/base/assets/vanguard/factions/vanguard_faculty.png`
- `res://mods/base/assets/vanguard/factions/aethelgard_workers.png`

Achievement icons:

- `res://mods/base/assets/vanguard/achievements/first_activity.png`
- `res://mods/base/assets/vanguard/achievements/first_purchase.png`
- `res://mods/base/assets/vanguard/achievements/orientation_complete.png`
- `res://mods/base/assets/vanguard/achievements/campus_walker.png`

-----------
Sound Assets

Ritual/equipment:

- `res://mods/base/assets/vanguard/audio/sfx_ritual_soft.wav`
- `res://mods/base/assets/vanguard/audio/sfx_ritual_primal.wav`
- `res://mods/base/assets/vanguard/audio/sfx_ritual_fae.wav`

UI/gameplay events:

- `res://mods/base/assets/vanguard/audio/sfx_trade.wav`
- `res://mods/base/assets/vanguard/audio/sfx_challenge_success.wav`
- `res://mods/base/assets/vanguard/audio/sfx_challenge_failure.wav`
- `res://mods/base/assets/vanguard/audio/sfx_quest_complete.wav`
- `res://mods/base/assets/vanguard/audio/sfx_achievement_unlock.wav`
- `res://mods/base/assets/vanguard/audio/sfx_sleep.wav`
- `res://mods/base/assets/vanguard/audio/sfx_craft.wav`
- `res://mods/base/assets/vanguard/audio/sfx_travel.wav`

Dialogue blips:

- `res://mods/base/assets/vanguard/audio/sfx_dialogue_mara.wav`
- `res://mods/base/assets/vanguard/audio/sfx_dialogue_ilex.wav`

-----------
Addon placeholder assets:

`mods/omni/primal_lineage/` currently includes local placeholder copies for all addon-owned asset references:

- `res://mods/omni/primal_lineage/assets/parts/pack_instinct.png`
- `res://mods/omni/primal_lineage/assets/parts/hauling_grip.png`
- `res://mods/omni/primal_lineage/assets/parts/yard_runner_legs.png`
- `res://mods/omni/primal_lineage/assets/parts/dray_frame.png`
- `res://mods/omni/primal_lineage/assets/audio/sfx_ritual_primal.wav`
- `res://mods/omni/primal_lineage/assets/audio/sfx_achievement_unlock.wav`

These are acceptable placeholders, not final unique addon art.

-----------
Asset Notes

- Keep icons readable at small UI sizes.
- Use transparent PNGs for parts, items, faction emblems, and achievement icons.
- Entity portraits can be square PNGs.
- One-shot UI sounds should be short `.wav` or `.ogg` files.
- Add `.import` files by importing the assets through Godot after the source files exist.
