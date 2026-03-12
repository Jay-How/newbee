# state.gd (抽象状态基类)
class_name BaseState
extends RefCounted

# 状态持有者(通常是角色/管理器)
var owner: Node = null  

# ==========状态生命周期函数==========
## 进入状态时调用方法
func enter(_prev_state: BaseState = null) -> void:
    pass
## 退出状态时调用方法
func exit(_next_state: BaseState = null) -> void:
    pass
## 每逻辑帧更新时方法
func update(_delta: float) -> void:
    pass
## 每物理帧更新时方法
func physics_update(_delta: float) -> void:
    pass
## 处理输入事件时调用方法
func handle_input(_event: InputEvent) -> void:
    pass

# ==========状态错误处理函数==========
## 状态有效性检查方法
func is_valid() -> bool:
    # 默认检查状态所有者，子类可以重写
    return owner != null
## 处理状态错误方法
func handle_error(error_message: String) -> void:
    # 默认错误处理，子类可以重写
    push_error("状态错误: " + error_message)