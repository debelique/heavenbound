# BossController.gd
extends CharacterBody2D
class_name BossController

signal died

@onready var _animation_player = %AnimatedSprite2D
@onready var hitbox_area: Area2D = $HitBoxArea
@onready var hurtbox_area: Area2D = $HurtBoxArea
@onready var state_machine: StateMachine = $StateMachine

@export var attack_pools: Array[Array] = []       # Array[Array[AttackData]], indexed by phase
@export var phase_thresholds: Array[float] = [0.5, 0.2]
@export var max_phase: int = 3
@export var max_hp: float = 500.0
@export var max_poise: float = 100.0

var current_hp: float
var poise: float
var phase: int = 1
var current_attack: AttackData
var last_attack_name: String = ""
var cooldowns: Dictionary = {}

func _ready():
	current_hp = max_hp
	poise = max_poise
	hurtbox_area.area_entered.connect(_on_hurt_box_area_area_entered)
	state_machine.start() 

func _physics_process(delta):
	# cooldowns tick centrally, independent of state
	for key in cooldowns.keys():
		cooldowns[key] = max(0.0, cooldowns[key] - delta)

func hp_percent() -> float:
	return current_hp / max_hp

func dist_to_player() -> float:
	var player = get_tree().get_first_node_in_group("player")
	return global_position.distance_to(player.global_position) if player else INF

func _on_hurt_box_area_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var dmg = area.get_damage()
		var poise_dmg = area.get_poise_damage()
		state_machine.current_state.handle_hit(dmg, poise_dmg)

func _on_hit_box_area_area_entered(area: Area2D):
	if area.is_in_group("player_hurtbox"):
		area.take_damage()

func take_damage(damage: float, poise_damage: float, is_zeal_charged: bool = false):
	if state_machine.current_state.name == "Dead":
		return
	current_hp -= damage
	current_hp = max(current_hp, 0.0)
	poise -= poise_damage * (1.5 if is_zeal_charged else 1.0)

	print("Boss HP: ", current_hp, " / ", max_hp)

	if current_hp <= 0.0:
		state_machine.transition_to("Dead")
	elif poise <= 0.0:
		poise = max_poise
		state_machine.transition_to("Staggered")
