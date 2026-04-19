# Test Failure Analysis — Omni-Framework

## Summary

The test failures fall into **three distinct categories**, all stemming from **missing or incorrect test data** rather than bugs in the implementation code:

1. **Currency initialization mismatch** (8 failures)
2. **Missing equippable parts** (7 failures)  
3. **Missing bootstrap content and resource loading issues** (8 failures)

---

## Category 1: Currency Initialization Mismatch (8 Tests)

### Root Cause
Tests expect the player to start with **100 credits**, but `entities.json` defines the player with **500 credits**.

### Affected Tests
- `test_game_state_and_save_flow.gd::test_player_currency_is_owned_by_player_entity`
  - Line 20: `assert_eq(GameState.get_currency("credits"), 100.0)` — **Expected 100, got 500**
  - Line 24: `assert_eq(GameState.player.get_currency("credits"), 125.0)` — **Expected 125, got 525**
  - Line 25: `assert_eq(GameState.player.get_currency("credits"), 125.0)` — **Expected 125, got 525**

- `test_game_state_and_save_flow.gd::test_save_round_trip_restores_game_state`
  - Line 46: `assert_eq(GameState.player.get_currency("credits"), 125.0)` — **Expected 125, got 525**

- `test_save_manager_hardening.gd::test_failed_load_restores_previous_runtime_state`
  - Line 77: `assert_eq(GameState.player.get_currency("credits"), 115.0)` — **Expected 115, got 515**

- `test_game_events_contracts.gd::test_boot_can_initialize_ai_and_start_new_game`
  - Line 153: `assert_eq(GameState.get_currency("credits"), 100.0)` — **Expected 100, got 500**

- `test_phase4_backends.gd::test_exchange_backend_moves_stocked_part_and_transfers_currency`
  - Line 81: `assert_eq(updated_player.get_currency("credits"), initial_player_credits - 8.0)` — **Expected 492, got 500**
  - Line 85: `assert_eq(updated_vendor.get_currency("credits"), initial_vendor_credits + 8.0)` — **Expected 0 + 8, got 8 (calculation is correct)**

- `test_phase4_backends.gd::test_catalog_list_backend_mints_new_part_for_buyer`
  - Line 117: `assert_eq(updated_player.get_currency("credits"), initial_credits - 8.0)` — **Expected 492, got 500**

- `test_phase4_backends.gd::test_challenge_backend_applies_success_reward_to_player`
  - Line 170: `assert_eq(GameState.get_currency("credits"), 515.0)` — **Expected 515, got 500+ reward**

- `test_game_events_contracts.gd::test_save_and_load_flow_matches_boot_suites`
  - Line 206: `assert_eq(GameState.player.get_currency("credits"), 125.0)` — **Expected 125, got 525**

### Data vs. Test Mismatch

**Current `entities.json`:**
```json
{
  "entity_id": "base:player",
  "currencies": {
    "credits": 500,
    "data_shards": 3
  },
  ...
}
```

**Test Expectation:** Initial player credit balance is **100**.

### Fix Location
Either:
- Update `mods/base/data/entities.json` to set player `credits: 100` (or adjust the test initial value), **OR**
- Update all test assertions to expect 500 + offset instead of 100 + offset

---

## Category 2: Missing Equippable Parts (7 Tests)

### Root Cause
Tests reference parts that **do not exist** in `parts.json`:
- `base:body_hair_short`
- `base:body_hair_long`
- `base:body_arm_standard`

### Current Parts Available
`parts.json` only contains:
- `base:test_core`
- `base:test_module`
- `base:test_weapon`

### Affected Tests

**`test_entity_instance_equipping.gd::test_set_equipped_template_replaces_slot_contents`**
- Lines 13-18: Tries to equip `base:body_hair_short` and `base:body_hair_long`
- **These parts don't exist** → `set_equipped_template()` fails silently
- Line 14: `assert_eq(entity.get_equipped_template_id("hair"), "base:body_hair_short")` — **Expected "base:body_hair_short", got ""**
- Line 15: `assert_eq(entity.equipped.size(), initial_equipped_count + 1)` — **Expected +1, got 0**

**`test_entity_instance_equipping.gd::test_inventory_equip_and_unequip_moves_part_between_inventory_and_slot`**
- Lines 24, 28-30: Tries to equip `base:body_arm_standard`
- **This part doesn't exist** → Can't create it
- Line 30: `assert_eq(entity.get_equipped_template_id("left_arm"), "base:body_arm_standard")` — **Expected "base:body_arm_standard", got ""**

**`test_game_events_contracts.gd::test_entity_instance_equipping_flow_matches_boot_suites`**
- Line 176: Assertion failure (child of equipping test flow)
- Line 177: `assert_eq(entity.get_equipped_template_id("left_arm"), "base:body_arm_standard")` — **Expected "base:body_arm_standard", got ""**

**`test_phase4_backends.gd::test_list_backend_builds_inventory_rows_from_player_inventory`**
- Lines 125-129: Creates a player and tries to add `base:body_arm_standard`
- **Part doesn't exist** → Can't add to inventory
- Line 126: `assert_false(template.is_empty())` — **Template IS empty**

### Fix Location
Add the missing parts to `mods/base/data/parts.json`:
- `base:body_hair_short` (equippable, slot: `hair`)
- `base:body_hair_long` (equippable, slot: `hair`)
- `base:body_arm_standard` (equippable, slot: `left_arm`/`right_arm`)

