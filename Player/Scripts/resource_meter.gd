extends Node
class_name ResourceMeter
## A charge-based resource meter ("Zeal") used for healing and
## spellcasting. Attach as a child node on the player.

signal charge_changed(current: float, max: float)
signal charge_depleted
signal charge_full
signal insufficient_charge(required: float, available: float)

@export var boon_manager: BoonManager

@export_group("Capacity")
@export var max_charge: float = 100.0
@export var starting_charge: float = 0.0

@export_group("Passive Regeneration")
## Set to 0 if this resource should ONLY fill via combat/kills, not passive regen.
@export var passive_regen_rate: float = 0.0 #TODO CHANGE BACK TO 0.0
@export var regen_delay_after_use: float = 1.5  # seconds before passive regen kicks back in

@export_group("Combat Charging")
## How much charge is gained per "charge point" (e.g. per hit landed, per kill).
@export var charge_per_hit: float = 5.0
@export var charge_per_kill: float = 15.0

@export_group("Ability Costs")
@export var heal_cost: float = 30.0
@export var spell_costs: Dictionary = {
	"minor_smite": 15.0,
	"radiant_burst": 40.0,
	"ascension_nova": 80.0,
}

var current_charge: float = 0.0
var _regen_locked_timer: float = 0.0

func _ready() -> void:
	current_charge = clamp(starting_charge, 0.0, max_charge)
	if boon_manager == null:
		boon_manager = get_parent().get_node("BoonManager")

func _process(delta: float) -> void:
	if _regen_locked_timer > 0.0:
		_regen_locked_timer -= delta
		return

	var regen_enabled = passive_regen_rate > 0.0
	if boon_manager:
		regen_enabled = regen_enabled or boon_manager.has_passive_zeal_regen()

	if regen_enabled and current_charge < max_charge:
		var rate = passive_regen_rate if passive_regen_rate > 0.0 else 5.0  # fallback rate if boon-granted
		_add_charge(rate * delta)


# ---------- Gaining charge ----------

func on_hit_landed() -> void:
	_add_charge(charge_per_hit)
	charge_changed.emit(current_charge, max_charge) 
	print("Zeal charge: ", current_charge, "/", max_charge)

func on_enemy_killed() -> void:
	if boon_manager and boon_manager.has_zeal_from_kills():
		_add_charge(charge_per_kill)

func add_charge_custom(amount: float) -> void:
	_add_charge(amount)

func _add_charge(amount: float) -> void:
	var was_full := current_charge >= max_charge
	current_charge = clamp(current_charge + amount, 0.0, max_charge)
	charge_changed.emit(current_charge, max_charge)
	if current_charge >= max_charge and not was_full:
		charge_full.emit()


# ---------- Spending charge ----------

## Call before healing. Returns true if the heal was allowed and paid for.
func try_heal() -> bool:
	return _try_spend(heal_cost)

## Call before casting a named spell. Returns true if allowed and paid for.
func try_cast(spell_name: String) -> bool:
	if not spell_costs.has(spell_name):
		push_warning("ResourceMeter: unknown spell '%s'" % spell_name)
		return false
	return _try_spend(spell_costs[spell_name])

## Generic spend, if you want custom-cost abilities not in spell_costs.
func try_spend_custom(amount: float) -> bool:
	return _try_spend(amount)

func can_afford(amount: float) -> bool:
	return current_charge >= amount

func _try_spend(amount: float) -> bool:
	if current_charge < amount:
		insufficient_charge.emit(amount, current_charge)
		return false

	current_charge -= amount
	_regen_locked_timer = regen_delay_after_use
	charge_changed.emit(current_charge, max_charge)
	if current_charge <= 0.0:
		charge_depleted.emit()
	return true


# ---------- Convenience ----------

func get_percent() -> float:
	return current_charge / max_charge if max_charge > 0.0 else 0.0

func reset_to_empty() -> void:
	current_charge = 0.0
	charge_changed.emit(current_charge, max_charge)

func reset_to_full() -> void:
	current_charge = max_charge
	charge_changed.emit(current_charge, max_charge)
