class_name Upgrade
extends Resource
## A level-up choice. Add a new .tres in res://resources/upgrades and list it in GameState.UPGRADE_PATHS.

@export var id: StringName
@export var title: String
@export_multiline var description: String
## Which procedural icon UpgradeIcon draws.
@export_enum("triple", "thrusters", "speed", "pierce", "shield", "homing", "power", "armor") var icon: String = "triple"
@export var color := Color(0.3, 0.7, 1.0)
@export var max_stacks := 3
## Added to player stats, e.g. {"multishot": 2}.
@export var add_stats: Dictionary = {}
## Multiplies player stats, e.g. {"fire_rate": 1.25}.
@export var mul_stats: Dictionary = {}
