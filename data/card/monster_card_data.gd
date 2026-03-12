## 怪物卡牌数据
## 包含怪物卡牌的基本信息、属性、能力等
extends CardData
class_name MonsterCardData

const COST : int = 0                        ## 卡牌登场成本（敌人无需消耗）
@export var level : int = -1                ## 怪物等级（负数非法）
@export var max_hp : int = -1               ## 最大生命值（负数非法）
@export var current_hp : int = -1           ## 当前生命值（负数非法）
@export var max_mp : int = -1               ## 最大MP（负数非法）
@export var current_mp : int = -1           ## 当前MP（负数非法）
var skills : Array[SkillData] = []  ## 技能列表
@export var intent_pool : Array = []        ## 意图池
