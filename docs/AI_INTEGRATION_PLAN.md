# Omni-Framework — AI Integration Plan

> **See also:** [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for the AI architecture overview, [`MODDING_GUIDE.md`](MODDING_GUIDE.md) for script hook patterns, and [`SYSTEM_CATALOG.md`](SYSTEM_CATALOG.md) for the `AIManager` autoload and provider catalog.

This document is a planning reference for the AI integration layer. It catalogs the consumer systems that will use `AIManager`, the new data schemas, modder-facing contracts, and phased work required to connect the existing LLM infrastructure to gameplay.

It is written to be revised. Treat it as the current best thinking, not a frozen spec.

Implementation status update: Phases 2 and 3 are now in place. `systems/ai/ai_chat_service.gd` provides persona lookup, placeholder resolution, bounded history, context assembly, response validation, fallback selection, and a debug snapshot surface. `DialogueBackend` and `dialogue_screen.gd` now support `ai_mode` handoff (`hybrid`, `freeform`), Dialogue Manager callable hooks (`ai_chat_open`, `ai_chat_close`, `can_open_ai_chat`), routed streaming via `GameEvents.ai_token_received`, and the base Kael interaction as the reference implementation.

Decisions this document assumes:

- **AI is opt-in and gracefully degraded.** Every consumer guards with `AIManager.is_available()`. When AI is disabled or unavailable, the game falls back to static content with zero runtime errors or missing UI.
- **Dialogue is the first integration point.** It has the highest modder impact and the lowest architectural risk — it wires into an existing backend (`DialogueBackend`) and an existing addon (Dialogue Manager).
- **The provider layer is complete.** `AIManager`, `openai_provider.gd`, `anthropic_provider.gd`, and `nobodywho_provider.gd` are implemented and tested. This plan consumes them; it does not extend them.
- **All AI configuration is engine-owned.** Provider selection, API keys, model paths, and system prompts live in `user://settings.cfg` via `AppSettings`, not in mod JSON. Mods supply persona data and prompt templates; the engine owns the connection.

---

## 1. Guiding Principles

The AI integration follows the same layered contract as the rest of the engine:

```
Mod persona data → Prompt builder → AIManager → Provider → Response parser → Game system
```

What each layer is responsible for:

| Layer | Responsibility | What it must not do |
|---|---|---|
| **Mod persona data** | Define NPC personalities, prompt templates, response constraints via JSON | Reference API keys, model names, or provider-specific settings |
| **Prompt builder** | Assemble a complete prompt from persona + game context + conversation history | Cache responses, manage provider state |
| **AIManager** | Route the prompt to the configured provider, manage request lifecycle | Know what the prompt is for — it is a generic pipe |
| **Provider** | Send the request, parse the wire format, return text | Know about game state, NPCs, or dialogue systems |
| **Response parser** | Validate, extract, and constrain the LLM output for the consuming system | Call the provider directly — always go through AIManager |
| **Game system** | Consume the parsed response and update state | Assume AI is available — always guard first |

Implications this document respects:

- Adding a new AI consumer means adding a prompt builder, a response parser, and wiring them into an existing system — not modifying `AIManager` or the providers.
- Modders extend AI behavior by writing persona JSON and prompt templates in their mod's `data/` folder, plus optional script hooks. They never touch provider code.
- Every AI consumer must produce identical gameplay when AI is disabled. The static fallback is the baseline; AI enhances it.

---

## 2. Current State Summary

### Implemented

- `AIManager` (autoload) — provider abstraction, request tracking, streaming, debug snapshots. Boots last in the autoload sequence.
- Three providers: `openai_provider.gd` (covers OpenAI, Ollama, LM Studio), `anthropic_provider.gd` (Anthropic Messages API), `nobodywho_provider.gd` (embedded local LLM via GDExtension).
- `GameEvents` signals: `ai_response_received`, `ai_token_received`, `ai_error`.
- `AppSettings` AI configuration block in `user://settings.cfg` (provider selection, API key, model, max tokens, system prompt).
- Settings screen AI section for configuring provider and connection parameters at runtime.
- Debug overlay AI panel showing provider state, recent requests, and error history.

### Not yet implemented

- ~~No game system consumes `AIManager` for gameplay yet.~~ `DialogueBackend` AI mode implemented in Phase 3.
- ~~No mod data schema for AI persona definitions.~~ Implemented in Phase 1.
- ~~No prompt builder or response parser infrastructure.~~ Implemented in Phase 2.
- No LimboAI behavior tree nodes for AI-driven NPC decisions.
- No script hook patterns for AI-generated content.

---

## 3. AI Consumer Catalog

Target end state once this plan is fully executed. Three consumer layers plus supporting infrastructure.

### 3.1 Dialogue Layer — AI-enhanced NPC conversation

| System | Status | Purpose |
|---|---|---|
| `AIChatService` | ✅ Implemented (Phase 2) | Prompt assembly, history management, response parsing for NPC conversations |
| `DialogueBackend` AI mode | ✅ Implemented (Phase 3) | Hybrid dialogue: scripted `.dialogue` trees hand off to freeform AI chat and back |
| `dialogue_screen.gd` streaming | ✅ Implemented (Phase 3) | Routed streaming display in the dialogue UI driven by `GameEvents.ai_token_received` |

The dialogue layer is the primary integration. It connects `AIManager` to the existing `DialogueBackend` and Dialogue Manager addon, enabling NPCs to hold freeform conversations informed by game state while retaining scripted branching for plot-critical moments.

### 3.2 Behavior Layer — AI-driven NPC decisions

| System | Status | Purpose |
|---|---|---|
| `BTActionAIQuery` | Planned (Phase 5) | LimboAI action node: send a decision prompt, parse the response into a blackboard variable |
| `BTConditionAICheck` | Planned (Phase 5) | LimboAI condition node: ask the LLM a yes/no gating question |

The behavior layer wires `AIManager` into LimboAI behavior trees so NPCs can make context-aware decisions — adjusting vendor prices based on reputation, choosing dialogue topics dynamically, or selecting patrol routes based on world state. These nodes are optional leaves in a BT; the tree always has a static fallback branch.

### 3.3 World Layer — AI-generated dynamic content

| System | Status | Purpose |
|---|---|---|
| AI narration hook | Planned (Phase 6) | Script hook that generates event narration for the `EventLogBackend` |
| AI task flavor hook | Planned (Phase 6) | Script hook that enhances `TaskProviderBackend` descriptions with contextual flavor text |
| AI lore hook | Planned (Phase 7) | Script hook that generates optional lore blurbs for `EntitySheetBackend` and part inspection |

The world layer uses script hooks to inject AI-generated flavor text into existing backend screens. All hooks produce supplementary content alongside the static baseline — never replacing it.

### 3.4 Do we really need three separate layers?

Reasonable question. All three layers ultimately call `AIManager.generate_async()` with a prompt and parse a response. They could theoretically collapse into a single "AI script hook" pattern.

The argument for separation: each layer has fundamentally different prompt shapes, response constraints, and failure modes. Dialogue needs conversation history and streaming. Behavior needs constrained enum output and fast turnaround. World generation needs long-form prose with no time pressure. Collapsing them would produce a single service with too many responsibilities and configuration knobs.

The argument against separation: more code surface, more things to test, more things for modders to learn.

**Recommendation: start with the dialogue layer as a focused, well-tested vertical. Extract shared prompt-building utilities into a helper as patterns emerge. Build behavior and world layers only after dialogue is stable.** This avoids premature abstraction while keeping the door open for consolidation later.

---

## 4. New Data Schemas Required

### 4.1 AI Persona Schema

Lives in `mods/<author>/<mod>/data/ai_personas.json`. Loaded by a new `AIPersonaRegistry` under `systems/loaders/`. Registered on `DataManager` as `get_ai_persona(id)` / `query_ai_personas(...)`.

```json
{
  "ai_personas": [
    {
      "persona_id": "base:kael_persona",
      "display_name": "Kael",
      "system_prompt_template": "You are {display_name}, {description}. You are located at {location_name}. Your faction is {faction_name} and your reputation with the player is {reputation_tier}.",
      "personality_traits": ["pragmatic", "calm", "trustworthy"],
      "speech_style": "Short, direct sentences. Avoids slang. Occasionally dry humor.",
      "knowledge_scope": ["threshold_syndicate", "contracts", "market_row", "local_politics"],
      "forbidden_topics": ["personal_history"],
      "response_constraints": {
        "max_sentences": 4,
        "tone": "conversational",
        "always_in_character": true
      },
      "fallback_lines": [
        "I don't have anything else to say about that.",
        "Let's focus on business.",
        "You'd have to ask someone else about that."
      ],
      "tags": ["fixer", "syndicate"]
    }
  ],
  "patches": []
}
```

Schema notes:

- `system_prompt_template` uses `{placeholder}` tokens that the prompt builder resolves from `GameState` and `DataManager` at call time. Supported tokens are defined and documented in `AIChatService`.
- `personality_traits` and `speech_style` are injected into the system prompt to shape the LLM's output voice. They are descriptive strings, not engine-evaluated values.
- `knowledge_scope` is an array of topic tags. The prompt builder uses these to assemble a "things this NPC knows about" block from available game data, preventing the LLM from hallucinating information the character shouldn't have.
- `forbidden_topics` causes the prompt builder to include an explicit instruction to avoid or deflect these subjects.
- `response_constraints` gives the prompt builder output-shaping instructions (sentence count, tone). These are prompt engineering directives, not hard runtime truncation.
- `fallback_lines` are used when AI is unavailable or the response fails validation. The dialogue system picks one at random. These ensure the NPC always has something to say.
- Persona IDs follow the standard `author:mod:name` namespacing. The base mod's personas use the `base:` prefix.

### 4.2 Entity-to-Persona Binding

Personas bind to entities via a new optional field on the entity template in `entities.json`:

```json
{
  "entity_id": "base:npc_fixer",
  "display_name": "Kael",
  "ai_persona_id": "base:kael_persona",
  "...": "..."
}
```

When `ai_persona_id` is present and `AIManager.is_available()` returns true, the dialogue system offers AI chat as an interaction mode. When absent or when AI is disabled, the entity uses only its scripted `.dialogue` files — no behavioral change.

### 4.3 AI Prompt Templates (optional, Phase 6+)

For the world generation layer, modders can supply prompt templates in `data/ai_templates.json`:

```json
{
  "ai_templates": [
    {
      "template_id": "base:task_flavor",
      "purpose": "task_description",
      "prompt_template": "Write a one-sentence mission briefing for a {task_type} task in {location_name}. The employer is {faction_name}. Reward: {reward_summary}. Keep it under 20 words.",
      "fallback": "{display_name}"
    }
  ]
}
```

These are deferred to Phase 6 and described here for schema completeness only.

---

## 5. Prompt Builder Architecture

The prompt builder is the bridge between game data and LLM input. It assembles complete prompts from persona definitions, game context, and conversation history.

### 5.1 `AIChatService`

A new runtime helper (not an autoload) that manages prompt assembly and conversation state for the dialogue layer. Instantiated by `DialogueBackend` when AI mode is active.

Responsibilities:

- Resolve `{placeholder}` tokens in persona system prompts from `GameState` and `DataManager`.
- Maintain per-NPC conversation history (bounded to a configurable window, default 20 turns).
- Assemble the context dictionary that `AIManager.generate_async()` expects: `{ "system_prompt": "...", "history": [...] }`.
- Validate responses against persona constraints (length, character-breaking content).
- Provide fallback lines when the AI response is empty, times out, or fails validation.

### 5.2 Context Assembly

The prompt builder resolves these token categories from game state:

| Token | Source | Example resolution |
|---|---|---|
| `{display_name}` | Entity template `.display_name` | `"Kael"` |
| `{description}` | Entity template `.description` | `"A soft-spoken fixer who operates..."` |
| `{location_name}` | Current location template `.display_name` | `"Market Row"` |
| `{faction_name}` | Entity's primary faction `.display_name` | `"Threshold Syndicate"` |
| `{reputation_tier}` | Player reputation with NPC's faction | `"Trusted"` |
| `{player_name}` | Player entity `.display_name` | `"Operative"` |
| `{player_stats}` | Formatted stat summary | `"power: 3, charisma: 2"` |
| `{time_of_day}` | `TimeKeeper` current period | `"evening"` |
| `{active_quests}` | Player's active quest names | `"Deliver the package, Find the warehouse"` |
| `{knowledge_block}` | Assembled from `knowledge_scope` tags | Context-specific world data |

Unrecognized tokens are left as-is with a warning logged. Missing data resolves to empty strings.

### 5.3 Response Validation

Before delivering a response to the dialogue screen, `AIChatService` runs these checks:

1. **Non-empty** — empty responses trigger fallback.
2. **Length check** — responses exceeding `max_sentences × 2` (generous buffer) are truncated at the last complete sentence within bounds.
3. **Character consistency** — if `always_in_character` is set, the response is checked for first-person references that break the NPC voice (e.g. "As an AI language model..."). Failures trigger fallback.
4. **Content safety** — responses containing content from `forbidden_topics` trigger a deflection fallback line.

Validation is best-effort heuristic, not a guarantee. The prompt engineering in the system prompt is the primary control surface.

---

## 6. DialogueBackend AI Mode

The highest-impact integration. This section describes how the existing `DialogueBackend` gains an AI conversation mode alongside its current scripted `.dialogue` file support.

### 6.1 Interaction Modes

An NPC interaction with `backend_class: "DialogueBackend"` gains a new optional field:

```json
{
  "tab_id": "kael_talk",
  "label": "Talk",
  "backend_class": "DialogueBackend",
  "dialogue_resource": "res://mods/base/dialogue/kael.dialogue",
  "dialogue_start": "start",
  "ai_mode": "hybrid"
}
```

| `ai_mode` | Behavior |
|---|---|
| absent or `"disabled"` | Current behavior — scripted `.dialogue` only. No change. |
| `"hybrid"` | Scripted `.dialogue` is the primary flow. At designated branch points (via a Dialogue Manager function call), the system hands off to AI freeform chat. The player can return to scripted branches via an explicit "back to topics" option. |
| `"freeform"` | The interaction opens directly into AI chat with no scripted preamble. The persona's `fallback_lines` are used if AI is unavailable. A "topics" button can optionally open the scripted `.dialogue` tree. |

When `ai_mode` is set but `AIManager.is_available()` returns false, the interaction falls back to the scripted `.dialogue` resource with no visible error. If neither `dialogue_resource` nor `ai_persona_id` (on the entity) is present, the interaction is invalid and fails contract validation at load time.

### 6.2 Hybrid Handoff via Dialogue Manager

The Dialogue Manager addon supports custom function calls from `.dialogue` files. The handoff to AI chat uses a new callable registered during `DialogueBackend` initialization:

```
~ start
Kael: You look new. That's fine — everyone starts somewhere.
- What's the Threshold Syndicate?
    => about_syndicate
- [if AIManager.is_available()] Talk freely
    do ai_chat_open()
- Just passing through.
    => END
```

`ai_chat_open()` signals the dialogue screen to transition from the scripted balloon to the AI chat interface. The AI chat interface shows:

- The NPC portrait and name (existing `entity_portrait` component).
- A streaming text display for the NPC's AI-generated response.
- A text input field for the player's freeform message.
- A "Back to topics" button that returns to the scripted `.dialogue` tree at a designated re-entry point.

`ai_chat_close()` (called from the "Back to topics" button) signals the dialogue screen to transition back to the scripted view. The scripted `.dialogue` tree resumes from a configurable re-entry title (default: `start`).

### 6.3 Conversation History Management

`AIChatService` maintains a rolling conversation history per NPC per session:

- History is an array of `{ "role": "user", "content": "..." }` and `{ "role": "assistant", "content": "..." }` entries, matching the format expected by all three providers.
- The history window defaults to 20 entries (configurable via `AppSettings`). Oldest entries are evicted when the window is exceeded.
- History is not persisted to save files. Each game session starts fresh. If save persistence is needed later, it can be added to `SaveManager`'s A2J registration — the history format is already JSON-serializable.
- When the player returns to scripted dialogue and then re-enters AI chat, the previous history is retained for the duration of the session.

### 6.4 Streaming Display

When `ai_mode` is active, the dialogue screen subscribes to `GameEvents.ai_token_received` filtered by the current request ID. Tokens are appended to a `RichTextLabel` with a typewriter effect (configurable speed via `AppSettings`). The text input is disabled while generation is in progress and re-enabled on `ai_response_received` or `ai_error`.

The streaming display reuses the existing dialogue screen layout — NPC portrait on the left, text on the right, response area replacing the branching-option list. No new scene is required; the screen conditionally shows the AI chat widgets or the scripted dialogue widgets based on the current mode.

---

## 7. LimboAI Behavior Tree Nodes

Two new BT action/condition nodes that let behavior trees make LLM-informed decisions.

### 7.1 `BTActionAIQuery`

A LimboAI `BTAction` that sends a prompt to `AIManager` and writes the parsed response to the blackboard.

```gdscript
## BTActionAIQuery — Queries AIManager and writes the result to the blackboard.
## Prompt is assembled from a template string with blackboard variable substitution.
## Response is parsed as one of: "text" (raw string), "enum" (constrained choice),
## or "json" (parsed dictionary). Parse failures return FAILURE status.
extends BTAction

@export var prompt_template: String = ""
@export var result_variable: StringName = &"ai_result"
@export var response_format: String = "text"  # "text", "enum", "json"
@export var enum_options: PackedStringArray = []
@export var timeout_seconds: float = 30.0
@export var fallback_value: String = ""
```

Usage in a behavior tree: an NPC vendor could use `BTActionAIQuery` to decide whether to offer a discount based on the player's reputation and recent purchase history. The prompt template references blackboard variables like `{player_reputation}` and `{recent_purchases}`, and `response_format: "enum"` with `enum_options: ["full_price", "small_discount", "big_discount"]` constrains the output to a branch-friendly value.

If `AIManager.is_available()` returns false or the request times out, the node returns `FAILURE` and the BT follows its static fallback branch. The `fallback_value` is written to the blackboard so downstream nodes can still read a default.

### 7.2 `BTConditionAICheck`

A LimboAI `BTCondition` that asks a yes/no question and succeeds or fails based on the response.

```gdscript
## BTConditionAICheck — Asks AIManager a yes/no question.
## Succeeds if the response indicates "yes", fails otherwise.
## Falls back to a configurable default when AI is unavailable.
extends BTCondition

@export var prompt_template: String = ""
@export var default_result: bool = false
@export var timeout_seconds: float = 10.0
```

The prompt builder appends "Respond with only YES or NO." to the assembled prompt. Response parsing is case-insensitive and strips whitespace. Any response not clearly "yes" resolves to the `default_result`.

### 7.3 Placement in BT Architecture

These nodes are optional leaves. A well-designed behavior tree never depends on AI availability for core functionality:

```
Selector
├── Sequence [AI-enhanced path]
│   ├── BTConditionAICheck: "Should I offer a discount?"
│   └── BTActionSetDiscount (from blackboard)
└── Sequence [static fallback]
    └── BTActionDefaultPricing
```

The AI path is tried first. If the condition fails (AI unavailable, timeout, or "no"), the selector falls through to the static branch. This mirrors the hybrid dialogue pattern: AI enhances, static delivers.

---

## 8. World Generation Script Hooks

Script hooks that inject AI-generated content into existing backend screens. All hooks extend `ScriptHook` and follow the existing mod hook lifecycle.

### 8.1 Event Narration Hook

Listens to key `GameEvents` signals and generates short narrative text for the `EventLogBackend`.

```gdscript
## Generates AI narration for significant game events.
## Writes a "narration" field into the event history entry.
extends ScriptHook

func on_quest_completed(quest_id: String) -> void:
    if not AIManager.is_available():
        return
    var quest := DataManager.get_quest(quest_id)
    var prompt := "Write a one-sentence dramatic summary of completing the quest '%s'. Keep it under 15 words." % quest.get("display_name", quest_id)
    var narration := await AIManager.generate_async(prompt)
    if not narration.is_empty():
        GameEvents.emit_dynamic("event_narrated", [quest_id, narration])
```

The `EventLogBackend` checks for an optional `narration` field on event entries and displays it below the standard event text when present.

### 8.2 Task Flavor Hook

Enhances task descriptions in `TaskProviderBackend` with contextual flavor text generated at display time.

The hook fires when the task provider screen builds its view model. It takes the static task template and generates a one-sentence contextual briefing. The flavor text is appended below the static description, visually distinguished (e.g. italic or muted color). If AI is unavailable or the request fails, the static description displays alone.

### 8.3 Lore Generation Hook

Generates optional lore blurbs for `EntitySheetBackend` and part inspection views. The hook takes the entity or part template and generates a short paragraph of in-world flavor text. The lore is cached per template ID for the session to avoid redundant API calls.

---

## 9. Config and Settings Integration

### 9.1 Engine-Owned AI Settings (`user://settings.cfg`)

AI provider configuration is engine-owned and lives in `AppSettings`. The settings screen already has an AI section. No changes to the ownership model are needed — the providers read from `AppSettings` at boot time via `AIManager.initialize()`.

New settings added by this plan:

| Setting | Type | Default | Purpose |
|---|---|---|---|
| `ai.chat_history_window` | int | 20 | Maximum conversation history entries per NPC |
| `ai.streaming_speed` | float | 0.03 | Seconds between typewriter characters in dialogue |
| `ai.bt_query_timeout` | float | 30.0 | Default timeout for BT AI query nodes |
| `ai.enable_world_gen` | bool | false | Master toggle for world generation hooks |
| `ai.cache_lore` | bool | true | Cache AI-generated lore blurbs for the session |

### 9.2 Mod-Owned AI Content (`config.json`)

Mods do not configure providers. They supply persona data and prompt templates via `ai_personas.json` and `ai_templates.json` in their `data/` folder. The existing two-phase mod loading pipeline (additions then patches) applies — Mod B can patch Mod A's persona definitions.

A mod's `config.json` gains an optional `ai` section for mod-level AI defaults:

```json
{
  "ai": {
    "default_persona_id": "base:generic_npc",
    "narration_enabled": true,
    "task_flavor_enabled": true,
    "lore_enabled": true
  }
}
```

These are content toggles, not provider settings. They let a mod author indicate whether their content is designed to work with AI enhancement. The engine respects them only when AI is also enabled at the engine level.

---

## 10. Phased Implementation Plan

### Phase 1 — AI Persona Data Pipeline (~2 days)

Current status: complete. `AIPersonaRegistry`, `DataManager` integration (`get_ai_persona`, `has_ai_persona`, `query_ai_personas`), entity-to-persona binding via `ai_persona_id`, persona shape validation, cross-registry reference validation, base mod persona (`base:kael_persona` → `base:npc_fixer`), modding guide documentation, and unit/content tests are all in place.

1. Create `systems/loaders/ai_persona_registry.gd` following the existing loader pattern (`PartsRegistry`, `EntityRegistry`). Done.
2. Register `get_ai_persona(id)` and `query_ai_personas(...)` on `DataManager`. Done.
3. Add `ai_persona_id` as an optional validated field on entity templates in `EntityRegistry`. Validation: if present, must reference a valid persona ID after all mods are loaded. Done.
4. Ship a base mod persona (`base:kael_persona`) wired to `base:npc_fixer`. Done.
5. Add `ai_personas.json` to the mod data spec in `MODDING_GUIDE.md`. Done.

Deliverable: persona data loads through the standard mod pipeline, is queryable via `DataManager`, and validates at boot time.

### Phase 2 — AIChatService (~3 days)

Current status: complete. `systems/ai/ai_chat_service.gd` provides persona-aware prompt assembly with `{placeholder}` token resolution, bounded role-tagged conversation history, response validation (length, character consistency, forbidden topic deflection, fallback selection), context assembly for `AIManager`, and a debug snapshot surface. Covered by `tests/unit/test_ai_chat_service.gd` with a fake provider test double.

1. Create `systems/ai/ai_chat_service.gd` as a `RefCounted` helper (not an autoload). Done.
2. Implement `{placeholder}` token resolution from `GameState` and `DataManager`. Done.
3. Implement conversation history management (bounded window, role-tagged entries). Done.
4. Implement response validation (length, character consistency, fallback selection). Done.
5. Unit tests: token resolution with known fixtures, history windowing, validation edge cases (empty response, overlong response, out-of-character detection). Done.

Deliverable: `AIChatService` can assemble a complete prompt from a persona + game state and validate the response, independent of any UI.

### Phase 3 — Dialogue Backend AI Mode (~4–5 days)

Current status: complete. `DialogueBackend` accepts optional `ai_mode`, configures `AIChatService` from the speaker entity persona, and exposes AI availability to the routed screen. `dialogue_screen.gd` now passes itself into Dialogue Manager as an extra game state, supports `ai_chat_open()` / `ai_chat_close()` handoff, streams provider output through `GameEvents.ai_token_received`, and can return from AI chat to scripted topics. The base Kael interaction now ships with `ai_mode: "hybrid"` and authored `ai_chat_open()` branch options, with coverage in `tests/unit/test_dialogue_ai_mode.gd`.

1. Add `ai_mode` to `DialogueBackend`'s contract registration (optional field, values: `"hybrid"`, `"freeform"`). Done.
2. Wire `DialogueBackend` to instantiate `AIChatService` when `ai_mode` is set. Done.
3. Register `ai_chat_open()` and `ai_chat_close()` as Dialogue Manager callable functions on the routed dialogue screen, with `can_open_ai_chat()` for authored branch gating. Done.
4. Extend `dialogue_screen.gd` with the AI chat panel: streaming text display, text input, "Back to topics" button. Done.
5. Wire streaming display to `GameEvents.ai_token_received` filtered by request ID. Done.
6. Add `ai_mode: "hybrid"` to Kael's talk interaction in `entities.json` as the reference implementation. Done.
7. Update the base mod's `kael.dialogue` with the `ai_chat_open()` branch option. Done.
8. Integration test: open dialogue, enter AI chat, send a message, receive a streaming response, return to scripted dialogue. Done (`tests/unit/test_dialogue_ai_mode.gd`).
9. Smoke test: open dialogue with AI disabled — hybrid branch is hidden, scripted dialogue works normally. Done (`tests/unit/test_dialogue_ai_mode.gd`).

Deliverable: a player can talk to Kael using both scripted branches and freeform AI conversation in the same interaction.

### Phase 4 — Polish and Modder Surface (~2–3 days)

Current status: complete. The base mod now ships `base:theta_persona` bound to Quartermaster Theta, and Theta's talk interaction demonstrates `ai_mode: "freeform"` while still keeping authored dialogue as the disabled-AI fallback. `MODDING_GUIDE.md` now documents persona tokens and authoring guidance, the settings screen exposes `ai.chat_history_window` and `ai.streaming_speed`, and the debug overlay surfaces the active `AIChatService` snapshot. Runtime hardening also landed for hidden failed responses, unique request IDs across AI boot cycles, bounded player input length, and stream-state cleanup on close/re-entry.

1. Add a second NPC AI persona (`base:theta_persona`) wired to Quartermaster Theta, demonstrating a different personality and speech style. Done.
2. Add `ai_mode: "freeform"` to Theta's talk interaction to demonstrate the freeform-only mode. Done.
3. Update `MODDING_GUIDE.md` with a full AI persona authoring guide: schema reference, prompt template tokens, personality tuning tips, fallback line guidelines. Done.
4. Add debug overlay panel for `AIChatService`: current persona, conversation history, last prompt sent, last response received, validation results. Done.
5. Add `AppSettings` UI controls for `ai.chat_history_window` and `ai.streaming_speed` in the settings screen. Done.
6. Edge case hardening: rapid re-entry to AI chat, switching NPCs mid-conversation, provider errors during streaming, very long player inputs. Done for the current dialogue scope.

Deliverable: two NPCs with distinct AI personalities, modder documentation, debug tooling, and hardened edge cases.

### Phase 5 — LimboAI Behavior Tree Nodes (~3–4 days)

AI-informed NPC decision-making via custom BT nodes.

1. Create `systems/ai/bt_action_ai_query.gd` extending LimboAI's `BTAction`.
2. Create `systems/ai/bt_condition_ai_check.gd` extending LimboAI's `BTCondition`.
3. Implement prompt template resolution from blackboard variables.
4. Implement response parsing: `"text"` (raw), `"enum"` (constrained choice from options list), `"json"` (parsed dictionary).
5. Implement timeout handling and fallback value writing.
6. Unit tests: enum parsing with edge cases (extra whitespace, casing, partial matches), JSON parsing with malformed input, timeout behavior.
7. Create a reference behavior tree for Kael that uses `BTActionAIQuery` to dynamically choose a greeting based on player reputation and time of day, with a static fallback.
8. Integration test: Kael's BT runs the AI query path when AI is available and falls through to static when it isn't.
9. Update `MODDING_GUIDE.md` with BT AI node documentation and usage examples.

Deliverable: modders can add AI decision points to behavior trees with graceful static fallback.

### Phase 6 — World Generation Hooks (~3 days)

AI-generated content injected into existing backend screens via script hooks.

1. Create `mods/base/scripts/ai_narration_hook.gd` extending `ScriptHook`. Wire to `quest_completed`, `location_changed`, and `day_advanced` signals.
2. Create `mods/base/scripts/ai_task_flavor_hook.gd`. Wire to `TaskProviderBackend`'s view model assembly.
3. Add `event_narrated` to `GameEvents` signal catalog.
4. Extend `EventLogBackend` view model to display optional narration text.
5. Extend `TaskProviderBackend` view model to display optional AI flavor text below static descriptions.
6. Add `ai_templates.json` schema and `AITemplateRegistry` loader.
7. Add `ai.enable_world_gen` toggle to `AppSettings` and settings screen.
8. Tests: hooks produce no errors when AI is disabled, narration text appears in event log when enabled.

Deliverable: the event log and task board gain contextual AI-generated flavor text when AI is enabled.

### Phase 7 — Lore Generation and Session Caching (~2 days)

AI-generated lore blurbs for entity and part inspection, with session-level caching.

1. Create `mods/base/scripts/ai_lore_hook.gd`. Wire to `EntitySheetBackend` and part detail panel view model assembly.
2. Implement session-level lore cache keyed by template ID. Cache is an in-memory dictionary on `AIChatService` (or a dedicated `AILoreCache` helper), cleared on new game or load.
3. Extend `EntitySheetBackend` view model with an optional `ai_lore` field.
4. Extend `part_detail_panel` to display optional lore text below the static description.
5. Tests: lore cache hit avoids redundant API calls, cache miss generates and stores, cache clears on new game.

Deliverable: inspecting an NPC or part shows optional AI-generated lore that persists for the session.

### Phase 8 — Advanced Features (deferred)

Not built in this plan. When needed, they follow the same prompt-builder + response-parser + consumer pattern.

Candidates for future phases:

- **Conversation memory persistence** — saving AI chat history to save files via A2J. Requires registering conversation history as a serializable type.
- **Multi-NPC conversations** — AI-driven group dialogue where multiple NPCs respond in sequence. Requires prompt orchestration and turn management.
- **Procedural quest generation** — AI generates quest templates at runtime from world state. Requires output validation against `QuestRegistry` schema and careful prompt engineering to produce valid JSON.
- **Player journal** — AI summarizes the player's session into a readable journal entry. Lower complexity, high flavor value.
- **Voice synthesis integration** — TTS for AI-generated dialogue. Provider-dependent; would require a new provider interface method.

None of these contradict anything in this plan. They slot in as new consumers of `AIManager` with their own prompt builders and parsers.

---

## 11. Testing and Verification

Every phase produces testable surface. Tests land alongside implementation, not as a follow-up.

### 11.1 Unit Tests (GUT)

- `AIPersonaRegistry`: persona loading, patch application, reference validation (persona references valid entity IDs where bound).
- `AIChatService`: token resolution with known fixtures, history windowing, response validation (empty, overlong, out-of-character, forbidden topic).
- `BTActionAIQuery`: enum parsing edge cases, JSON parsing with malformed input, timeout fallback value writing.
- `BTConditionAICheck`: yes/no parsing with edge cases (whitespace, casing, "YES.", "y", "nah"), default result on failure.

### 11.2 Integration Tests

- Full mod load with a fixture mod that declares an AI persona, binds it to an entity, and configures a `DialogueBackend` interaction with `ai_mode: "hybrid"` — must validate at load time.
- Dialogue flow: open NPC dialogue → enter AI chat → send message → receive response → return to scripted tree → re-enter AI chat (history retained).
- AI disabled flow: same interaction with `AIManager` disabled — hybrid branch hidden, scripted dialogue works normally, no runtime errors.
- BT integration: behavior tree with AI query node runs with a mock provider, writes expected blackboard value, falls through to static on mock failure.

### 11.3 Smoke Tests

- GUT scene runner opens dialogue screen with AI mode enabled using a test provider stub — no `push_error` during streaming.
- World generation hooks fire on `quest_completed` and `location_changed` with AI disabled — no errors, no visible change.
- Settings screen AI section renders and persists values correctly.

### 11.4 Debug Surfaces

Per `PROJECT_STRUCTURE.md §Debug And Test Tooling`, every new system gets a debug inspection surface. Extend the existing debug overlay with:

- **AI Chat panel**: current persona ID, conversation history (scrollable), last assembled system prompt, last request/response pair, validation result.
- **AI BT panel**: last query prompt, last parsed result, current blackboard AI variables.
- **AI World Gen panel**: narration cache contents, task flavor cache, lore cache, generation count and error count.

---

## 12. Open Questions

Items this plan cannot resolve without more information from the project owner.

**Q1. Should AI conversation history persist across save/load?**

Current recommendation: no. History is session-scoped and cleared on new game or load. Persisting it requires A2J registration of a new type and increases save file size proportionally to conversation length. Defer until a modder requests it.

**Q2. Should the player's text input be freeform or offer suggested prompts?**

Current recommendation: freeform with optional suggested prompts. The AI chat input is a `LineEdit` with a "send" button. Below it, 2–3 contextual suggestions are generated from the NPC's `knowledge_scope` (e.g. "Ask about contracts", "Ask about the Syndicate"). The player can tap a suggestion or type freely. Suggestions avoid the blank-page problem without constraining conversation.

**Q3. Should AI-generated text be visually distinguished from authored text?**

Current recommendation: yes, subtly. AI-generated text in the event log, task board, and entity sheet should use a slightly muted style or a small indicator (e.g. a sparkle icon or italic formatting) so players and modders can tell what's authored vs. generated. The dialogue screen does not distinguish — the NPC is "speaking" regardless of source.

**Q4. What is the token/cost budget for AI calls?**

This plan does not impose hard limits. The `response_constraints.max_sentences` field on personas is the primary cost control for dialogue. BT queries use short prompts and expect short responses. World generation hooks use one-sentence prompts. The engine-owned `max_tokens` setting in `AppSettings` is the global ceiling. Modders should be advised to keep prompts concise and response constraints tight, especially for behavior tree queries where latency matters.

**Q5. Should NobodyWho (local) be the recommended default for shipped games?**

Current recommendation: yes for offline/privacy-sensitive games, no as a universal default. NobodyWho runs in-process with no API key required, but it needs a `.gguf` model file (hundreds of MB to several GB) and has lower output quality than cloud providers for most persona work. The settings screen should present all three providers neutrally and let the player choose. The base mod's personas should be tested against all three providers to ensure reasonable output quality across the board.
