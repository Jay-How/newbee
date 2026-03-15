# 有限状态机 (Finite State Machine) 实现

## 1. 核心功能说明

本状态机实现是一个轻量级的有限状态机框架，专为Godot游戏引擎设计，提供了以下核心功能：

- **状态管理**：添加、切换、移除状态
- **状态生命周期管理**：支持状态的进入、退出、更新等生命周期方法
- **输入事件处理**：状态可以处理输入事件
- **物理帧更新**：支持物理帧的更新逻辑
- **错误处理**：提供基本的错误检测和处理机制

## 2. 设计理念

本状态机实现遵循以下设计理念：

- **分离关注点**：状态机负责状态管理，状态负责具体行为逻辑
- **面向对象**：使用Godot的RefCounted作为基类，支持继承和多态
- **灵活性**：状态可以自由定义和扩展，状态机可以动态添加和移除状态
- **简洁性**：核心逻辑简单明了，易于理解和使用

## 3. 核心类与接口说明

### 3.1 BaseStateMachine (状态机基类)

**主要属性**：
- `owner: Node` - 状态机所有者
- `states: Dictionary` - 状态机所有状态列表，格式为 `{状态名: 状态实例}`
- `current_state: BaseState` - 当前状态

**主要方法**：
- `add_state(state: BaseState) -> void` - 添加状态
- `switch_state(state_name: String) -> void` - 切换状态
- `remove_state(state_name: String) -> void` - 移除状态
- `_process(delta: float) -> void` - 每逻辑帧调用状态更新方法
- `_physics_process(delta: float) -> void` - 每物理帧调用状态物理更新方法
- `_input(event: InputEvent) -> void` - 输入事件调用状态输入处理方法

### 3.2 BaseState (状态基类)

**主要属性**：
- `owner: Node` - 状态持有者(通常是角色/管理器)

**主要方法**：
- `enter(_prev_state: BaseState = null) -> void` - 进入状态时调用
- `exit(_next_state: BaseState = null) -> void` - 退出状态时调用
- `update(_delta: float) -> void` - 每逻辑帧更新时调用
- `physics_update(_delta: float) -> void` - 每物理帧更新时调用
- `handle_input(_event: InputEvent) -> void` - 处理输入事件时调用
- `is_valid() -> bool` - 状态有效性检查
- `handle_error(error_message: String) -> void` - 处理状态错误

## 4. 详细使用步骤

### 步骤1：创建状态类

创建继承自 `BaseState` 的状态类，实现必要的生命周期方法。

### 步骤2：创建状态机实例

在需要使用状态机的节点中创建 `BaseStateMachine` 实例。

### 步骤3：添加状态

使用 `add_state` 方法添加状态到状态机。

### 步骤4：设置初始状态

使用 `switch_state` 方法设置初始状态。

### 步骤5：集成到节点生命周期

在节点的 `_process`、`_physics_process` 和 `_input` 方法中调用状态机的对应方法。

## 5. 使用示例代码

### 5.1 示例1：角色状态管理

#### 状态定义

```gdscript
# 角色状态基类
class_name CharacterState extends BaseState

#  idle_state.gd
class_name IdleState extends CharacterState

func enter(_prev_state: BaseState = null) -> void:
    print("进入 idle 状态")
    # 播放 idle 动画

func exit(_next_state: BaseState = null) -> void:
    print("退出 idle 状态")

func update(_delta: float) -> void:
    # 检查输入，切换到其他状态
    if Input.is_action_pressed("ui_up"):
        owner.state_machine.switch_state("move")
    elif Input.is_action_pressed("ui_attack"):
        owner.state_machine.switch_state("attack")

# move_state.gd
class_name MoveState extends CharacterState

func enter(_prev_state: BaseState = null) -> void:
    print("进入 move 状态")
    # 播放移动动画

func exit(_next_state: BaseState = null) -> void:
    print("退出 move 状态")

func update(_delta: float) -> void:
    # 移动逻辑
    var direction = Vector2.ZERO
    if Input.is_action_pressed("ui_left"):
        direction.x -= 1
    if Input.is_action_pressed("ui_right"):
        direction.x += 1
    if Input.is_action_pressed("ui_up"):
        direction.y -= 1
    if Input.is_action_pressed("ui_down"):
        direction.y += 1
    
    if direction.length() > 0:
        owner.position += direction.normalized() * 100 * _delta
    else:
        # 没有输入，切换回 idle 状态
        owner.state_machine.switch_state("idle")

# attack_state.gd
class_name AttackState extends CharacterState

var attack_duration: float = 0.5
var elapsed_time: float = 0

func enter(_prev_state: BaseState = null) -> void:
    print("进入 attack 状态")
    # 播放攻击动画
    elapsed_time = 0

func exit(_next_state: BaseState = null) -> void:
    print("退出 attack 状态")

func update(_delta: float) -> void:
    elapsed_time += _delta
    if elapsed_time >= attack_duration:
        # 攻击结束，切换回 idle 状态
        owner.state_machine.switch_state("idle")
```

#### 角色类实现

```gdscript
# character.gd
class_name Character extends Node2D

var state_machine: BaseStateMachine

func _ready() -> void:
    # 创建状态机实例
    state_machine = BaseStateMachine.new()
    state_machine.owner = self
    
    # 添加状态
    state_machine.add_state(IdleState.new())
    state_machine.add_state(MoveState.new())
    state_machine.add_state(AttackState.new())
    
    # 设置初始状态
    state_machine.switch_state("idle")

func _process(delta: float) -> void:
    state_machine._process(delta)

func _physics_process(delta: float) -> void:
    state_machine._physics_process(delta)

func _input(event: InputEvent) -> void:
    state_machine._input(event)
```

