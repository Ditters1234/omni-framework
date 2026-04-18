<p>
  <img src="icon.svg" alt="Omni-Framework Icon" width="100" style="vertical-align: middle; margin-right: 15px;">
  <span style="font-size: 2.5em; font-weight: bold; vertical-align: middle;">Omni-Framework</span>
</p>

A single-player, data-driven, genre-agnostic game engine built on **Godot 4** (GDScript).

The engine provides the systems; JSON provides the content. The same runtime can power a fantasy RPG, a sci-fi colony sim, or a cyberpunk trading game without code changes — swap the mod, swap the game.

[![Godot 4.6](https://img.shields.io/badge/Godot-4.6-478cbf?style=flat-square&logo=godotengine)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/ditters/omni-framework.git
   cd omni-framework
   ```

2. **Open in Godot 4.6**
   - Launch Godot 4.6
   - Open the project folder
   - Godot will auto-load the GDExtensions (LimboAI, NobodyWho)

3. **Create your first mod**
   - Duplicate `mods/base/` as `mods/yourname/yourmod/`
   - Edit `mod.json` with your mod's metadata
   - Add JSON content to `data/` folder
   - See [`docs/modding_guide.md`](docs/modding_guide.md) for full details

## Highlights

- **Data-first** — JSON templates define content; GDScript instances are runtime objects.
- **Moddable by default** — two-phase loading lets mods layer non-destructively (additions first, patches second).
- **Genre-agnostic** — abstract names throughout (Parts, Entities, Locations), no hardcoded genres, stats, or currencies.
- **Engine-owned UI + moddable backends** — fixed app screens live in code; interactive screens are selected from mod data via `backend_class`.
- **Pluggable AI** — `AIManager` routes to OpenAI-compatible, Anthropic, embedded NobodyWho, or disabled.

## Documentation

Full documentation lives in [`docs/`](docs/README.md).

Quick jumps:

- [Project structure](docs/PROJECT_STRUCTURE.md) — architecture, autoloads, core systems, UI framework.
- [Modding guide](docs/modding_guide.md) — data schemas, patching, backend classes, script hooks.
- [UI implementation plan](docs/UI_IMPLEMENTATION_PLAN.md) — backend catalog and phased rollout.
- [Stat system](docs/STAT_SYSTEM_IMPLEMENTATION.md) — base/capacity pairs and clamping rules.

## Requirements

- [Godot 4.6](https://godotengine.org/) (GDScript — no C#).
- Godot auto-loads the included GDExtensions (`LimboAI`, `NobodyWho`). Other addons (A2J, Dialogue Manager, GUT) are enabled in `project.godot`.

## Contributing

Contributions are welcome! Before submitting, please:

1. Review [`docs/CODING_STANDARDS_AND_LOADER_PATTERNS.md`](docs/CODING_STANDARDS_AND_LOADER_PATTERNS.md) for implementation patterns
2. Check [`docs/SCHEMA_AND_LINT_SPEC.md`](docs/SCHEMA_AND_LINT_SPEC.md) for validation requirements
3. Run tests: `godot --headless -s res://addons/gut/gut_cmdln.gd -gexit`
4. Ensure no test regressions before opening a pull request

## Troubleshooting

**Missing mods/base/ folder?**
- `ModLoader` treats this as a fatal boot error. Ensure `mods/base/` exists with a valid `mod.json`.

**Import errors on startup?**
- Godot should auto-load A2J, LimboAI, and NobodyWho. If not, check **Project Settings → Autoload** to verify they're registered.

**JSON validation errors?**
- Check [`docs/SCHEMA_AND_LINT_SPEC.md`](docs/SCHEMA_AND_LINT_SPEC.md) for schema rules and error messages in the debug overlay.

## License

[MIT](LICENSE) © 2026 Ditters.
