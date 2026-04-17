# Stat System Implementation Guide

## Overview

This document provides clear implementation guidance for the **Capacity + Base Stat System** used in the Omni-Framework.

---

## Core Concepts

### Base Stats vs. Capacity Stats

```
Example: Health System

Base Stat: "health"
  → Represents CURRENT health
  → Ranges from 0 to health_max
  → Changes during gameplay (damage, healing)
  
Capacity Stat: "health_max"
  → Represents MAXIMUM health pool
  → The ceiling for the base stat
  → Modified by equipment/buffs
  → Never goes below 0
```

### Why This Matters

**Without Separation (WRONG):**
```gdscript
# Player equips armor that reduces health_max by 25
player.health = 100
player.equip_armor()  # armor.health_max = -25

# Now what is player.health?
# Did the armor reduce current health? (player dies mid-fight)
# Did it reduce max health? (no, that was health_max)
# AMBIGUITY = BUG
```

**With Separation (CORRECT):**
```gdscript
player.stats["health"] = 100        # Current health
player.stats["health_max"] = 100    # Maximum health pool

player.equip_armor()  # armor modifies health_max, not health
# armor.stats["health_max"] = -25

effective_health_max = player.stats["health_max"] + armor.stats["health_max"]
# effective_health_max = 100 + (-25) = 75

player.stats["health"] = min(player.stats["health"], effective_health_max)
# If player had 100 health and max drops to 75, clamp to 75
```

---

## Stat Definition Format

The canonical stat-definition format should be explicit and machine-readable. Do not rely on string names alone to tell the engine whether a stat is flat, current-value, or capacity.

Recommended `definitions.json` structure:
```json
{
  "stats": [
    {
      "id": "strength",
      "kind": "flat",
      "default_value": 0,
      "ui_group": "combat"
    },
    {
      "id": "health",
      "kind": "resource",
      "paired_capacity_id": "health_max",
      "default_value": 100,
      "default_capacity_value": 100,
      "clamp_min": 0,
      "ui_group": "survival"
    },
    {
      "id": "health_max",
      "kind": "capacity",
      "paired_base_id": "health",
      "default_value": 100,
      "clamp_min": 0,
      "ui_group": "survival"
    }
  ]
}
```

Field expectations:
- `id`: Unique stat ID.
- `kind`: `flat`, `resource`, or `capacity`.
- `paired_capacity_id`: Required when `kind` is `resource`.
- `paired_base_id`: Required when `kind` is `capacity`.
- `default_value`: Used for entity initialization when omitted from a template.
- `default_capacity_value`: Optional helper used by resource stats during initialization.
- `clamp_min`: Lower bound used by runtime systems and validation.
- `ui_group`: Optional display grouping.

The `_max` suffix remains the required naming convention for capacity stats, but metadata should be the source of truth for validation and tooling.

## Always Paired Stats

**Rule:** If you define one, you MUST define the other.

Valid pairs in `definitions.json`:
```json
{
  "stats": [
    { "id": "health", "kind": "resource", "paired_capacity_id": "health_max" },
    { "id": "health_max", "kind": "capacity", "paired_base_id": "health" },
    { "id": "mana", "kind": "resource", "paired_capacity_id": "mana_max" },
    { "id": "mana_max", "kind": "capacity", "paired_base_id": "mana" },
    { "id": "stamina", "kind": "resource", "paired_capacity_id": "stamina_max" },
    { "id": "stamina_max", "kind": "capacity", "paired_base_id": "stamina" },
    { "id": "rage", "kind": "resource", "paired_capacity_id": "rage_max" },
    { "id": "rage_max", "kind": "capacity", "paired_base_id": "rage" }
  ]
}
```

**DO NOT CREATE:**
- ❌ `health` without `health_max`
- ❌ `mana_max` without `mana`
- ❌ Unpaired capacity stats

### Load-Time Validation Rules

The stat system is one of the engine's core invariants, so template validation should reject bad stat data early.

Required rules:

- Every stat key used by an entity, part, task reward, or condition must exist in `definitions.json`.
- Every stat definition must declare a valid `kind`.
- Any stat with `kind: "resource"` must declare `paired_capacity_id`.
- Any stat with `kind: "capacity"` must declare `paired_base_id`.
- The named pair must exist in `definitions.json` and point back correctly.
- Any stat ending with `_max` must be a `capacity` stat, and capacity stats should keep the `_max` naming convention.
- Any entity template that defines `health_max`-style capacity stats should also define the matching base stat, unless the loader is explicitly filling it from metadata defaults.
- Parts may modify base stats or capacity stats, but they may not invent unknown stat IDs.
- Authoring data that starts with `current > max` is invalid and should be fixed in source, even if runtime clamping would eventually correct it.

---

## Stat Initialization on Entities

### Correct Entity Definition

