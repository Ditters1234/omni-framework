# Fae Lineage

This addon adds a small social transformation line and a Student Union relationship path.

## What This Teaches

- `data/parts.json`: adding a second transformation lineage with social/perceptive strengths and `normalcy` costs.
- `data/activities.json`: social activities with outcome branches gated by `charisma`, `perception`, and `normalcy`.
- `data/entities.json`: an NPC interaction that opens authored dialogue and a stat-gated challenge interaction that starts a quest.
- `dialogue/lark.dialogue`: a simple authored Dialogue Manager tree. Stat and flag gating currently lives in JSON conditions, where Omni's `ConditionEvaluator` supports it directly.
- `data/quests.json`: a relationship path driven by activity history and reputation/flag rewards.

## Play Pattern

Buy and equip fae parts from the normal catalog flow, then visit Lark in the Student Union. Fae builds make social tells and glamour easier to read, but low `normalcy` can turn ordinary social space into a stress source.

## Assets

This addon includes local placeholder sprites and sounds under `assets/`. They are copied from current Vanguard base placeholders while final fae art and audio are still in progress.
