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
- AI provider config selection
- mod dependency-aware load ordering
- base content invariants
