## 卡牌抽象基类
## 包含卡牌的ID、名称、类型、描述、图标路径和风味文本
extends Resource
class_name CardData
enum CardType {UNIT_CARD, STRATEGY_CARD, MONSTER_CARD} ## 卡牌类型
enum Rarity {COMMON, RARE, EPIC, LEGENDARY} ## 稀有度(普通、稀有、史诗、传说)

@export var id : StringName                     ## 卡牌ID
@export var name : String                       ## 卡牌名称 
@export var card_type : CardType                ## 卡牌类型
@export var description : String                ## 卡牌描述
@export var icon_path : String                  ## 图标路径
@export var flavor_text : String = ""           ## 风味文本
@export var developer : String = ""             ## 开发者注释（字符串）
@export var rarity : Rarity                     ## 稀有度（枚举类型）     
@export var source : String                     ## 来源（字符串）
@export var acquisition_method : String = ""    ## 获得方式（字符串）