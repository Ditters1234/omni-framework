# Omni Activity & Schedule Systems - Clean Implementation and Action Plan

## 0. Agent Usage Notes

This document is the working implementation contract for activity and calendar work. Keep it easy for agents to search, patch, and resume.

Formatting rules for this document:

- Use ASCII punctuation only.
- Keep headings stable and numbered.
- Prefer simple lists over decorative diagrams.
- Keep code blocks fenced with explicit language tags.
- Mark checklist items as complete only after the code, tests, and current-state docs are updated.
- Do not add historical notes, changelog language, or "future cleanup" commentary outside `docs/TODO/`.

Agent workflow:

1. Read `AGENTS.md` instructions, then this section, then the phase being implemented.
2. Read the relevant current-state docs before editing architecture: `docs/PROJECT_STRUCTURE.md`, `docs/SYSTEM_CATALOG.md`, `docs/modding_guide.md`, `docs/SAVE_SCHEMA_AND_MIGRATION.md`, and any phase-specific docs.
3. Implement one coherent phase or sub-phase at a time.
4. Update this plan's checklist as work lands.
5. Update base `docs/` files so they describe current behavior, not history.
6. Run focused tests for the touched systems and record any test gaps in the final response.

Search anchors:

- `Phase 1 - Time foundation`
- `Phase 2 - Activity loading`
- `Phase 3 - Activity history and save/load`
- `Phase 6 - Activity execution core`
- `Phase 12 - Activity board UI`
- `Phase 14 - Documentation alignment`
- `Definition of Done`

Current implementation status: Phase 1 through Phase 11 complete; Phase 12 is next. Phase 9 was completed early because activity execution uses the weighted choice helper and activity outcome dispatch.

## 1. Purpose

Implement two tightly integrated systems for Omni:

1. **Activity System** - data-authored, player-facing actions that represent an intentional use of time.
2. **Schedule / Calendar Projection** - read-only UI and backend projections that show when activities are available across day, range, week, and month views.

The implementation must integrate cleanly with existing Omni systems, especially:

- `DataManager`
- `GameState`
- `SaveManager`
- `TimeKeeper`
- `ConditionEvaluator`
- `ActionDispatcher`
- `QuestTracker`
- `LocationGraph`
- `LocationAccessService`
- encounter backend/runtime
- `AIManager`
- `ScriptHookService`
- `GameEvents`
- backend contracts and route catalog

The goal is not to create another quest/task/encounter system. Activities should orchestrate existing systems through existing service paths.

---

## 2. Core Design Decisions

### 2.1 Activity means immediate player intent

An activity is a synchronous player choice such as:

- train
- study
- rest
- socialize
- investigate
- patrol
- work
- visit a location
- trigger a scene
- start a quest
- start a task
- open an encounter

An activity may consume time, check requirements, dispatch actions, record history, and emit events.

An activity must **not** become an autonomous background job. Ongoing or queued work belongs to the task system.

### 2.2 Task means ongoing or queued runtime work

Omni already has task infrastructure for time-limited jobs that advance over ticks. Activities should not duplicate that.

Use this boundary:

| System | Responsibility |
|---|---|
| Activity | Immediate player-selected time spend |
| Task | Ongoing/queued runtime work that advances on ticks |
| Quest | Objective/state-machine progression |
| Encounter | Interactive conflict/minigame runtime |
| Schedule | Read-only projection of activity availability |

If an activity needs to create ongoing work, it should dispatch `start_task` through `ActionDispatcher`.

### 2.3 Calendar is projection only

The calendar/schedule layer must not store appointments in save data.

Schedule views are generated from:

- activity templates
- activity schedule rules
- current game time
- configured calendar model
- visibility conditions
- requirement state
- repeat/cooldown history

Do not add `calendar_events`, `appointments`, or equivalent persistent calendar state in v1.

### 2.4 ActivityService must stay thin

`ActivityService` coordinates execution. It does not own gameplay mutation.

It may:

- fetch templates
- evaluate visibility and requirements
- evaluate schedule state
- resolve location policy
- call existing services
- dispatch existing action blocks
- advance time through `TimeKeeper`
- record activity history
- emit activity events
- return result dictionaries

It must not directly mutate:

- stats
- inventory
- currency
- reputation
- quest stages
- encounter-local state
- rewards
- route data
- location entry conditions

### 2.5 AI is additive only

AI may provide:

- optional activity flavor text
- optional completion narration
- optional schedule summaries
- optional mod-authored hook behavior

AI must not determine deterministic gameplay mechanics.

AI-disabled mode must remain fully functional.

---

## 3. Ownership Boundaries

| Concern | Owner |
|---|---|
| Template loading | `DataManager` + relevant registry |
| Activity templates | `ActivityRegistry` |
| Activity execution | `ActivityService` |
| Schedule projection | `ActivityScheduleService` + `ScheduleBackend` |
| Time mutation | `TimeKeeper` |
| Time/date interpretation | `TimeModel` |
| Runtime state | `GameState` |
| Save/load | `SaveManager` |
| Conditions | `ConditionEvaluator` |
| Side effects | `ActionDispatcher` |
| Rewards | `RewardService` |
| Quest state | `QuestTracker` |
| Location entry checks | `LocationAccessService` |
| Route cost | `LocationGraph` |
| Player travel | `GameState.travel_to()` |
| Encounter mechanics | encounter backend/runtime |
| AI provider access | `AIManager` |
| AI flavor/hooks | `ScriptHookService` |
| Cross-system events | `GameEvents` |
| Backend UI contracts | backend classes + `BackendContractRegistry` |
| Screen routing | `OmniUIRouteCatalog` + `UIRouter` |

---

## 4. Target Architecture

```text
mods/*/data/activities.json
  -> ActivityRegistry -> DataManager.activities
                          -> ActivityService
                          -> ActivityScheduleService

ConditionEvaluator -> ActivityService -> TimeKeeper.advance_ticks()
GameState.activity_history <- activity started/completed records
GameEvents.activity_* -> QuestTracker refresh
GameEvents.activity_* -> ScriptHookService / optional AI
ActivityService -> ActivityBoardBackend / ScheduleBackend
```