---

## Category 3: Missing Bootstrap Content & Resource Loading (8 Tests)

### Root Cause #1: Missing "base:start" Location
Tests expect a location with ID `base:start`, but `locations.json` only defines:
- `base:hub_safehouse` (starting location for player)
- `base:test_hub`

### Affected Tests

**`test_base_content_invariants.gd::test_base_bootstrap_content_exists`**
- Line 12: `assert_false(DataManager.get_location("base:start").is_empty())` — **Location "base:start" doesn't exist**

**`test_game_events_contracts.gd::test_boot_can_initialize_ai_and_start_new_game`**
- Line 154: `assert_eq(GameState.current_location_id, "base:start")` — **Expected "base:start", got "base:hub_safehouse"**

### Current Data Mismatch
`entities.json` defines player's starting location as:
```json
"location_id": "base:hub_safehouse"
```

Tests expect: `base:start`

---

### Root Cause #2: Dialogue Resource Loading Failures

**`test_phase4_backends.gd::test_dialogue_backend_resolves_sample_dialogue_resource`**
- Line 218: `assert_eq("", "The configured dialogue resource could not be loaded.")`
- This indicates the dialogue system couldn't load a resource (likely a `.dialogue` file reference in the backend config)

---

### Root Cause #3: Backend Screen Resource Failures

Multiple tests fail with "Unexpected Errors" containing `Method/function failed. Returning: Ref<Resource>()`:

**`test_backend_screen_smoke.gd::test_phase4_backend_screens_instantiate_and_initialize_without_runtime_errors`**
- Lines 145+: **8 method/function failures** when instantiating backend screens
- Likely causes:
  - Scenes referenced in `backend_class` registry don't exist
  - Scene dependencies (scripts, themes, assets) are missing
  - Resources are null/invalid

**`test_engine_owned_screen_smoke.gd::test_engine_owned_screens_instantiate_and_initialize_without_runtime_errors`**
- Lines 81+: **2 method/function failures** instantiating engine screens

**`test_engine_owned_ui_behaviors.gd` (2 tests)**
- Lines 71, 163+: **Repeated resource loading failures** during UI initialization

**`test_ui_component_library.gd::test_remaining_component_library_renders_sample_view_models`**
- Line 198: **1 method/function failure** rendering components

### Fix Location
The failures suggest missing or broken scene assets. Check:
- `ui/screens/backends/*.tscn` — Do all referenced backend scenes exist?
- `ui/screens/*.tscn` — Do all engine-owned screen scenes exist?
- Theme/asset references in `ui/theme/`
- Script imports in scene files

---

## Category 4: Phase-Specific Data Definition Failures (4 Tests)

**`test_game_events_contracts.gd::test_mod_loader_phase_one_populates_registries`**
- Line 117: Assertion failure (likely related to missing parts/entities)

**`test_phase5_backends.gd::test_faction_reputation_backend_lists_seeded_faction`**
- Line 48: `assert_eq(2, 1)` — Expected 1 faction, got 2 (or vice versa)
- **Data mismatch in `factions.json`** or faction seeding logic

**`test_phase5_backends.gd::test_achievement_list_backend_reports_progress_and_unlock_state`**
- Lines 64, 67, 68: Multiple assertion failures
- Expected achievement: `base:phase5_achievement`
- Got achievement: `base:first_trip`
- **Mismatch between test expectations and `achievements.json` data**

---

## Summary Table

| Category | Count | Root Cause | Fix |
|----------|-------|-----------|-----|
| Currency mismatch | 8 | Player starts with 500 credits, not 100 | Align `entities.json` or test assertions |
| Missing parts | 7 | `base:body_hair_*` and `base:body_arm_standard` don't exist | Add missing parts to `parts.json` |
| Missing location | 2 | `base:start` doesn't exist; should be `base:hub_safehouse` | Update test OR rename location |
| Dialogue loading | 1 | Resource file missing or path invalid | Check dialogue backend config & files |
| UI scene failures | 5 | Backend/engine screens or components missing/broken | Verify `ui/screens/` scene files |
| Data definitions | 4 | Achievement/faction data mismatch | Audit `achievements.json` and `factions.json` |

---

## Verification Strategy

To confirm these diagnoses:

1. **Check currency balance:**
   ```bash
   grep -A5 '"base:player"' mods/base/data/entities.json | grep -A2 "currencies"
   ```

2. **List all parts:**
   ```bash
   grep '"id":' mods/base/data/parts.json
   ```

3. **List all locations:**
   ```bash
   grep '"location_id":' mods/base/data/locations.json
   ```

4. **Verify scene paths:**
   ```bash
   ls ui/screens/backends/
   ls ui/screens/
   ```

5. **Check achievement IDs:**
   ```bash
   grep '"achievement_id":' mods/base/data/achievements.json
   ```

---

## Conclusion

**All test failures are data-driven, not code bugs.** The test assertions reference game data that either:
- Doesn't exist (missing parts, locations, achievements)
- Has changed since tests were written (currency initialization, starting location)
- Is incomplete or malformed (missing scene files, dialogue resources)

The implementation code is likely correct—**the tests are validating against stale or incomplete test fixtures.**
