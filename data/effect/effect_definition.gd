## 技能效果数据
## 包含技能效果的基本信息、效果等
extends Resource
class_name EffectDefinition
## 效果类型（无、增增益、减益、触发）
enum EffectType {NONE, BENEFIT, DETRITUS, TRIGGER} 

@export var id : StringName = ""            ## 效果ID（字符串名）
@export var name : String = ""              ## 效果名称（字符串）
@export var type : EffectType               ## 效果类型（枚举类型） 默认值为无
@export var description : String = ""       ## 效果描述（字符串）