---

## 5. Data Model

### 5.1 New activity data file

Add a first-class activity data file:

```text
mods/base/data/activities.json
mods/<author_id>/<mod_id>/data/activities.json
```

Top-level shape:

```json
{
  "activities": [],
  "patches": []
}
```

No activity content should be hardcoded into engine code.

### 5.2 Activity template v1

Use this schema:

```json
{
  "activity_id": "base:study_at_library",
  "display_name": "Study at Library",
  "description": "Spend time studying.",
  "category": "study",
  "kind": "standard",
  "duration_ticks": 2,

  "location_id": "base:library",
  "provider_entity_id": "",

  "schedule": {
    "weekdays": ["Mon", "Tue", "Wed", "Thu", "Fri"],
    "start_tick": 8,
    "end_tick": 18,
    "crosses_midnight": false,
    "must_fit_window": true,
    "start_grace_ticks": 0,
    "days": [],
    "available_after_day": -1,
    "available_until_day": -1,
    "months": [],
    "month_tags": [],
    "day_of_month": []
  },

  "visible_if": [],
  "requirements": [],

  "travel_policy": "must_be_present",

  "start_actions": [],
  "completion_actions": [],
  "failure_actions": [],

  "outcomes": [],

  "repeat": {
    "rule": "always",
    "max_completions": -1,
    "max_completions_per_day": -1,
    "cooldown_ticks": 0,
    "cooldown_days": 0
  },

  "tags": [],
  "ui": {},
  "ai": {},
  "script_path": ""
}
```

### 5.3 Required fields

| Field | Required | Purpose |
|---|---:|---|
| `activity_id` | yes | Stable namespaced ID |
| `display_name` | yes | Player-facing title |
| `category` | yes | UI grouping/filter key |
| `duration_ticks` | yes | Time consumed by normal execution |

### 5.4 Optional fields

| Field | Purpose |
|---|---|
| `description` | Player-facing details |
| `kind` | Secondary classification |
| `location_id` | Associated location |
| `provider_entity_id` | Associated NPC/entity/provider |
| `schedule` | Availability rules |
| `visible_if` | Conditions required to show |
| `requirements` | Conditions required to start |
| `travel_policy` | Location handling behavior |
| `start_actions` | Actions before duration advancement |
| `completion_actions` | Actions after duration advancement |
| `failure_actions` | Actions after started execution fails |
| `outcomes` | Optional weighted result branches |
| `repeat` | Repeat/cooldown limits |
| `tags` | Query/filter metadata |
| `ui` | Presentation metadata |
| `ai` | Optional AI metadata |
| `script_path` / `script_hook` | Optional mod script hook |

### 5.5 Normalized defaults

`ActivityRegistry.normalize_activity()` should apply:

| Field | Default |
|---|---|
| `description` | `""` |
| `kind` | `"standard"` |
| `schedule` | `{}` |
| `visible_if` | `[]` |
| `requirements` | `[]` |
| `travel_policy` | `"must_be_present"` when `location_id` exists, otherwise `"current_or_none"` |
| `start_actions` | `[]` |
| `completion_actions` | `[]` |
| `failure_actions` | `[]` |
| `outcomes` | `[]` |
| `repeat.rule` | `"always"` |
| `repeat.max_completions` | `-1` |
| `repeat.max_completions_per_day` | `-1` |
| `repeat.cooldown_ticks` | `0` |
| `repeat.cooldown_days` | `0` |
| `tags` | `[]` |
| `ui` | `{}` |
| `ai` | `{}` |

Backward-compatible aliases:

- `actions` may normalize to `completion_actions`.
- `script_hook` may normalize to `script_path` if `script_path` is empty.

---

## 6. TimeModel

### 6.1 File

```text
systems/time_model.gd
```

### 6.2 Purpose

`TimeModel` is a stateless helper for interpreting game time.

It must not advance time.

Time advancement remains owned by `TimeKeeper`.

`GameState.current_tick` is the canonical absolute tick, and `GameState.current_day` is the canonical saved day normalized from that absolute tick by `TimeKeeper`. `calendar.day_start_tick` only affects display-day/date projection and schedule interpretation; it must not rewrite canonical saved time.

### 6.3 Config keys

Use `calendar.*` rather than setting-specific names such as `life.*`.

```json
{
  "game": {
    "ticks_per_day": 24
  },
  "calendar": {
    "day_start_tick": 0,
    "weekdays": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    "months": [
      {
        "month_id": "spring",
        "display_name": "Spring",
        "days": 30,
        "tags": ["season:spring"]
      }
    ],
    "starting_year": 1,
    "starting_absolute_day": 1,
    "time_format": "{hour_24}:{minute_2}",
    "date_format": "{weekday}, {month} {day}, Year {year}"
  },
  "ui": {
    "activity_category_labels": {},
    "activity_category_colors": {}
  }
}
```

Do not hardcode:

- 24-hour days beyond config default
- 7-day weeks
- 12-month years
- 365-day years
- real-world month names

### 6.4 API

```gdscript
class_name TimeModel

static func get_ticks_per_day() -> int
static func get_current_absolute_tick() -> int
static func get_absolute_tick(day: int = -1, tick_of_day: int = -1) -> int
static func get_day_for_absolute_tick(absolute_tick: int) -> int
static func get_tick_of_day(absolute_tick: int = -1) -> int
static func get_display_day(day: int = -1, tick_of_day: int = -1) -> int
static func get_weekdays() -> Array[String]
static func get_week_length() -> int
static func get_current_weekday() -> String
static func get_weekday_for_day(day: int) -> String
static func get_months() -> Array[Dictionary]
static func get_month_days(month_id: String) -> int
static func get_month_tags(month_id: String) -> Array[String]
static func get_year_length(year: int = -1) -> int
static func absolute_day_to_date(day: int) -> Dictionary
static func date_to_absolute_day(year: int, month_id: String, day_of_month: int) -> int
static func format_time(tick_of_day: int = -1) -> String
static func format_date(day: int = -1) -> String
static func format_datetime(day: int = -1, tick_of_day: int = -1) -> String
static func days_until_weekday(target_weekday: String, from_day: int = -1) -> int
```

