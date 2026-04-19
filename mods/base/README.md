# Base Starter Pack

A minimal **base game content pack** for Omni-Framework that follows the guide's `mods/base/` model instead of behaving like an add-on mod.

## What it is

This is a small self-contained starter dataset meant to help you validate the core data pipeline and major gameplay systems in a fresh project structure.

It includes:
- base definitions for currencies and stats
- a `base:player` entity with starter inventory and sockets
- a vendor NPC with trade, dialogue, sheet, and challenge interactions
- two connected locations (`base:hub_safehouse` and `base:test_hub`)
- a faction, task templates, quest, achievements, and small config defaults
- one simple DialogueBackend resource

## Install

Extract so the final path is:

`mods/base/`

## Notes

- This pack intentionally avoids custom assets so it stays small and easy to inspect.
- It is designed as a *starter/base scaffold*, not a content-rich game.
- If your current engine build has drifted from the guide, you may still need to adjust a few field names or route params.
