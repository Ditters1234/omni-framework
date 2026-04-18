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
godot --headless -s res://addons/gut/gut_cmdln.gd -gexit -gdir=res://tests/unit -ginclude_subdirs
```

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
- gameplay shell presenter view-model coverage for active and inactive session states
- shared UI route catalog coverage for backend mappings and runtime scene registration
- mod dependency-aware load ordering
- mod manifest validation and loader debug snapshot coverage
- end-to-end boot pipeline contracts (load phases, new game bootstrap, repeated reloads, save/load flow)
- base content invariants