---

## 7. ActivityRegistry and DataManager Integration

### 7.1 Add data constant

Add wherever Omni stores data file constants:

```gdscript
const DATA_ACTIVITIES := "activities.json"
```

### 7.2 Add DataManager fields

```gdscript
const ACTIVITY_REGISTRY := preload("res://systems/loaders/activity_registry.gd")
var activities: Dictionary = {}
```

### 7.3 Add DataManager query methods

```gdscript
func get_activity(activity_id: String) -> Dictionary
func has_activity(activity_id: String) -> bool
func query_activities(filters: Dictionary = {}) -> Array[Dictionary]
```

Supported filters:

```gdscript
{
  "activity_ids": [],
  "categories": [],
  "category": "",
  "tags": [],
  "tags_all": [],
  "location_id": "",
  "provider_entity_id": "",
  "kind": ""
}
```

### 7.4 ActivityRegistry file

```text
systems/loaders/activity_registry.gd
```

### 7.5 ActivityRegistry API

```gdscript
class_name ActivityRegistry

static func load_additions(entries: Array) -> void
static func apply_patch(patches: Array) -> void
static func get_activity(activity_id: String) -> Dictionary
static func get_all() -> Array[Dictionary]
static func has_activity(activity_id: String) -> bool
static func validate_activity(activity: Dictionary) -> Array[String]
static func normalize_activity(activity: Dictionary) -> Dictionary
```

### 7.6 Patch operations

Support:

```json
{
  "target": "namespace:activity_id",
  "set": {},
  "set_schedule": {},
  "add_tags": [],
  "remove_tags": [],
  "add_requirements": [],
  "set_requirements": [],
  "add_visible_if": [],
  "set_visible_if": [],
  "add_start_actions": [],
  "set_start_actions": [],
  "add_completion_actions": [],
  "set_completion_actions": [],
  "add_failure_actions": [],
  "set_failure_actions": [],
  "add_outcomes": [],
  "set_outcomes": [],
  "set_repeat": {}
}
```

### 7.7 Validation rules

Reject or warn for:

- missing `activity_id`
- duplicate `activity_id`
- missing `display_name`
- missing `category`
- missing or negative `duration_ticks`
- unknown repeat rule
- malformed schedule block
- malformed condition arrays
- malformed action arrays
- missing referenced `location_id`
- missing referenced `provider_entity_id`
- invalid outcome weights
- outcome without `outcome_id`
- `end_tick < start_tick` without `crosses_midnight`
- `must_fit_window` without enough schedule data

---

## 8. Activity Runtime History

### 8.1 GameState addition

Add:

```gdscript
var activity_history: Dictionary = {}
```

### 8.2 History shape

```gdscript
{
  "activity_id": {
    "started_count": 0,
    "completion_count": 0,
    "last_started_tick": -1,
    "last_completed_tick": -1,
    "last_started_day": -1,
    "last_completed_day": -1,
    "last_started_absolute_tick": -1,
    "last_completed_absolute_tick": -1,
    "completed_by_day": {},
    "last_outcome_id": ""
  }
}
```

### 8.3 GameState helpers

Add:

```gdscript
func get_activity_history(activity_id: String) -> Dictionary
func record_activity_started(activity_id: String, payload: Dictionary = {}) -> void
func record_activity_completed(activity_id: String, payload: Dictionary = {}) -> void
func get_activity_completion_count(activity_id: String) -> int
func get_activity_category_completion_count(category: String) -> int
func was_activity_completed_today(activity_id: String) -> bool
func get_last_activity_outcome(activity_id: String) -> String
```

### 8.4 Save integration

Update:

- `GameState.reset()`
- `GameState.to_dict()`
- `GameState.from_dict()`
- `GameState.validate_runtime_state()`
- `SaveManager.REQUIRED_GAME_STATE_FIELDS`

Save schema must move to version 2 because `activity_history` becomes a required `game_state` field.

During active development, old v1 saves are intentionally rejected instead of migrated. Local development saves can be deleted when schema-breaking runtime fields land.

Activity history must survive save/load for schema v2 saves.

---

## 9. Activity Events

### 9.1 Add GameEvents signals

Add to `GameEvents.SIGNAL_CATALOG`:

```gdscript
"activities": [
  {"name": "activity_started", "args": ["payload"]},
  {"name": "activity_completed", "args": ["payload"]},
  {"name": "activity_failed", "args": ["payload"]},
  {"name": "activity_cancelled", "args": ["payload"]}
]
```

Add declared signals:

```gdscript
signal activity_started(payload: Dictionary)
signal activity_completed(payload: Dictionary)
signal activity_failed(payload: Dictionary)
signal activity_cancelled(payload: Dictionary)
```

### 9.2 Payload shape

```gdscript
{
  "activity_id": "",
  "category": "",
  "location_id": "",
  "provider_entity_id": "",
  "entity_id": "player",
  "started_day": 0,
  "started_tick": 0,
  "completed_day": 0,
  "completed_tick": 0,
  "duration_ticks": 0,
  "travel_ticks": 0,
  "outcome_id": "",
  "success": true,
  "failure_code": "",
  "reason": ""
}
```

Use dictionary payloads to avoid future signal-arity churn.

---

## 10. ActivityScheduleService

### 10.1 File

```text
systems/activity_schedule_service.gd
```

### 10.2 Purpose

`ActivityScheduleService` performs pure schedule evaluation and slot expansion.

It should not execute activities or mutate state.

### 10.3 API

