<div style="display: flex; align-items: center; gap: 20px;">
  <img src="../../icon.svg" alt="Omni-Framework Icon" width="100"/>
  <h1>Base Game Mod</h1>
</div>

The shipped base content for Omni-Framework. It is a mod like any other, with one special property: `ModLoader` treats it as required and loads it first.

- **ID:** `base`
- **load_order:** `0`
- **Namespace:** All template IDs here use the `base:` prefix (e.g. `base:iron_sword`).
- **Status:** Required — the engine refuses to boot if this folder is missing.

## Contents

```
base/
├── mod.json       # Manifest
├── data/          # Definitions, parts, entities, locations, factions,
│                  # quests, tasks, achievements, config
├── dialogue/      # Dialogue Manager .dialogue files
├── scripts/       # Optional ScriptHook extensions
└── assets/        # Fonts, icons, SFX, music
```

## Editing this mod

Treat `base/` the same as any other mod — author JSON additions and patches under `data/`, follow the schemas in [`../../docs/modding_guide.md`](../../docs/modding_guide.md), and keep stat pairs consistent with [`../../docs/STAT_SYSTEM_IMPLEMENTATION.md`](../../docs/STAT_SYSTEM_IMPLEMENTATION.md).

For the overall mod pipeline and load phases, see [`../README.md`](../README.md).
