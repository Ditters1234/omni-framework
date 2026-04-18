<p>
  <img src="icon.svg" alt="Omni-Framework Icon" width="100" style="vertical-align: middle; margin-right: 15px;">
  <span style="font-size: 2.5em; font-weight: bold; vertical-align: middle;">Omni-Framework</span>
</p>

A single-player, data-driven, genre-agnostic game engine built on **Godot 4** (GDScript).

The engine provides the systems; JSON provides the content. The same runtime can power a fantasy RPG, a sci-fi colony sim, or a cyberpunk trading game without code changes — swap the mod, swap the game.

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

## License

[MIT](LICENSE) © 2026 Ditters.