```gdscript
class_name ActivityScheduleService

static func is_scheduled(activity: Dictionary, day: int, tick_of_day: int) -> bool
static func get_schedule_status(activity: Dictionary, day: int, tick_of_day: int) -> Dictionary
static func expand_slots(activity: Dictionary, from_day: int, to_day: int) -> Array[Dictionary]
static func get_next_slot(activity: Dictionary, from_day: int = -1, from_tick: int = -1, max_days: int = 14) -> Dictionary
```

### 10.4 Empty schedule behavior

An omitted or empty `schedule` means always scheduled, subject to:

- visibility
- requirements
- repeat policy
- cooldowns
- location policy

### 10.5 Supported v1 schedule keys

```json
{
  "weekdays": [],
  "start_tick": -1,
  "end_tick": -1,
  "crosses_midnight": false,
  "must_fit_window": false,
  "start_grace_ticks": 0,
  "days": [],
  "available_after_day": -1,
  "available_until_day": -1,
  "months": [],
  "month_tags": [],
  "day_of_month": []
}
```

Defer advanced recurrence keys such as `annual`, `once`, and `month_window` until after v1 is stable.

### 10.6 Schedule logic

All keys inside one schedule block use AND logic.

For OR scheduling, use multiple activities in v1. A future `schedule_any` field can be added later.

### 10.7 Cross-midnight windows

If `crosses_midnight` is true:

```text
tick >= start_tick OR tick <= end_tick
```

If `crosses_midnight` is false and `end_tick < start_tick`, validation fails.

### 10.8 Must-fit windows

If `must_fit_window` is true, the activity can start only when its full duration fits within the scheduled window after applying `start_grace_ticks`.

---

## 11. ActivityService

### 11.1 File

```text
systems/activity_service.gd
```

### 11.2 Purpose

`ActivityService` coordinates activity availability, execution, history, events, and board rows.

It delegates actual gameplay mutation to existing systems.

### 11.3 API

```gdscript
class_name ActivityService

static func get_activity_status(activity: Dictionary, context: Dictionary = {}) -> Dictionary
static func is_visible(activity: Dictionary, context: Dictionary = {}) -> bool
static func can_start(activity: Dictionary, context: Dictionary = {}) -> bool
static func get_unavailable_reason(activity: Dictionary, context: Dictionary = {}) -> String

static func resolve_location_policy(activity: Dictionary, context: Dictionary = {}) -> Dictionary
static func get_repeat_status(activity: Dictionary) -> Dictionary
static func get_cooldown_status(activity: Dictionary) -> Dictionary

static func build_board_rows(filters: Dictionary = {}) -> Array[Dictionary]
static func execute_activity(activity_id: String, context: Dictionary = {}) -> Dictionary
```

### 11.4 Execution lifecycle

Use this exact order:

1. Fetch activity template from `DataManager.get_activity()`.
2. Validate template exists.
3. Build execution context.
4. Evaluate `visible_if`.
5. Evaluate schedule via `ActivityScheduleService`.
6. Evaluate `requirements`.
7. Evaluate repeat/cooldown policy.
8. Resolve location policy.
9. Perform `auto_travel` if configured and valid.
10. Record activity started.
11. Emit `GameEvents.activity_started`.
12. Invoke `on_activity_start` hook.
13. Dispatch `start_actions`.
14. Advance duration through `TimeKeeper.advance_ticks(duration_ticks)`.
15. Resolve optional outcome.
16. Dispatch selected outcome actions or `completion_actions`.
17. Record activity completed.
18. Call `GameState.record_event("activity_completed", payload)`.
19. Emit `GameEvents.activity_completed`.
20. Invoke `on_activity_complete` hook.
21. Queue optional narration/flavor through `ScriptHookService`.
22. Return execution result.

### 11.5 Execution result shape

```gdscript
{
  "success": true,
  "activity_id": "",
  "category": "",
  "location_id": "",
  "provider_entity_id": "",
  "outcome_id": "",
  "started_day": 0,
  "started_tick": 0,
  "completed_day": 0,
  "completed_tick": 0,
  "duration_ticks": 0,
  "travel_ticks": 0,
  "message": "",
  "post_action": {}
}
```

Failure result:

```gdscript
{
  "success": false,
  "activity_id": "",
  "failure_code": "",
  "reason": ""
}
```

### 11.6 Failure codes

```text
missing_activity
hidden
not_scheduled
requirements_failed
repeat_blocked
cooldown_active
wrong_location
location_locked
route_unavailable
invalid_template
execution_error
```

### 11.7 Failure handling

If failure happens before activity start, do not dispatch `failure_actions`.

After `activity_started` is recorded, failures should dispatch `failure_actions`, record a failure event, and emit `activity_failed`.

`ActionDispatcher` is currently a void best-effort dispatcher. Activity execution should treat authored actions as side-effect commands and should not infer failure from warning output. Only explicit validation failures, failed location policy, failed requirements, failed schedule/repeat/cooldown checks, missing templates, script-hook errors, or future dispatcher result objects should produce an activity failure.

---

## 12. Location Policy

### 12.1 Supported values

| Policy | Behavior |
|---|---|
| `must_be_present` | Player must already be at `location_id` |
| `auto_travel` | System may travel to `location_id` before starting |
| `ignore_location` | Location is descriptive/filter metadata only |
| `current_or_none` | Valid if no `location_id` or current location matches |

### 12.2 Auto-travel flow

Use existing systems only:

```gdscript
var entry_status := LocationAccessService.get_entry_status(destination_id)
var travel_ticks := LocationGraph.get_route_travel_cost(GameState.current_location_id, destination_id)
GameState.travel_to(destination_id, travel_ticks)
```

ActivityService must not:

- inspect location connection dictionaries directly
- evaluate location entry conditions directly
- mutate location discovery directly
- implement independent routing

---

## 13. Repeat and Cooldown Rules

### 13.1 Supported repeat rules

| Rule | Behavior |
|---|---|
| `always` | Can repeat whenever other checks pass |
| `once` | Can complete once per save |
| `once_per_day` | Can complete once per display day |
| `limited` | Uses `repeat.max_completions` |
| `limited_per_day` | Uses `repeat.max_completions_per_day` |
| `cooldown` | Uses `repeat.cooldown_ticks` and/or `repeat.cooldown_days` |

