<div style="display: flex; align-items: center; gap: 20px;">
  <img src="../icon.svg" alt="Omni-Framework Icon" width="100"/>
  <h1>Mods</h1>
</div>

All game content lives here. The engine ships without content — `ModLoader` treats this folder as the source of truth and a missing `mods/base/` is a fatal boot error.

## Layout

Each subfolder is one mod.

```
mods/
├── base/                   # The base game (load_order: 0, always required)
└── <author_id>/<mod_id>/   # User/community mods
```

## Mod folder shape

```
<author>/<mod>/
├── mod.json       # Manifest: name, id, version, load_order, dependencies
├── data/          # JSON additions and patches (parts, entities, locations, …)
├── dialogue/      # .dialogue files (Dialogue Manager format)
├── scripts/       # GDScript hooks extending ScriptHook
└── assets/        # Fonts, icons, SFX, music
```

## Load pipeline

Mods load in two phases:

1. **Additions** — new JSON entries merge into their registries.
2. **Patches** — every mod's `patches` block runs last, so Mod B can patch Mod A's additions.

Base mod always loads first. All template IDs use `author:mod:name` namespacing (the base game uses `base:`).

## Authoring

See [`../docs/modding_guide.md`](../docs/modding_guide.md) for the full modder reference — schemas, patching rules, backend class contracts, config keys, and script hook patterns.
