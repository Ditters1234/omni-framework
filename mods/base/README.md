<p>
  <img src="../../icon.svg" alt="Omni-Framework Icon" width="100" style="vertical-align: middle; margin-right: 15px;">
  <span style="font-size: 2.5em; font-weight: bold; vertical-align: middle;">Base Game Mod</span>
</p>

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

## Contributing to Base Game Content

The base game is a mod like any other. When adding or modifying base content:

1. **Follow the data schemas** — see [`../../docs/SCHEMA_AND_LINT_SPEC.md`](../../docs/SCHEMA_AND_LINT_SPEC.md)
2. **Use patches for compatibility** — if modifying existing entries, use Phase 2 patches to allow other mods to layer on top
3. **Document your additions** — include descriptions in quest/task/achievement definitions
4. **Test thoroughly** — use the debug overlay to verify registries and state
5. **Keep it genre-agnostic** — the base game should not assume a specific setting or mechanics (no hardcoded classes, currencies, etc.)