### 13.2 Enforcement

Repeat and cooldown checks are enforced by `ActivityService.can_start()` using `GameState.activity_history`.

---

## 14. Outcomes and Weighted Choice

### 14.1 WeightedChoiceService file

```text
systems/weighted_choice_service.gd
```

### 14.2 API

```gdscript
class_name WeightedChoiceService

static func filter_available(entries: Array, context: Dictionary = {}) -> Array[Dictionary]
static func pick_weighted(entries: Array, context: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary
static func resolve_weight(entry: Dictionary, context: Dictionary = {}) -> float
```

### 14.3 Activity outcome shape

```json
{
  "outcome_id": "great_success",
  "display_name": "Great Success",
  "weight": 1.0,
  "conditions": [],
  "text": "You made excellent progress.",
  "actions": [],
  "tags": []
}
```

### 14.4 Outcome rules

- If `outcomes` is empty, dispatch `completion_actions`.
- If `outcomes` exist, filter by `conditions`.
- Pick by weight from eligible outcomes.
- Dispatch selected outcome `actions`.
- Store selected `outcome_id` as `last_outcome_id` in activity history.
- Include selected outcome in the activity completion event payload.

---

## 15. ConditionEvaluator Additions

### 15.1 Activity-aware conditions

Add typed conditions:

```json
{ "type": "activity_completed", "activity_id": "" }
{ "type": "activity_not_completed", "activity_id": "" }
{ "type": "activity_count_at_least", "activity_id": "", "count": 1 }
{ "type": "activity_count_less_than", "activity_id": "", "count": 1 }
{ "type": "activity_completed_today", "activity_id": "" }
{ "type": "activity_not_completed_today", "activity_id": "" }
{ "type": "activity_category_count_at_least", "category": "", "count": 1 }
{ "type": "last_activity_outcome_is", "activity_id": "", "outcome_id": "" }
```

### 15.2 Time-aware conditions

Add typed conditions:

```json
{ "type": "weekday_is", "weekday": "" }
{ "type": "weekday_in", "weekdays": [] }
{ "type": "tick_after", "tick": 0 }
{ "type": "tick_before", "tick": 0 }
{ "type": "tick_between", "start": 0, "end": 0 }
{ "type": "month_is", "month": "" }
{ "type": "month_in", "months": [] }
{ "type": "month_tag_is", "tag": "" }
{ "type": "month_tag_in", "tags": [] }
{ "type": "day_of_month_is", "day": 1 }
{ "type": "day_of_month_between", "start": 1, "end": 10 }
{ "type": "absolute_day_after", "day": 1 }
{ "type": "absolute_day_before", "day": 10 }
{ "type": "absolute_tick_after", "tick": 0 }
{ "type": "absolute_tick_before", "tick": 100 }
```

All time-aware conditions must use `TimeModel`.

### 15.3 Condition array semantics

For activity templates:

- `visible_if`: all entries must pass.
- `requirements`: all entries must pass.

Do not accidentally treat these arrays as OR unless a future schema explicitly adds `visible_if_any` or `requirements_any`.

---

## 16. ActionDispatcher Additions

Add these action types:

```gdscript
"advance_time": _action_advance_time
"advance_to_time": _action_advance_to_time
"advance_to_next_weekday": _action_advance_to_next_weekday
"record_event": _action_record_event
```

### 16.1 `advance_time`

```json
{ "type": "advance_time", "ticks": 2 }
```

Rules:

- Clamp negative values to zero.
- Call `TimeKeeper.advance_ticks()`.

### 16.2 `advance_to_time`

```json
{ "type": "advance_to_time", "day_offset": 0, "tick_of_day": 12 }
```

Rules:

- Target is relative to current day.
- Target tick is clamped to configured day length.
- Action never rewinds time.
- If target is not ahead, advance to the next valid target.

### 16.3 `advance_to_next_weekday`

```json
{ "type": "advance_to_next_weekday", "weekday": "Mon", "tick_of_day": 8 }
```

Rules:

- Use configured weekday strings.
- Use `TimeModel.days_until_weekday()`.
- Never hardcode week length.

### 16.4 `record_event`

```json
{ "type": "record_event", "event_type": "custom_event", "payload": {} }
```

Rules:

- Route through `GameState.record_event()`.
- Do not create a separate activity log store.

---

## 17. Quest Integration

### 17.1 QuestTracker signal subscription

Modify `QuestTracker._ready()`:

```gdscript
GameEvents.activity_completed.connect(_on_activity_completed)
```

Add:

```gdscript
func _on_activity_completed(_payload: Dictionary) -> void:
    _refresh_active_quests()
```

### 17.2 Quest objective pattern

Quests should depend on activity state through `ConditionEvaluator` conditions.

Valid examples:

```json
{
  "type": "activity_completed",
  "activity_id": "base:study_at_library"
}
```

```json
{
  "type": "activity_category_count_at_least",
  "category": "training",
  "count": 3
}
```

```json
{
  "type": "last_activity_outcome_is",
  "activity_id": "base:investigate_ruins",
  "outcome_id": "found_clue"
}
```

### 17.3 Hard boundary

`ActivityService` must not directly advance quest stages.

Activities may dispatch quest actions through `ActionDispatcher`, such as `start_quest`, but quest state remains owned by `QuestTracker`.

---

## 18. Encounter Integration

### 18.1 V1 approach

Activities can open encounters through existing screen routing actions:

```json
{
  "type": "push_screen",
  "screen_id": "encounter",
  "params": {
    "encounter_id": "base:ambush"
  }
}
```

### 18.2 Hard boundary

`ActivityService` must not:

- resolve encounter rounds
- pick encounter actions
- apply encounter rewards
- mutate encounter-local stats
- decide encounter outcomes

Encounter backend/runtime owns encounter mechanics.

### 18.3 Optional future action

A future `start_encounter` action may be added if `push_screen` becomes too verbose.

