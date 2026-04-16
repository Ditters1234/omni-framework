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

## Always Paired Stats

**Rule:** If you define one, you MUST define the other.

Valid pairs in `definitions.json`:
```json
{
  "stats": [
    "health",
    "health_max",
    "mana",
    "mana_max",
    "stamina",
    "stamina_max",
    "rage",
    "rage_max"
  ]
}
```

**DO NOT CREATE:**
- ❌ `health` without `health_max`
- ❌ `mana_max` without `mana`
- ❌ Unpaired capacity stats

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

If an entity doesn't specify a stat, initialize from definitions with sensible defaults:

```gdscript
# In EntityLoader.gd
func initialize_entity_stats(entity: Dict) -> Dict:
    var stats = entity.get("stats", {})
    
    for stat_name in definitions["stats"]:
        if not stat_name in stats:
            # Default initialization
            if stat_name.ends_with("_max"):
                stats[stat_name] = 10  # Default max = 10
            else:
                if "%s_max" % stat_name in definitions["stats"]:
                    # This is a base stat with a capacity
                    stats[stat_name] = stats["%s_max" % stat_name]  # current = max
                else:
                    # Flat stat with no capacity
                    stats[stat_name] = 0
    
    return stats
```

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

### Integration Tests

- [ ] **Entity Load:** Entity with invalid stats corrected on load
- [ ] **Patch Load:** Patching entity stats updates correctly
- [ ] **Part Override:** Equipping new part with same stat modifier works
- [ ] **UI Display:** Character sheet shows correct current/max values
- [ ] **Economy:** Selling damaged part with health_max modifier prices correctly

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
