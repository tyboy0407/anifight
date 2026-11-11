class_name AttackData
extends Resource
## 單一招式的數值。時間單位為秒,位置以角色腳底為原點、面向右為正。

@export var damage: int = 50
## 出招前搖、判定持續、收招硬直
@export var startup: float = 0.07
@export var active: float = 0.10
@export var recovery: float = 0.20
## 攻擊框中心位置與大小
@export var hitbox_offset: Vector2 = Vector2(60, -65)
@export var hitbox_size: Vector2 = Vector2(70, 40)
## 命中後對手的擊退速度;launches 為 true 時 y 為擊飛的垂直速度
@export var knockback: Vector2 = Vector2(220, 0)
@export var hitstun: float = 0.30
@export var launches: bool = false
## 出招時自身往前踏的速度
@export var lunge: float = 120.0
## 命中時攻擊方是否累積氣量(耗氣招式設為 false)
@export var builds_energy: bool = true
## 攻擊框的顯示顏色
@export var color: Color = Color(1, 0.95, 0.3, 0.75)


static func make(p_damage: int, p_startup: float, p_active: float, p_recovery: float,
		p_offset: Vector2, p_size: Vector2, p_knockback: Vector2,
		p_hitstun: float = 0.3, p_launches: bool = false, p_lunge: float = 120.0) -> AttackData:
	var data := AttackData.new()
	data.damage = p_damage
	data.startup = p_startup
	data.active = p_active
	data.recovery = p_recovery
	data.hitbox_offset = p_offset
	data.hitbox_size = p_size
	data.knockback = p_knockback
	data.hitstun = p_hitstun
	data.launches = p_launches
	data.lunge = p_lunge
	return data