That action should still only route into the encounter backend.

---

## 19. AI and Script Hooks

### 19.1 ScriptHookService additions

Extend `ScriptHookService`:

```gdscript
const WORLD_GEN_HOOK_ACTIVITY_FLAVOR := "activity_flavor"
static var _activity_flavor_cache: Dictionary = {}
static var _pending_activity_flavors: Dictionary = {}
```

Add:

```gdscript
static func request_activity_flavor(activity_template: Dictionary, context: Dictionary = {}) -> String
static func store_activity_flavor(activity_id: String, flavor_text: String) -> void
```

### 19.2 Activity hooks

Activity templates may define `script_path`.

Supported callbacks:

```gdscript
func on_activity_start(activity: Dictionary, context: Dictionary) -> void:
    pass

func on_activity_complete(activity: Dictionary, result: Dictionary) -> void:
    pass

func on_activity_fail(activity: Dictionary, result: Dictionary) -> void:
    pass
```

`ActivityService` invokes hooks only through `ScriptHookService.invoke_template_hook()`.

### 19.3 AI guardrails

- Do not call `AIManager.generate_async()` directly from `ActivityService`.
- AI flavor should be requested through `ScriptHookService`.
- Activity execution must not await AI output.
- AI-disabled mode returns empty flavor/narration and continues normally.

---

## 20. ActivityBoardBackend

### 20.1 Files

```text
ui/screens/backends/activity_board_backend.gd
ui/screens/backends/activity_board_screen.gd
ui/screens/backends/activity_board_screen.tscn
```

### 20.2 Backend contract

```gdscript
BACKEND_CONTRACT_REGISTRY.register("ActivityBoardBackend", {
  "required": [],
  "optional": [
    "screen_title",
    "screen_description",
    "categories",
    "tags",
    "tags_all",
    "location_filter",
    "show_locked",
    "show_hidden",
    "show_upcoming",
    "max_upcoming_days",
    "max_upcoming_slots",
    "allow_auto_travel",
    "empty_label"
  ],
  "field_types": {
    "screen_title": TYPE_STRING,
    "screen_description": TYPE_STRING,
    "categories": TYPE_ARRAY,
    "tags": TYPE_ARRAY,
    "tags_all": TYPE_ARRAY,
    "location_filter": TYPE_STRING,
    "show_locked": TYPE_BOOL,
    "show_hidden": TYPE_BOOL,
    "show_upcoming": TYPE_BOOL,
    "max_upcoming_days": TYPE_INT,
    "max_upcoming_slots": TYPE_INT,
    "allow_auto_travel": TYPE_BOOL,
    "empty_label": TYPE_STRING
  }
})
```

### 20.3 Behavior

The activity board should:

- render current datetime using `TimeModel`
- render available activity rows
- optionally render locked rows
- hide failed `visible_if` rows unless debug/config allows hidden rows
- optionally render upcoming rows
- render category labels/colors from config
- render location/provider metadata when available
- render deterministic preview data if authored
- request optional AI flavor through `ScriptHookService`
- execute selected activity through `ActivityService.execute_activity()`
- refresh immediately after execution
- display execution result message
- route post-actions through existing backend navigation helpers

### 20.4 View model shape

```gdscript
{
  "title": "",
  "description": "",
  "datetime_text": "",
  "rows": [],
  "selected_activity_id": "",
  "status_text": "",
  "confirm_label": "Start",
  "confirm_enabled": true,
  "empty_label": ""
}
```

### 20.5 Board row shape

```gdscript
{
  "activity_id": "",
  "display_name": "",
  "description": "",
  "category": "",
  "category_label": "",
  "category_color": "",
  "kind": "",
  "location_id": "",
  "location_name": "",
  "provider_entity_id": "",
  "provider_name": "",
  "start_tick": -1,
  "end_tick": -1,
  "time_text": "",
  "duration_ticks": 0,
  "duration_text": "",
  "status": "available",
  "reason": "",
  "button_label": "Start",
  "preview_effects": [],
  "ai_flavor_text": "",
  "raw_activity": {}
}
```

---

## 21. ScheduleBackend

### 21.1 Files

```text
ui/screens/backends/schedule_backend.gd
ui/screens/backends/schedule_screen.gd
ui/screens/backends/schedule_screen.tscn
```

### 21.2 Backend contract

```gdscript
BACKEND_CONTRACT_REGISTRY.register("ScheduleBackend", {
  "required": [],
  "optional": [
    "screen_title",
    "view_mode",
    "day_range",
    "categories",
    "tags",
    "tags_all",
    "location_filter",
    "show_past",
    "group_by"
  ],
  "field_types": {
    "screen_title": TYPE_STRING,
    "view_mode": TYPE_STRING,
    "day_range": TYPE_INT,
    "categories": TYPE_ARRAY,
    "tags": TYPE_ARRAY,
    "tags_all": TYPE_ARRAY,
    "location_filter": TYPE_STRING,
    "show_past": TYPE_BOOL,
    "group_by": TYPE_STRING
  }
})
```

### 21.3 View modes

| Mode | Behavior |
|---|---|
| `day` | Current display day |
| `range` | Configured number of days |
| `week` | Current configured weekday cycle |
| `month` | Current configured month |

### 21.4 Slot statuses

| Status | Meaning |
|---|---|
| `elapsed` | Slot ended before current time |
| `active` | Current tick is inside slot |
| `upcoming` | Future slot |
| `locked` | Scheduled but current requirements fail |
| `hidden` | Visibility failed; normally not rendered |

### 21.5 Schedule slot shape

```gdscript
{
  "activity_id": "",
  "absolute_day": 0,
  "date_text": "",
  "weekday": "",
  "month_id": "",
  "month_name": "",
  "day_of_month": 0,
  "start_tick": -1,
  "end_tick": -1,
  "time_text": "",
  "status": "upcoming",
  "reason": "",
  "raw_activity": {}
}
```

### 21.6 Important behavior

Schedule rows should be read-only by default.

