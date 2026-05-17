# Vanguard Nightlife

This addon adds an after-hours district with late-day recovery and social risk activities.

## What This Teaches

- `data/locations.json`: adding a new location and patching a base location connection.
- `data/activities.json`: time-gated activities with cross-midnight schedules and risk/reward outcomes.
- `data/status_effects.json`: temporary recovery and fatigue effects driven by activity results.
- `data/entities.json`: a static location NPC that appears through its authored `location_id`.
- `data/quests.json`: a small scene-onboarding quest started from Vesper's interaction.
- `data/achievements.json`: an addon-owned milestone unlocked by a data-authored activity action.

## Play Pattern

Travel from High Street to the Nightlife District after daytime work or study. The activities can reduce stress, improve reputation, or create short-lived buffs, but risk cash loss, fatigue, or public consequences if the player's build is not suited to the scene.

The quest `omni:nightlife:learn_the_scene` asks the player to reach the district, get Vesper's read, and complete one after-hours activity.

## Assets

This addon includes local placeholder sprites and sounds under `assets/`. They are copied from current Vanguard base placeholders while final nightlife art and audio are still in progress.
