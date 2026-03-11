## skill_data.gd
## 技能数据
## 包含技能的基本信息、效果、成本等
extends Resource
class_name SkillData

## 技能范围（前排、后排、所有、自身、无、敌方所有、敌方单个）
enum SkillRange {FRONTLINE, BACKLINE, ALL, SELF, NONE, ENEMY_ALL, ENEMY_SINGLE} ## 技能范围
enum SkillType {ACTIVE, PASSIVE, TRIGGERED} ## 技能类型 

@export var skill_id : StringName = ""                  ## 技能ID（字符串名）
@export var skill_name : String = ""                    ## 技能名称（字符串）
@export var skill_type : SkillType                      ## 技能类型（枚举类型）
@export var skill_cost : Dictionary = {}                ## 技能成本（key : value）  
@export var skill_effects : Dictionary = {}             ## 技能效果（key : value）
@export var skill_description : String = ""             ## 技能描述（字符串）
@export var skill_range : SkillRange                    ## 技能范围 
@export var cooldown_turn : int = 1                     ## 技能冷却回合（负数非法，默认1,每回合使用一次）
@export var skill_update : SkillData = null             ## 技能升级（对应技能，默认为无）
@export var combo_abilities : Array[SkillData] = []     ## 组合/相关技能（数组，默认为空）
@export var developer : String = ""                     ## 开发者注释（字符串）
@export var icon_path : String = ""                     ## 图标路径（字符串）