### 5.2 示例2：游戏AI状态管理

#### 状态定义

```gdscript
# ai_state.gd
class_name AIState extends BaseState

# patrol_state.gd
class_name PatrolState extends AIState

var waypoints: Array = [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]
var current_waypoint: int = 0
var move_speed: float = 50

func enter(_prev_state: BaseState = null) -> void:
    print("进入巡逻状态")

func update(_delta: float) -> void:
    var target = waypoints[current_waypoint]
    var direction = (target - owner.position).normalized()
    owner.position += direction * move_speed * _delta
    
    if owner.position.distance_to(target) < 10:
        current_waypoint = (current_waypoint + 1) % waypoints.size()
    
    # 检查玩家是否在视野范围内
    if _is_player_in_sight():
        owner.state_machine.switch_state("chase")

func _is_player_in_sight() -> bool:
    # 实现视野检测逻辑
    return false

# chase_state.gd
class_name ChaseState extends AIState

var move_speed: float = 80

func enter(_prev_state: BaseState = null) -> void:
    print("进入追逐状态")

func update(_delta: float) -> void:
    var player = get_tree().get_root().get_node("Player")
    if player:
        var direction = (player.position - owner.position).normalized()
        owner.position += direction * move_speed * _delta
        
        # 检查是否到达攻击范围
        if owner.position.distance_to(player.position) < 50:
            owner.state_machine.switch_state("attack")
    else:
        # 找不到玩家，切换回巡逻状态
        owner.state_machine.switch_state("patrol")

# attack_state.gd
class_name AIAttackState extends AIState

var attack_cooldown: float = 1.0
var last_attack_time: float = 0

func enter(_prev_state: BaseState = null) -> void:
    print("进入攻击状态")

func update(_delta: float) -> void:
    var player = get_tree().get_root().get_node("Player")
    if player:
        # 检查玩家是否在攻击范围内
        if owner.position.distance_to(player.position) > 50:
            owner.state_machine.switch_state("chase")
        else:
            # 攻击逻辑
            if Time.get_time_dict_from_system()['second'] - last_attack_time > attack_cooldown:
                _attack()
                last_attack_time = Time.get_time_dict_from_system()['second']
    else:
        # 找不到玩家，切换回巡逻状态
        owner.state_machine.switch_state("patrol")

func _attack() -> void:
    print("AI 攻击玩家")
    # 实现攻击逻辑
```

#### AI类实现

```gdscript
# ai_controller.gd
class_name AIController extends Node2D

var state_machine: BaseStateMachine

func _ready() -> void:
    # 创建状态机实例
    state_machine = BaseStateMachine.new()
    state_machine.owner = self
    
    # 添加状态
    state_machine.add_state(PatrolState.new())
    state_machine.add_state(ChaseState.new())
    state_machine.add_state(AIAttackState.new())
    
    # 设置初始状态
    state_machine.switch_state("patrol")

func _process(delta: float) -> void:
    state_machine._process(delta)

func _physics_process(delta: float) -> void:
    state_machine._physics_process(delta)
```

## 6. 常见问题解答

### Q: 状态切换时，如何传递参数给新状态？
A: 目前的实现中，状态切换时没有直接传递参数的机制。可以通过在状态类中添加属性，在切换状态前设置这些属性来实现参数传递。

### Q: 如何实现状态转换条件的管理？
A: 目前的实现中，状态转换条件需要在状态的update方法中手动检查。可以考虑扩展BaseStateMachine，添加状态转换条件的管理机制。

### Q: 如何实现状态历史记录和回退？
A: 目前的实现中，没有状态历史记录的功能。可以通过在BaseStateMachine中添加一个状态历史栈来实现。

### Q: 如何处理状态机的暂停和恢复？
A: 可以在BaseStateMachine中添加pause和resume方法，控制是否调用状态的更新方法。

## 7. 未来可能的扩展方向

1. **状态转换条件管理**：添加状态转换条件的配置和管理机制，使状态转换更加灵活。

2. **状态历史记录**：实现状态历史栈，支持状态回退功能。

3. **状态机可视化**：添加状态机可视化编辑器，方便设计和调试状态机。

4. **并行状态**：支持并行状态，一个实体可以同时处于多个状态。

5. **状态机组合**：支持状态机的组合，一个状态可以是另一个状态机。

6. **状态持久化**：支持状态的保存和加载，方便游戏存档和读档。

7. **性能优化**：针对大型状态机进行性能优化，减少状态切换的开销。

## 8. 优势与局限性

### 优势

- **轻量级**：核心逻辑简单，代码量少，易于理解和使用。
- **灵活性**：状态可以自由定义和扩展，状态机可以动态添加和移除状态。
- **易于集成**：与Godot引擎的生命周期方法无缝集成。
- **错误处理**：提供基本的错误检测和处理机制。

### 局限性

- **状态切换时没有传递前一个状态和后一个状态的信息**：虽然方法签名中有参数，但调用时没有传递。
- **没有状态历史记录**：无法实现状态回退。
- **没有状态转换条件的管理**：状态转换需要外部逻辑控制。
- **没有状态机的暂停和恢复机制**：需要手动实现。
- **错误处理比较简单**：只是打印错误信息，没有更复杂的错误处理机制。

## 9. 结论

本状态机实现是一个轻量级、灵活的有限状态机框架，适合在Godot游戏引擎中使用。它提供了基本的状态管理和生命周期控制功能，可以满足大多数游戏开发中的状态管理需求。虽然存在一些局限性，但通过适当的扩展和定制，可以适应更复杂的场景。