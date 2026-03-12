## 技能数据基类
## 包含技能的基本信息、触发逻辑等
extends Resource
class_name SkillData

@export var name : String = ""              ## 技能名称
@export var description : String = ""       ## 技能描述
@export var cost : Dictionary = {}          ## 技能成本（字典，键为资源类型，值为成本数量）
@export var active_cost : Dictionary = {}   ## 激活成本（字典，键为资源类型，值为成本数量）
var skill_state : SkillState = null ## 技能状态（技能相关方法都在这里写）