```json
{
  "entity_id": "base:player",
  "display_name": "Player Character",
  "stats": {
    "health": 80,
    "health_max": 100,
    "mana": 50,
    "mana_max": 100,
    "stamina": 60,
    "stamina_max": 75,
    "strength": 10,
    "agility": 8
  }
}
```

**Notes:**
- Base stats (`health`, `mana`) = current values
- Capacity stats (`health_max`, `mana_max`) = maximum pools
- Flat stats (`strength`, `agility`) = no capacity variant
- Current ≤ Maximum always (else initialize broken)

### Default Values

If an entity doesn't specify a stat, initialize from definitions metadata instead of guessing from suffixes alone:

```gdscript
# In EntityLoader.gd
func initialize_entity_stats(entity: Dict) -> Dict:
    var stats = entity.get("stats", {})
    
    for stat_def in definitions["stats"]:
        var stat_id = stat_def["id"]
        var kind = stat_def["kind"]

        if stat_id in stats:
            continue

        match kind:
            "flat":
                stats[stat_id] = stat_def.get("default_value", 0)
            "capacity":
                stats[stat_id] = stat_def.get("default_value", 0)
            "resource":
                var capacity_id = stat_def["paired_capacity_id"]
                if not capacity_id in stats:
                    stats[capacity_id] = stat_def.get("default_capacity_value", stat_def.get("default_value", 0))
                stats[stat_id] = stat_def.get("default_value", stats[capacity_id])
    
    return stats
```

This keeps initialization deterministic and makes flat stats, current-value stats, and capacity stats all first-class concepts in data.

---

## Stat Calculation: Base + Modifiers

### Formula

```
effective_stat = base_stat + sum(equipped_parts.stats[stat_name])
```

### Example: Strength Calculation

```gdscript
# Scenario:
# - Entity base strength: 10
# - Equipped sword: +5 strength
# - Equipped armor: +3 strength

entity.stats["strength"] = 10
equipped_parts = [sword, armor]

effective_strength = 10
for part in equipped_parts:
    if "strength" in part.stats:
        effective_strength += part.stats["strength"]

# effective_strength = 10 + 5 + 3 = 18
```

### Example: Health Calculation with Clamping

```gdscript
# Scenario:
# - Entity base health: 100, health_max: 100
# - Equip heavy armor: health_max - 30
# - Player has taken 5 damage
# - What is current/max health?

entity.stats["health"] = 95         # Current (taken 5 damage)
entity.stats["health_max"] = 100    # Base max

armor = { "stats": { "health_max": -30 } }
entity.equip(armor)

# Calculate effective capacity
effective_health_max = entity.stats["health_max"] + armor.stats["health_max"]
# effective_health_max = 100 + (-30) = 70

# Clamp current health to not exceed max
entity.stats["health"] = min(entity.stats["health"], effective_health_max)
# entity.stats["health"] = min(95, 70) = 70

# Now player has 70/70 health (lost 25 health from capacity reduction)
```

---

## Clamping Rules

### Health-Like Stats (Must Clamp)

```gdscript
func clamp_health_stat(entity: Dictionary) -> void:
    var base_health = entity.stats["health"]
    var max_health = calculate_effective_max(entity, "health_max")
    
    # Current health never exceeds max
    entity.stats["health"] = clamp(base_health, 0, max_health)
    
    # Max health never goes below 0
    entity.stats["health_max"] = max(entity.stats["health_max"], 0)

func calculate_effective_max(entity: Dictionary, max_stat: String) -> int:
    var base_max = entity.stats.get(max_stat, 0)
    var modifiers = 0
    
    for part in entity.equipped_parts:
        if max_stat in part.stats:
            modifiers += part.stats[max_stat]
    
    return base_max + modifiers
```

### When to Apply Clamping

1. **On Part Equip:** When a part with `health_max` modifier is equipped
2. **On Part Unequip:** When capacity might increase (less common)
3. **On Damage:** After reducing current health
4. **On Load:** When entity loads with potentially invalid data
5. **On Stat Patch:** If a mod patch changes stat values

### Clamping Is Runtime Safety, Not Schema Validation

Clamping keeps the live game safe, but it should not be used as an excuse to accept broken template data silently.

- Runtime code clamps transient gameplay changes.
- Load-time validation rejects malformed definitions and authoring mistakes.
- Migration code may repair legacy data intentionally, but that repair should be explicit and logged.

---

## Part Stat Modifiers

### Modifying Base Stats

```json
{
  "id": "my_name:my_mod:strength_ring",
  "display_name": "Ring of Strength",
  "stats": {
    "strength": 5
  }
}
```
Effect: Adds 5 to effective strength (no clamping needed)

### Modifying Capacity Stats