Clicking a schedule row may optionally navigate to `ActivityBoardBackend` with filters, but `ScheduleBackend` should not execute activities directly.

---

## 22. Route and Backend Registration

Update `ui/ui_route_catalog.gd`.

### 22.1 Add screen IDs

```gdscript
const SCREEN_ACTIVITY_BOARD := "activity_board"
const SCREEN_SCHEDULE := "schedule"
```

### 22.2 Add scene paths

```gdscript
const ACTIVITY_BOARD_SCENE := "res://ui/screens/backends/activity_board_screen.tscn"
const SCHEDULE_SCENE := "res://ui/screens/backends/schedule_screen.tscn"
```

### 22.3 Add backend mappings

```gdscript
"ActivityBoardBackend": "activity_board",
"ScheduleBackend": "schedule",
```

### 22.4 Add runtime scene mappings

```gdscript
SCREEN_ACTIVITY_BOARD: ACTIVITY_BOARD_SCENE,
SCREEN_SCHEDULE: SCHEDULE_SCENE,
```

Register backend contracts before `BackendContractRegistry.lock()` is called.

Add preload constants for the new backend scripts in `autoloads/mod_loader.gd`, then call:

```gdscript
ACTIVITY_BOARD_BACKEND.register_contract()
SCHEDULE_BACKEND.register_contract()
```

inside `_register_backend_contracts()` before `BACKEND_CONTRACT_REGISTRY.lock()`.

---

## 23. Implementation Sequence

Work phases in order unless a later phase is explicitly needed to unblock tests for an earlier one. If a phase is split across multiple sessions, add short unchecked sub-items under that phase rather than creating a separate planning document.

Status convention:

- `[ ]` not started
- `[~]` in progress
- `[x]` complete

Completion rule: a phase is complete only when its code, tests, and relevant current-state docs are done.

### Phase 1 - Time foundation

- [x] Add `systems/time_model.gd`.
- [x] Add `calendar.*` config handling.
- [x] Add validation for weekdays, months, day start offset, and display formats.
- [x] Add tests for arbitrary ticks per day.
- [x] Add tests for arbitrary week length.
- [x] Add tests for arbitrary month/year structures.
- [x] Add tests for day-start offset.

### Phase 2 - Activity loading

- [x] Add `DATA_ACTIVITIES` constant.
- [x] Add base `mods/base/data/activities.json`.
- [x] Add `DataManager.activities`.
- [x] Add `get_activity()`, `has_activity()`, and `query_activities()`.
- [x] Add `systems/loaders/activity_registry.gd`.
- [x] Wire activity additions into `DataManager.register_additions()`.
- [x] Wire activity patches into `DataManager.apply_patches()`.
- [x] Add normalization.
- [x] Add validation.
- [x] Add loader tests.

### Phase 3 - Activity history and save/load

- [x] Add `GameState.activity_history`.
- [x] Add GameState activity-history helpers.
- [x] Serialize `activity_history` in `GameState.to_dict()`.
- [x] Restore `activity_history` in `GameState.from_dict()`.
- [x] Add runtime validation.
- [x] Bump save schema to v2.
- [x] Reject older development save schemas without migration.
- [x] Add save/load tests.

### Phase 4 - Activity events

- [x] Add activity signals to `GameEvents.SIGNAL_CATALOG`.
- [x] Add declared activity signals.
- [x] Add tests that signal catalog and declarations stay in sync.

### Phase 5 - Schedule projection core

- [x] Add `systems/activity_schedule_service.gd`.
- [x] Implement empty schedule behavior.
- [x] Implement weekday checks.
- [x] Implement start/end tick windows.
- [x] Implement cross-midnight windows.
- [x] Implement must-fit window logic.
- [x] Implement absolute day and date/month filters.
- [x] Implement slot expansion.
- [x] Add schedule tests.

### Phase 6 - Activity execution core

- [x] Add `systems/activity_service.gd`.
- [x] Implement visibility checks.
- [x] Implement schedule checks.
- [x] Implement requirement checks.
- [x] Implement repeat/cooldown checks.
- [x] Implement location policy.
- [x] Implement duration advancement.
- [x] Implement action dispatch.
- [x] Implement activity started/completed history writes.
- [x] Emit activity lifecycle signals.
- [x] Return stable result dictionaries.
- [x] Add execution tests.

### Phase 7 - Conditions and actions

- [x] Add activity-aware conditions to `ConditionEvaluator`.
- [x] Add time-aware conditions to `ConditionEvaluator`.
- [x] Add `advance_time` action.
- [x] Add `advance_to_time` action.
- [x] Add `advance_to_next_weekday` action.
- [x] Add `record_event` action.
- [x] Add condition/action tests.

### Phase 8 - Quest integration

- [x] Connect `QuestTracker` to `GameEvents.activity_completed`.
- [x] Refresh active quests on activity completion.
- [x] Add quest objective fixture using activity history.
- [x] Confirm `ActivityService` does not directly advance quest stages.
- [x] Add quest integration tests.

### Phase 9 - Outcomes

- [x] Add `systems/weighted_choice_service.gd`.
- [x] Implement outcome filtering.
- [x] Implement weighted selection.
- [x] Dispatch selected outcome actions.
- [x] Record `last_outcome_id`.
- [x] Add outcome tests.

### Phase 10 - Encounter handoff

- [x] Confirm activities can open encounter screen through `push_screen`.
- [x] Add test activity that routes to an encounter.
- [x] Confirm activity does not resolve encounter state.
- [x] Confirm encounter rewards remain encounter-owned.
- [x] Add integration tests.

### Phase 11 - AI and script hooks

- [x] Add activity flavor cache/pending state to `ScriptHookService`.
- [x] Add `request_activity_flavor()`.
- [x] Add `store_activity_flavor()`.
- [x] Add activity hook callbacks.
- [x] Invoke hooks through `ScriptHookService` only.
- [x] Confirm AI-disabled mode is a complete no-op.
- [x] Add AI/hook tests.

