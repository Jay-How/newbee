## 策略卡牌数据
## 包含策略卡牌的基本信息、效果、成本等
extends CardData
class_name StrategyCardData

const COST : int = 1                            ## 卡牌登场成本（常量始终为1）
enum StrategyType {TACTIC, SPELL}               ## 策略类型（战术卡/法术卡）
enum TriggerType {ACTIVE, PASSIVE}              ## 发动类型（主动发动/被动发动）

@export var strategy_type : StrategyType = StrategyType.TACTIC  ## 策略类型
@export var trigger_type : TriggerType = TriggerType.ACTIVE     ## 发动类型
@export var effect : Dictionary = {}                            ## 策略效果
@export var effect_description : String = ""                    ## 效果描述
