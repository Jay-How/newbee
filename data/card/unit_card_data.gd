## 单位卡牌数据
## 包含单位卡牌的基本信息、效果、成本等
extends CardData
class_name UnitCardData
enum UnitCardType {WARRIOR, MAGE}

const COST : int = 1                                ## 卡牌登场成本（常量始终为1）
@export var unit_card_type : UnitCardType           ## 单位卡牌类型
@export var max_hp : int = -1                       ## 最大生命值（负数非法）
@export var current_hp : int = -1                   ## 当前生命值（负数非法）
@export var mp : int = -1                           ## 法力值（负数非法）
@export var current_skill : SkillData               ## 当前技能（技能数据资源）
@export var job : StringName = ""                   ## 职业（字符串名）
@export var move_cost : int = -1                    ## 移动成本（负数非法）
@export var active_cost : int = -1                  ## 激活成本（负数非法）