### Phase 12 - Activity board UI

- [ ] Add `ActivityBoardBackend`.
- [ ] Add activity board screen script.
- [ ] Add activity board scene.
- [ ] Register backend contract.
- [ ] Add backend preload and contract registration in `ModLoader._register_backend_contracts()`.
- [ ] Add route catalog entry.
- [ ] Add backend/screen tests.

### Phase 13 - Schedule UI

- [ ] Add `ScheduleBackend`.
- [ ] Add schedule screen script.
- [ ] Add schedule scene.
- [ ] Register backend contract.
- [ ] Add backend preload and contract registration in `ModLoader._register_backend_contracts()`.
- [ ] Add route catalog entry.
- [ ] Add schedule projection tests.

### Phase 14 - Documentation alignment

- [ ] Update `docs/PROJECT_STRUCTURE.md`.
- [ ] Update `docs/SYSTEM_CATALOG.md`.
- [ ] Update `docs/modding_guide.md`.
- [ ] Update `docs/GAME_EVENTS_TAXONOMY.md`.
- [ ] Update `docs/SAVE_SCHEMA_AND_MIGRATION.md`.
- [ ] Update any schema/lint docs affected by activity data, calendar config, conditions, actions, or backend contracts.

### Phase 15 - Content-agnostic validation

- [ ] Add minimal fixture activities for tests only.
- [ ] Confirm no engine code depends on specific setting names.
- [ ] Confirm no engine code depends on specific location names.
- [ ] Confirm no engine code depends on specific NPCs, factions, campaigns, or sample scenarios.

---

## 24. Testing Matrix

Add or update tests next to the affected subsystem. Keep fixture data minimal and content-agnostic. Prefer targeted unit tests for pure helpers and integration tests for save/load, mod loading, quest refresh, backend routing, and UI contracts.

### 24.1 TimeModel tests

- [x] Tick-of-day resolves from absolute tick.
- [x] Day resolves from absolute tick.
- [x] Weekday cycle works with arbitrary weekday counts.
- [x] Month rollover works with arbitrary month counts and lengths.
- [x] Year rollover works.
- [x] Day-start offset changes display day correctly.
- [x] Date formatting uses config.
- [x] No hardcoded 24-hour, 7-day, 12-month, or 365-day assumptions.

### 24.2 ActivityRegistry tests

- [x] Loads valid activities.
- [x] Rejects missing IDs.
- [x] Rejects duplicates.
- [x] Normalizes defaults.
- [x] Preserves unknown metadata.
- [x] Applies patches.
- [x] Validates schedule shapes.
- [x] Validates referenced locations/entities.

### 24.3 ActivityScheduleService tests

- [x] Empty schedule is always scheduled.
- [x] Weekday filters work.
- [x] Tick windows work.
- [x] Cross-midnight windows work.
- [x] Must-fit windows block invalid starts.
- [x] Month filters work.
- [x] Month tag filters work.
- [x] Slot expansion is deterministic.

### 24.4 ActivityService tests

- [x] Hidden activities do not appear.
- [x] Locked activities appear only when configured.
- [x] Requirements block execution.
- [x] Schedule checks block execution.
- [x] Repeat rules block correctly.
- [x] Cooldowns block correctly.
- [x] Location policies resolve correctly.
- [x] Auto-travel uses route cost.
- [x] Auto-travel respects location entry gates.
- [x] Duration advances time only through `TimeKeeper`.
- [x] Start actions dispatch before duration.
- [x] Completion actions dispatch after duration.
- [x] Activity history records starts/completions.
- [x] Activity events emit.

### 24.5 Quest integration tests

- [x] Activity completion refreshes active quests.
- [x] Activity-count objectives complete correctly.
- [x] Activity-category objectives complete correctly.
- [x] Activity outcome objectives complete correctly.
- [x] ActivityService does not directly advance quest stages.

### 24.6 Encounter integration tests

- [x] Activity can open encounter screen through existing action paths.
- [x] Activity does not resolve encounter state.
- [x] Encounter rewards remain encounter-owned.

### 24.7 AI integration tests

- [x] AI-disabled mode returns no flavor and does not error.
- [x] AI-enabled flavor can be cached.
- [x] Activity execution does not await flavor generation.
- [x] Completion narration is optional.

### 24.8 Backend tests

- [ ] Activity board renders available rows.
- [ ] Activity board renders locked rows.
- [ ] Activity board executes selected activity.
- [ ] Activity board refreshes after execution.
- [ ] Schedule day view works.
- [ ] Schedule range view works.
- [ ] Schedule week view uses configured week length.
- [ ] Schedule month view uses configured month length.

### 24.9 Save/load tests

- [ ] Activity history persists.
- [ ] Repeat status survives reload.
- [ ] Cooldown status survives reload.
- [ ] Last outcome survives reload.
- [ ] Older saves migrate cleanly.

---

## 25. Definition of Done

The implementation is complete when:

- [ ] Activities are loaded through the normal mod data pipeline.
- [ ] Activities are queryable through `DataManager`.
- [ ] Activity execution is fully data-authored.
- [ ] Activity execution advances time only through `TimeKeeper`.
- [ ] Activity execution applies side effects only through `ActionDispatcher` or existing service paths.
- [ ] Activity requirements use `ConditionEvaluator`.
- [ ] Activity history persists through save/load.
- [x] Quests can depend on activity history without `ActivityService` knowing quest internals.
- [ ] Activities can use location policy without duplicating route or entry logic.
- [x] Activities can open encounters without owning encounter resolution.
- [x] AI flavor/narration is optional and non-blocking.
- [ ] Activity board UI can execute activities.
- [ ] Schedule UI can project upcoming activities.
- [ ] Tests cover time, loading, execution, save/load, quest integration, location integration, encounter handoff, AI no-op behavior, and backend rendering.
- [ ] Base docs describe the implemented activity/calendar systems as current behavior.
- [ ] No engine code depends on specific content, setting names, location names, NPCs, factions, campaigns, or sample scenarios.
