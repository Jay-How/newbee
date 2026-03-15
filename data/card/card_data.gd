## 卡片数据基类
## 用于存储卡牌的基本信息
extends Resource
class_name CardData

enum CardType {UNIT, STRATEGY, ENIMY}

@export var id: StringName
@export var name: String
@export var card_type: CardType
@export var description: String
@export var image_path: String

@export var unit_data: UnitData
@export var strategy_data: StrategyData
@export var enemy_data: EnemyData
