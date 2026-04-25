# Bounty Board

Adds the **Ironweld Collective**, a rival faction with a fortified outpost, a patrolling enforcer, bounty tasks, and a reputation-gated quest line.

## What this mod demonstrates

- **New faction**: The Ironweld Collective with reputation thresholds (hostile/neutral/friendly/allied), its own territory, and a roster of two NPCs.
- **Task routines (NPC patrol)**: Enforcer Voss walks a daily route between the Outpost and Market Row on a schedule. At tick 8 he travels to Market Row; at tick 16 he returns. He appears at whichever location he's currently at.
- **Inter-faction reputation dynamics**: The `debt_collection` bounty rewards Ironweld reputation but costs Threshold Syndicate reputation, creating a meaningful choice.
- **Reputation threshold quest objectives**: The `prove_yourself` quest requires reaching 40+ Ironweld reputation before advancing, demonstrating the `reputation_threshold` condition type.
- **Stat-check challenge on an NPC**: Voss has a sparring challenge (power >= 4) that rewards both credits and faction reputation.
- **Location patching with bidirectional connections**: The Outpost connects to both Market Row and the Warehouse, and both base locations are patched to connect back.
- **`map_position`**: The Outpost declares a world map position so it renders at a fixed location instead of the auto-layout.
- **`faction_id` on location**: The Outpost declares its faction, so the world map tints its node with the Ironweld color.

## Content added

| Type | ID | Description |
|---|---|---|
| Faction | `example:bounty_board:ironweld` | Ironweld Collective |
| Location | `example:bounty_board:outpost` | Ironweld Outpost |
| Entity | `example:bounty_board:handler_rin` | Handler Rin (contract dispatcher) |
| Entity | `example:bounty_board:enforcer_voss` | Enforcer Voss (patrolling enforcer) |
| Part | `example:bounty_board:ironweld_badge` | Ironweld Contractor Badge |
| Part | `example:bounty_board:shock_knuckles` | Shock Knuckles (melee weapon) |
| Part | `example:bounty_board:signal_scrambler` | Signal Scrambler (implant) |
| Task | `example:bounty_board:patrol_escort` | Escort convoy to Market Row |
| Task | `example:bounty_board:salvage_sweep` | Clear industrial corridors |
| Task | `example:bounty_board:debt_collection` | Collect debt in Undercity (hurts Syndicate rep) |
| Task | `example:bounty_board:voss_to_market` | Voss patrol leg (routine) |
| Task | `example:bounty_board:voss_to_outpost` | Voss patrol return (routine) |
| Quest | `example:bounty_board:prove_yourself` | Iron Proof |
| Achievement | `example:bounty_board:bounty_hunter` | Bounty Hunter |

## Gameplay flow

1. Discover the Ironweld Outpost (connected from Warehouse and Market Row).
2. Meet Handler Rin and pick up bounties from the task board.
3. Complete bounties to build Ironweld reputation. Watch out — debt collection hurts your Syndicate standing.
4. Encounter Enforcer Voss either at the Outpost or Market Row depending on time of day.
5. Once you hit 40+ Ironweld reputation, beat Voss in a sparring match (power >= 4) to complete the quest and earn your Ironweld Contractor Badge.

## Voss patrol schedule

| Tick | Action |
|---:|---|
| 8 | Travels from Outpost to Market Row |
| 16 | Returns from Market Row to Outpost |

Travel duration is resolved automatically from `LocationGraph` route costs.
