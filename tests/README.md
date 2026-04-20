# Omni-Framework Tests

The project uses GUT for automated coverage.

Default config lives in `res://.gutconfig.json` and searches all suites under `res://tests/`.

Typical command-line run:

```text
godot --headless -s res://addons/gut/gut_cmdln.gd -gexit
```

Useful variants:

```text
godot --headless -s res://addons/gut/gut_cmdln.gd -gexit -gselect=test_entity_instance_stats
```

On Godot 4.6.2 Mono for Windows, prefer the configured full-suite run or
`-gselect` targeted runs. Directory/path override flags such as `-gdir` and
`-gtest` have been observed to crash this workspace before GUT prints its
banner, while the configured suite and filename-selection flow run headlessly.
This local runner can still return process exit code `0` when GUT reports assertion failures, so treat the printed GUT summary as authoritative.

UI-facing smoke/component suites mount scenes under offscreen `SubViewport` hosts so editor-driven runs keep the GUT result readout visible while controls and routed screens initialize.

Persistence-facing suites must stay isolated from normal player data. During GUT runs, `SaveManager` writes under `user://test_saves/` and `AppSettings` writes under `user://test_settings/`; tests that need explicit paths should use the provided testing override helpers and keep temporary scratch files under `user://test_scratch/`.

Current baseline suites cover:

- stat definition normalization
- GameEvents catalog and dynamic emit guards
- entity stat initialization and clamping
- action signal forwarding
- basic GameState/save flow
- save/load time resynchronization
- DataManager query helpers and immutability
- DataManager load diagnostics, patch target validation, and cross-registry integrity checks
- AI provider config selection, readiness gating, GameEvents emission, and debug snapshot coverage
- AudioManager bus fallback, config reload hooks, pause/resume signal wiring, and music transition hardening
- UIRouter stack semantics, failure-path hardening, and debug snapshot coverage
- engine-owned UI behavior coverage for pause/cancel routing, settings back-save persistence, save-slot delete confirmation, and current-screen debug snapshots
- Phase 4 backend screen smoke coverage for assembly editor, exchange, catalog list, list view, challenge, task provider, and dialogue routed scenes
- gameplay shell presenter view-model coverage for active and inactive session states
- shared UI route catalog coverage for backend mappings and runtime scene registration
- mod dependency-aware load ordering
- mod manifest validation and loader debug snapshot coverage
- end-to-end boot pipeline contracts (load phases, new game bootstrap, repeated reloads, save/load flow)
- base content invariants
