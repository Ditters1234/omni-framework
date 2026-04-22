# Omni-Framework Autoload Audit
## Runtime / Documentation Mismatches and Risky Assumptions

Date: 2026-04-18

Update: 2026-04-22 sanity check follow-up
- `game.ticks_per_hour` is now used by `gameplay_shell_presenter.gd` as an optional UI time-step override.
- `GameState.new_game()` now follows the strict `game.starting_player_id` contract instead of falling back to `base:player`.
- `DataManager.validate_loaded_content()` now validates `starting_discovered_locations`, `ticks_per_day`, `ticks_per_hour`, and `ui.time_advance_buttons`.

This audit focuses on issues similar to the `DataManager.connections` bug we discovered:
- runtime/doc mismatches
- strict validation that is under-documented
- hidden assumptions in autoload interfaces
- places likely to drift as the project grows

It is based on the uploaded autoload scripts currently in the conversation.

---

## Executive Summary

Confirmed items worth updating in docs or code:

1. **Base mod dependencies are stricter than the guide implies**
   - `mods/base` cannot declare dependencies at all.
   - This should be documented explicitly.

2. **`game.ticks_per_hour` appears documented but unused**
   - `TimeKeeper` reads `game.ticks_per_day`.
   - No current runtime use of `ticks_per_hour` was found in the uploaded autoloads.

3. **`locations.connections` should be documented as object-only**
   - After the validator fix, the runtime expects object-form connections.
   - Array fallback should not be advertised unless reintroduced and tested.

4. **Backend payload typing is stricter than the guide originally suggested**
   - Optional fields are still load-time contract data.
   - Type mismatches become hard failures.

Also worth tracking:

5. **`GameState` contains a fallback default for `game.starting_player_id`**
   - Runtime behavior is looser than validation behavior.
   - This can mask misconfiguration during testing.

6. **`UIRouter` is narrower than a generic “screen container” abstraction**
   - It specifically requires a `CanvasLayer`.

7. **`SaveManager` is future-sensitive**
   - It currently registers only `EntityInstance` and `PartInstance` with A2J.
   - If more runtime classes become first-class objects, save/load will need updating.

8. **`AIManager` and `AudioManager` look broadly aligned with the guide**
   - No comparable contradiction stood out in this pass.

---

## Confirmed Findings

### 1) Base mod cannot declare dependencies

**File:** `mod_loader.gd`

Your loader explicitly rejects dependencies on the base mod:

```gdscript
if not _get_dependencies(manifest).is_empty():
	_record_load_error(manifest_id, "Base mod cannot declare dependencies.", true, ERROR_STAGE_VALIDATION)
```

### Impact
The guide should clearly distinguish:
- normal mod dependencies
- base mod rules

### Recommendation
Update docs to say:
- `mods/base/mod.json` must not declare `dependencies`
- other mods may declare dependency IDs

---

### 2) `ticks_per_hour` looks like doc drift

**Files checked:** `time_keeper.gd`, `game_state.gd`, `data_manager.gd`

`TimeKeeper` reads:

```gdscript
var configured_value: Variant = DataManager.get_config_value("game.ticks_per_day", TICKS_PER_DAY)
```

No runtime reads of `game.ticks_per_hour` were found in the uploaded autoloads.

### Impact
If modders set `ticks_per_hour`, they may assume it changes runtime behavior when it currently does not.

### Recommendation
Either:
- remove `ticks_per_hour` from docs for now, or
- mark it as planned / reserved, or
- implement real runtime use

---

### 3) `locations.connections` should be documented as object-only

**File:** `data_manager.gd`

After the fix, runtime validation now expects a dictionary and validates keys as location IDs:

```gdscript
var connections_value: Variant = location.get("connections", {})
if connections_value is Dictionary:
	var connections: Dictionary = connections_value
	for target_location_value in connections.keys():
		var target_location_id := str(target_location_value)
		...
elif location.has("connections"):
	_record_issue(location_id, OmniConstants.DATA_LOCATIONS, LOAD_PHASE_VALIDATION, "Location '%s' field 'connections' must be an object." % location_id)
```

### Impact
The guide should stop presenting array-form connections as an accepted current runtime format unless that compatibility path is intentionally restored.

### Recommendation
Document only:

```json
"connections": {
  "base:other_location": 1
}
```

---

### 4) Backend payloads are strict contract data

**Evidence**
This came up directly during pack validation with `EventLogBackend.limit`, and is consistent with your runtime’s overall validation style.

