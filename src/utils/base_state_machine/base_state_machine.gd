# base_state_machine.gd （状态机基类）
class_name BaseStateMachine
extends RefCounted
# ==========状态机属性==========
## 状态机所有者
var owner: Node :
    set(value):
        owner = value
        _update_owner_for_states()
    get():
        return owner
## 状态机所有状态列表[状态名：状态实例]
var states : Dictionary = {}
## 当前状态
var current_state: BaseState = null 

# ==========状态机设置方法==========
## 状态机添加状态方法
func add_state(state: BaseState) -> void:
    if state.name in states:
        push_error("状态机添加状态失败，状态名已存在")
        return
    states[state.name] = state
    state.owner = owner
## 状态机切换状态方法
func switch_state(state_name: String) -> void:
    if current_state:
        current_state.exit()
    if state_name in states:
        current_state = states[state_name]
    else:
        push_error("状态机切换状态失败，状态名不存在")
    if current_state and current_state.is_valid():
        current_state.enter()
    else:
        push_error("状态机切换状态失败，状态无效")
## 状态机移除状态方法
func remove_state(state_name: String) -> void:
    if state_name in states:
        states.erase(state_name)
    else:
        push_error("状态机移除状态失败，状态名不存在")  

# ==========状态机处理方法==========
## 每逻辑帧调用状态更新方法
func _process(delta: float) -> void:
    if current_state and current_state.is_valid():
        current_state.update(delta)
## 每物理帧调用状态物理更新方法
func _physics_process(delta: float) -> void:
    if current_state and current_state.is_valid():
        current_state.physics_update(delta)
## 输入事件调用状态输入处理方法
func _input(event: InputEvent) -> void:
    if current_state and current_state.is_valid():
        current_state.handle_input(event)

# ==========状态机私有方法==========
## 获取状态机当前状态方法
func _get_current_state() -> BaseState:
    if not current_state or not current_state.is_valid():
        push_error("状态机当前状态无效")
        return null
    return current_state
## 获取所有状态列表方法
func _get_all_states() -> Dictionary:
    if not states:
        push_error("状态机没有添加任何状态")
        return {}
    return states
## 状态机更新所有者方法
func _update_owner_for_states() -> void:
    if not states:
        push_error("状态机没有添加任何状态")
        return
    for state in states.values():
        state.owner = owner
## 验证状态是否为状态机所属方法
func _is_state_of_machine(state: BaseState) -> bool:
    return state.name in states and states[state.name] == state