```json
{
  "id": "my_name:my_mod:heavy_armor",
  "display_name": "Plate Armor",
  "stats": {
    "health_max": -20
  }
}
```
Effect: Reduces max health by 20 (current health must be clamped)

### Modifying Both

```json
{
  "id": "my_name:my_mod:life_leech_sword",
  "display_name": "Life Leech Sword",
  "stats": {
    "strength": 10,
    "health_max": -15
  }
}
```
Effect: 
- +10 to effective strength
- -15 to effective max health
- Current health must be clamped if it exceeds new max

---

## Stat Names: Naming Convention

### Pattern: `<base>_<max>`

**Correct pairs:**
- `health` ↔ `health_max`
- `mana` ↔ `mana_max`
- `stamina` ↔ `stamina_max`
- `rage` ↔ `rage_max`
- `fuel` ↔ `fuel_max`

**NOT valid:**
- ❌ `health` ↔ `max_health`
- ❌ `health` ↔ `healthmax`
- ❌ `health` ↔ `health_capacity`

Always use `_max` suffix consistently.

---

## Patching Stats

### Adding Stats to a Part

```json
{
  "patches": [
    {
      "target": "base:iron_sword",
      "set_stats": {
        "strength": 3
      }
    }
  ]
}
```

**Why `set_stats`?** 
- `set` replaces the entire `stats` object (destructive)
- `set_stats` merges into existing `stats` (safe)

### Modifying an Entity's Base Stats

```json
{
  "patches": [
    {
      "target": "base:player",
      "set": {
        "stats": {
          "health": 100,
          "health_max": 120,
          "mana": 50,
          "mana_max": 75
        }
      }
    }
  ]
}
```

---

## Testing Checklist

### Unit Tests

- [ ] **Stat Clamping:** Health > max → clamped to max
- [ ] **Zero Health:** Health = 0 → character "dead" logic triggered
- [ ] **Over-Capacity:** Part reduces max health below current → current clamped
- [ ] **Negative Stats:** Part grants `-strength` → effective strength reduced
- [ ] **Zero Max:** health_max goes to 0 → health forced to 0
- [ ] **Stacking:** Multiple parts modify same stat → additive
- [ ] **Unequip:** Removing part restores previous stat value
- [ ] **Unknown Stat Rejected:** Template using undefined stat key fails validation
- [ ] **Missing Pair Rejected:** `health_max` without `health` is rejected or explicitly defaulted by the loader

### Integration Tests

- [ ] **Entity Load:** Entity with invalid stats corrected on load
- [ ] **Patch Load:** Patching entity stats updates correctly
- [ ] **Part Override:** Equipping new part with same stat modifier works
- [ ] **UI Display:** Character sheet shows correct current/max values
- [ ] **Economy:** Selling damaged part with health_max modifier prices correctly
- [ ] **Definitions Validation:** Stats file with broken base/capacity pairs fails before gameplay boots
- [ ] **Patch Validation:** Mod patch that introduces an unknown stat is rejected with a useful error

### Example Test Cases

```gdscript
# test_stat_clamping.gd
extends GDScriptTestCase

func test_health_clamped_on_equip():
    var entity = Entity.new()
    entity.stats = {"health": 100, "health_max": 100}
    
    var heavy_armor = Part.new()
    heavy_armor.stats = {"health_max": -50}
    
    entity.equip(heavy_armor)
    
    assert_equal(entity.stats["health_max"], 50)
    assert_equal(entity.stats["health"], 50)  # Clamped

func test_multiple_stat_modifiers_stack():
    var entity = Entity.new()
    entity.stats = {"strength": 10}
    
    var sword = Part.new()
    sword.stats = {"strength": 5}
    entity.equip(sword)
    
    var ring = Part.new()
    ring.stats = {"strength": 3}
    entity.equip(ring)
    
    assert_equal(entity.get_effective_stat("strength"), 18)  # 10 + 5 + 3

func test_capacity_stat_required():
    var definitions = DefinitionLoader.load("res://data/definitions.json")
    
    for stat in definitions["stats"]:
        if stat.ends_with("_max"):
            var base_stat = stat.trim_suffix("_max")
            assert_true(base_stat in definitions["stats"],
                "Missing base stat '%s' for capacity '%s'" % [base_stat, stat])
```

---

## Migration Path (If Upgrading Existing System)

If you have an existing system using `health_max` as a modifier (not properly separated):

### Step 1: Audit Current Data
```gdscript
var deprecated_patterns = grep_data("_max") # Find all _max fields
# Review each to confirm they're capacity stats
```

### Step 2: Add Base Stats to Definitions
```json
{
  "stats": [
    "health",      // ADD THIS
    "health_max",
    "mana",        // ADD THIS
    "mana_max"
  ]
}
```

### Step 3: Migrate Entity Data