### Impact
The guide should not frame optional backend fields as casual extras. They are exact typed payload fields.

### Recommendation
Add a global backend note:

> Backend payloads are strict load-time contract data. Optional fields should be omitted unless needed, and all provided values must match expected runtime types exactly.

---

## Additional Runtime Assumptions Worth Documenting

### 5) `GameState` defaults `starting_player_id` more loosely than validation does

**File:** `game_state.gd`

```gdscript
var player_template_id := str(DataManager.get_config_value("game.starting_player_id", "base:player"))
```

**File:** `data_manager.gd`

```gdscript
var player_template_id := str(get_config_value("game.starting_player_id", ""))
if player_template_id.is_empty():
	_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'game.starting_player_id' must reference a non-empty entity id.")
```

### Impact
Validation requires explicit config.
Gameplay fallback quietly supplies `base:player`.

That split can:
- make testing feel inconsistent
- hide missing config during manual runtime checks

### Recommendation
Choose one policy:
- strict everywhere, or
- fallback everywhere

For docs, prefer strict explicit config.

---

### 6) `UIRouter` specifically requires a `CanvasLayer`

**File:** `ui_router.gd`

```gdscript
var _screen_container: CanvasLayer = null

func initialize(container: CanvasLayer) -> void:
	if container == null:
		_record_error("initialize() requires a valid CanvasLayer container.")
```

### Impact
If internal docs or code comments describe this as a generic screen container, that is broader than the actual contract.

### Recommendation
Document `UIRouter.initialize()` as requiring a `CanvasLayer`.

---

### 7) `SaveManager` is fine now, but narrow for future typed runtime classes

**File:** `save_manager.gd`

```gdscript
const REQUIRED_RUNTIME_CLASSES := ["EntityInstance", "PartInstance"]
```

and:

```gdscript
A2J.object_registry["EntityInstance"] = EntityInstance
A2J.object_registry["PartInstance"] = PartInstance
```

### Impact
This is okay if quests, tasks, and other runtime state remain plain dictionaries or primitive structures.

It becomes a future bug source if you later introduce first-class objects like:
- `QuestInstance`
- `TaskInstance`
- custom runtime progression/state objects

### Recommendation
Add an internal note:
- every new runtime class that enters save payloads must be registered with A2J

---

## Areas That Look Good

### AIManager
No major contradiction stood out relative to your guide’s intended AI ownership model:
- engine-owned provider setup
- optional runtime availability
- mod-side consumption rather than mod-side provider ownership

### AudioManager
This looked aligned with your config docs:
- reads `ui.sounds`
- validates dictionary shape
- reloads after `all_mods_loaded`

Relevant behavior:

```gdscript
var sounds_value: Variant = DataManager.get_config_value("ui.sounds", {})
if not sounds_value is Dictionary:
	_warn_once("invalid_ui_sounds", "AudioManager: ui.sounds must be a dictionary when provided.")
```

and it listens for:

```gdscript
GameEvents.all_mods_loaded.connect(_on_all_mods_loaded)
```

---

## Recommended Documentation Updates

### High priority
- State that `mods/base` cannot declare dependencies
- Remove or mark `game.ticks_per_hour` as unused/reserved
- Document `locations.connections` as object-only
- Add a global note about strict backend typing
- Keep `game.starting_player_id` explicit and required

### Medium priority
- Clarify `UIRouter.initialize()` requires a `CanvasLayer`
- Add an internal developer note for A2J registration when introducing new runtime classes

---

## Recommended Code Follow-Ups

1. Decide whether `game.ticks_per_hour` should:
   - be implemented
   - be removed from docs
   - be treated as deprecated/reserved

2. Consider unifying `starting_player_id` behavior:
   - either validate + require it everywhere
   - or make fallback behavior explicit and intentional

3. If you want legacy location support:
   - add array-form `connections` parsing deliberately
   - test it
   - document it
   - otherwise remove mention of it completely

4. Add an internal checklist for new runtime object types:
   - save/load registration
   - validation
   - serialization round-trip tests

---

## Confidence / Scope Notes

This audit is strongest on:
- loader rules
- config validation
- location schema expectations
- autoload interface assumptions

It is weaker on:
- screen/backend-specific scene logic not included here
- non-autoload helpers
- any runtime behavior defined outside the uploaded files

So this should be treated as a focused autoload audit, not a whole-project code audit.
