extends BaseState
class_name SkillState
## 技能状态基类
## 包含技能状态的基本信息、触发逻辑等

## 进入状态时调用方法
func enter(_prev_state: BaseState = null) -> void:
    pass
func exit(_next_state: BaseState = null) -> void:
    pass
func trigger() -> void:
    pass
func execute_skill() -> Dictionary:
    return {}