**Before:**
```json
{
  "entity_id": "base:player",
  "stats": {
    "health_max": 100,
    "strength": 10
  }
}
```

**After:**
```json
{
  "entity_id": "base:player",
  "stats": {
    "health": 100,
    "health_max": 100,
    "strength": 10
  }
}
```

### Step 4: Update Stat Calculation

Replace old logic with new formula:
```gdscript
# OLD: effective_health_max = modifiers only
# NEW: effective_health_max = base + modifiers

effective_health_max = entity.stats["health_max"] + sum(parts.health_max)
```

### Step 5: Add Clamping

Clamp current health wherever max changes:
```gdscript
entity.stats["health"] = min(entity.stats["health"], effective_health_max)
```

---

## Edge Cases & Gotchas

### Gotcha 1: Negative Max Health
```gdscript
# If equipment reduces health_max below 0:
entity.stats["health_max"] = -10  # INVALID

# Fix: Clamp to 0
entity.stats["health_max"] = max(entity.stats["health_max"], 0)
entity.stats["health"] = min(entity.stats["health"], entity.stats["health_max"])
```

### Gotcha 2: Unstacking Stats
```gdscript
# If player unequips armor that reduced health_max:
# DON'T do this:
entity.stats["health_max"] = 100  # Direct assignment loses other mods

# DO this:
effective_health_max = entity.stats["health_max"]  # Before unequip
entity.unequip(armor)
# effective_health_max now recalculated without armor's modifier
new_effective_health_max = entity.stats["health_max"]
entity.stats["health"] = min(entity.stats["health"], new_effective_health_max)
```

### Gotcha 3: Initialization Order
```gdscript
# DON'T initialize like this:
entity.stats["health"] = 100
entity.stats["health_max"] = 50  # oops, health > max now

# DO this:
entity.stats["health_max"] = 50
entity.stats["health"] = 50
```

### Gotcha 4: Flat Stats Don't Need Capacity
```json
{
  "stats": {
    "strength": 10,          // ✅ Good
    "strength_max": 50       // ❌ WRONG - strength has no max
  }
}
```

Only use `_max` for resources that have finite pools.

---

## Questions & Answers

**Q: Can current health be negative?**
A: No. Clamp to 0. Negative health doesn't make logical sense (0 = dead).

**Q: Can max health be negative?**
A: No. Clamp to 0. If max drops to 0, entity is incapacitated.

**Q: What if two parts both modify health_max?**
A: They stack additively. Both modifiers apply.

**Q: Can a part add to health (not health_max)?**
A: Technically yes, but philosophically no. Parts grant permanent stat changes. For temporary healing, use consumable items or actions, not equipped parts.

**Q: What about stat minimums (strength_min)?**
A: Not part of this system. If you need minimums, add clamping in your calculation logic, or track them in config.json.

**Q: How do I make health regenerate?**
A: That's a game mechanic (via tasks, ticks, or events), not a stat definition. You'd have a task that periodically increases the `health` stat.

---

## Code Template

```gdscript
# res://systems/stat_manager.gd
class_name StatManager
extends Node

static func get_effective_stat(entity: Dictionary, stat_name: String) -> float:
    """Get a stat value including all equipped part modifiers."""
    var base_value = entity.stats.get(stat_name, 0.0)
    var modifiers = 0.0
    
    for part in entity.get_equipped_parts():
        if stat_name in part.stats:
            modifiers += part.stats[stat_name]
    
    return base_value + modifiers

static func clamp_to_capacity(entity: Dictionary, base_stat: String) -> void:
    """Ensure current stat doesn't exceed its _max capacity."""
    var max_stat = "%s_max" % base_stat
    if max_stat not in entity.stats:
        return  # No capacity defined
    
    var current = entity.stats.get(base_stat, 0.0)
    var max_value = get_effective_stat(entity, max_stat)
    
    entity.stats[base_stat] = clamp(current, 0.0, max_value)

static func validate_stat_pair(definitions: Dictionary) -> Array:
    """Return list of errors if stat pairs are invalid."""
    var errors = []
    
    for stat in definitions.get("stats", []):
        if stat.ends_with("_max"):
            var base_stat = stat.trim_suffix("_max")
            if base_stat not in definitions["stats"]:
                errors.append("Capacity stat '%s' missing base stat '%s'" % [stat, base_stat])
    
    return errors
```

---

## Summary

**Key Takeaways:**
1. ✅ Always define pairs: `health` AND `health_max`
2. ✅ Initialize both current and max on entities
3. ✅ Clamp current to max when max changes
4. ✅ Stack modifiers additively
5. ✅ Use `set_stats` when patching to avoid overwriting
6. ✅ Never allow negative max values
7. ✅ Test edge cases thoroughly

This system cleanly separates the "how much you have" from "how much you can have", preventing ambiguity and enabling robust stat management across all game systems.
