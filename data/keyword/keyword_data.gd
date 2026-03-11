## 词条数据
## 包含词条的基本信息、触发逻辑等
extends Resource
class_name KeywordData

@export var id : StringName = ""            ## 词条ID（字符串名）
@export var name : String = ""              ## 词条名称（字符串）
@export var description : String = ""       ## 词条描述（字符串）
@export var logic : Dictionary = {}         ## 词条触发逻辑
@export var effects : Array = []            ## 词条触发后产生的效果