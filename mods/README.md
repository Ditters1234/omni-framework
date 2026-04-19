<p>
  <img src="../icon.svg" alt="Omni-Framework Icon" width="100" style="vertical-align: middle; margin-right: 15px;">
  <span style="font-size: 2.5em; font-weight: bold; vertical-align: middle;">Mods</span>
</p>

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

See [`../docs/MODDING_GUIDE.md`](../docs/MODDING_GUIDE.md) for the full modder reference — schemas, patching rules, backend class contracts, config keys, and script hook patterns.

## Best Practices

When creating mods:

- **Keep mods non-destructive** — use patches (Phase 2) to modify existing content rather than replacing it
- **Follow naming conventions** — use `author_id:mod_id:content_id` format for all IDs
- **Validate your JSON** — the loader will reject invalid files; test your mod with the debug overlay
- **Document dependencies** — list required mods in `mod.json` so load order is predictable
- **Test compatibility** — ensure your mod patches work with multiple load orders

## Contributing

Found a bug in a mod or want to improve the base game?

1. Check the existing issues in the repo
2. Test against the latest version
3. Submit a PR with your changes, ensuring the test suite passes
4. Reference the relevant documentation (`MODDING_GUIDE.md`, `SCHEMA_AND_LINT_SPEC.md`, etc.)
