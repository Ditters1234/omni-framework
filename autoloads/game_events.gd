## GameEvents — Global signal bus.
## All cross-system communication flows through here.
## No system should hold a direct reference to another system.
extends Node

class_name OmniGameEvents

# ---------------------------------------------------------------------------
# Mod / Data loading
# ---------------------------------------------------------------------------
signal mod_loaded(mod_id: String)
signal mod_load_error(mod_id: String, message: String)
signal all_mods_loaded()

# ---------------------------------------------------------------------------
# Time
# ---------------------------------------------------------------------------
signal tick_advanced(tick: int)
signal day_advanced(day: int)

# ---------------------------------------------------------------------------
# Game State
# ---------------------------------------------------------------------------
signal game_started()
signal game_paused()
signal game_resumed()
signal game_over()

signal location_changed(old_id: String, new_id: String)
signal player_stat_changed(stat_key: String, old_value: float, new_value: float)
signal entity_stat_changed(entity_id: String, stat_key: String, old_value: float, new_value: float)
signal flag_changed(entity_id: String, flag_id: String, value: Variant)

# ---------------------------------------------------------------------------
# Inventory / Parts
# ---------------------------------------------------------------------------
signal part_acquired(entity_id: String, part_id: String)
signal part_removed(entity_id: String, part_id: String)
signal part_equipped(entity_id: String, part_id: String, slot: String)
signal part_unequipped(entity_id: String, part_id: String, slot: String)

# ---------------------------------------------------------------------------
# Economy
# ---------------------------------------------------------------------------
signal currency_changed(currency_key: String, old_amount: float, new_amount: float)
signal entity_currency_changed(entity_id: String, currency_key: String, old_amount: float, new_amount: float)
signal transaction_completed(buyer_id: String, seller_id: String, part_id: String, price: float)

# ---------------------------------------------------------------------------
# Quests / Tasks
# ---------------------------------------------------------------------------
signal quest_started(quest_id: String)
signal quest_stage_advanced(quest_id: String, stage_index: int)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal task_started(task_id: String, entity_id: String)
signal task_completed(task_id: String, entity_id: String)

# ---------------------------------------------------------------------------
# Achievements
# ---------------------------------------------------------------------------
signal achievement_unlocked(achievement_id: String)

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
signal screen_pushed(screen_id: String)
signal screen_popped(screen_id: String)
signal notification_requested(message: String, level: String)
signal ui_screen_pushed(screen_id: String)
signal ui_screen_popped(screen_id: String)
signal ui_notification_requested(message: String, level: String)

# ---------------------------------------------------------------------------
# AI
# ---------------------------------------------------------------------------
signal ai_response_received(context_id: String, response: String)
signal ai_token_received(context_id: String, token: String)
signal ai_error(context_id: String, error: String)

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------
signal save_started(slot: int)
signal save_completed(slot: int)
signal load_started(slot: int)
signal load_completed(slot: int)
signal save_failed(slot: int, reason: String)
signal load_failed(slot: int, reason: String)
