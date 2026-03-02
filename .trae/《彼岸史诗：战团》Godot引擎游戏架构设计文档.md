# 《彼岸史诗：战团》Godot引擎游戏架构设计文档

# 一、架构核心设计原则

1. **模块化解耦**：每个功能模块抽象为独立节点/脚本，通过全局总线、管理器统筹调度，避免模块间直接依赖，便于调试、修改和扩展，充分贴合Godot节点树的分层特性。

2. **状态驱动**：以GameManager全局状态机为核心，统一管理游戏全生命周期，规避异步加载、状态切换的潜在冲突（如预加载与主菜单切换、战斗与加载状态衔接），确保状态流转清晰可追溯。

3. **数据标准化**：所有核心数据（卡牌、玩家、场景等）统一设计标准化数据结构，以JSON/CSV格式存储，支持存档读写、配置修改，降低开发与维护成本，同时便于学习阶段的数据调试。

4. **可扩展性**：预留多人模式、卡牌扩展、地图扩展接口，管理器与数据结构设计兼顾后续功能迭代，充分适配规则说明书中“待补充”的增益/减益效果、FAQ等内容。

# 一.1 核心数据结构定义

## 1.1.1 GameData（全局游戏数据）

核心全局数据结构，贯穿游戏生命周期，存储当前游戏状态数据。

```gdscript
# GameData.gd
class_name GameData

# 行动点
var current_action_point: int = 3  # 当前行动点
var max_action_point: int = 3      # 最大行动点

# 圣物能量
var sanctum_energy: int = 30       # 圣物初始能量
var max_sanctum_energy: int = 30   # 圣物最大能量

# 战斗状态
var battle_round: int = 0          # 当前回合数
var battle_time: float = 0.0       # 战斗持续时间

# 游戏难度
var game_difficulty: int = 0       # 0-简单, 1-普通, 2-困难

# 游戏模式
var game_mode: String = "single"  # single-单人模式, multi-多人模式

# 加载进度
var load_progress: float = 0.0     # 加载进度(0-1)
```

## 1.1.2 PlayerData（玩家数据）

存储玩家相关数据，包括卡组、等级、成就等。

```gdscript
# PlayerData.gd
class_name PlayerData

# 玩家基本信息
var player_id: String = ""         # 玩家唯一ID
var player_name: String = "Player" # 玩家名称
var player_level: int = 1          # 玩家等级
var player_exp: int = 0            # 玩家经验值

# 卡组数据
var deck: Array = []               # 玩家卡组（卡牌ID列表）
var hand_cards: Array = []         # 手牌（卡牌ID列表）
var draw_pile: Array = []          # 抽牌堆（卡牌ID列表）
var discard_pile: Array = []       # 弃牌堆（卡牌ID列表）

# 圣物数据
var sanctum_level: int = 1         # 圣物等级
var sanctum_protection: int = 0    # 圣物保护值

# 成就数据
var achievements: Dictionary = {}  # 成就完成情况

# 统计数据
var total_battles: int = 0         # 总战斗次数
var total_victories: int = 0       # 总胜利次数
var total_defeats: int = 0         # 总失败次数
```

## 1.1.3 CardData（卡牌数据）

存储卡牌相关数据，包括属性、效果等。

```gdscript
# CardData.gd
class_name CardData

# 卡牌基本信息
var card_id: String = ""           # 卡牌唯一ID
var card_name: String = ""         # 卡牌名称
var card_type: String = ""         # 卡牌类型（unit-单位卡, strategy-策略卡）
var card_cost: int = 0             # 卡牌费用（行动点）

# 单位卡属性（仅单位卡有效）
var attack: int = 0                # 攻击力
var health: int = 0                # 生命值
var position: Vector2 = Vector2(0, 0)  # 位置
var is_active: bool = false        # 是否激活
var cooldown: int = 0              # 冷却回合数

# 策略卡属性（仅策略卡有效）
var effect_id: String = ""         # 效果ID
var effect_range: Array = []       # 效果范围
var effect_duration: int = 0       # 效果持续时间

# 通用属性
var rarity: String = "common"      # 稀有度（common-普通, rare-稀有, epic-史诗, legendary-传说）
var description: String = ""       # 卡牌描述
var sprite_path: String = ""       # 卡牌精灵路径
```

## 1.1.4 配置文件Schema示例

### card_config.json Schema

```json
{
  "version": "1.0",
  "cards": [
    {
      "card_id": "card_001",
      "card_name": "步兵",
      "card_type": "unit",
      "card_cost": 1,
      "attack": 2,
      "health": 2,
      "rarity": "common",
      "description": "基础单位，具有中等攻击力和生命值",
      "sprite_path": "res://resources/cards/infantry.png"
    },
    {
      "card_id": "card_002",
      "card_name": "火球术",
      "card_type": "strategy",
      "card_cost": 2,
      "effect_id": "effect_fireball",
      "effect_range": ["enemy_unit"],
      "effect_duration": 1,
      "rarity": "common",
      "description": "对敌方单位造成3点伤害",
      "sprite_path": "res://resources/cards/fireball.png"
    }
  ]
}
```

### effect_config.json Schema

```json
{
  "version": "1.0",
  "effects": [
    {
      "effect_id": "effect_fireball",
      "effect_name": "火球术",
      "effect_type": "damage",
      "damage": 3,
      "target_type": "enemy_unit"
    },
    {
      "effect_id": "effect_heal",
      "effect_name": "治疗术",
      "effect_type": "heal",
      "heal": 2,
      "target_type": "friendly_unit"
    }
  ]
}
```

# 二、全局核心模块：GameManager（全局游戏总线状态机）

GameManager是整个游戏的核心枢纽，采用“状态机+全局总线”一体化设计，统一管理游戏生命周期状态，协调所有全局管理器，规避异步系统（如场景加载、资源预加载）的竞态问题。在Godot中以**Autoload自动加载节点**实现（全局唯一实例，可在任意脚本中直接访问），是所有模块交互的核心桥梁。

## 2.1 核心功能定位

- 状态统一管理：控制游戏从启动到退出的全生命周期状态切换，明确各状态的职责边界，杜绝状态混乱。

- 全局总线分发：作为信号中枢，接收各模块发送的信号（如卡牌使用、战斗胜负），并分发至对应管理器，避免模块间直接调用，降低耦合度。

- 异步协调：统一处理预加载、场景加载等异步操作，确保异步过程中状态稳定（如加载时禁止玩家操作、预加载完成后自动触发状态切换）。

- 全局异常处理：捕获游戏运行中的基础异常（如资源加载失败、数据读取错误），提供兜底方案（如默认配置 fallback），避免游戏崩溃，适合学习阶段的调试需求。

- 模块间逻辑衔接：统一协调各模块间的信号交互、数据传递和执行顺序，确保架构的联动性和一致性。

## 2.2 状态机设计（核心，贴合游戏规则与Godot生命周期）

采用有限状态机（FSM）设计，每个状态对应独立的逻辑处理类，所有状态统一继承自BaseState基类（定义统一接口），状态切换通过信号触发，避免硬编码，提升可维护性。

### 2.2.1 核心状态定义（覆盖游戏全生命周期）

#### PreloadState（预加载状态）
- **核心功能**：
  1. 加载全局配置（卡牌、场景、圣物等基础配置）
  2. 预加载核心资源（卡牌精灵、场景预制体、音效）
  3. 初始化所有全局管理器
  4. 检测存档文件是否存在，为后续读档做准备
- **Godot实现要点**：
  - 使用Godot的ResourceLoader异步加载资源，通过await等待加载完成
  - 初始化所有Autoload管理器，触发管理器的_init()方法
  - 同步更新预加载进度至GameData
  - 实现加载失败的重试逻辑
- **切换条件**：
  - 预加载完成（资源加载率100%）→ 切换至MainMenuState
  - 加载失败（重试3次后）→ 显示错误状态

#### MainMenuState（主菜单状态）
- **核心功能**：
  1. 显示主菜单UI（开始游戏、加载存档、设置、退出）
  2. 响应菜单操作
  3. 监听ArchiveManager的存档列表信号，显示已存在存档
- **Godot实现要点**：
  - 通过UIManager控制菜单UI显示/隐藏
  - 绑定按钮信号（如开始游戏按钮→触发状态切换）
  - 禁用战斗相关模块，避免资源浪费
- **切换条件**：
  - 点击“开始游戏”→ LoadState
  - 点击“加载存档”→ LoadState（携带存档ID）
  - 点击“退出”→ QuitState

#### LoadState（加载状态）
- **核心功能**：
  1. 加载对应场景（单人Demo战斗场景）
  2. 读取玩家存档（若有）
  3. 初始化战斗所需数据（卡组、圣物能量、行动点）
  4. 显示加载进度条，同步进度至UIManager
- **Godot实现要点**：
  - 使用SceneManager异步加载战斗场景，通过await获取加载进度
  - 调用ArchiveManager读取存档数据，映射为PlayerData
  - 同步初始化CardManager的卡组数据
  - 处理存档读取失败的兜底逻辑
- **切换条件**：
  - 场景加载完成+数据初始化完成→ RunState
  - 加载失败→ 显示错误状态

#### RunState（运行/战斗状态）
- **核心功能**：
  1. 启动战斗逻辑（回合流程、卡牌操作、敌方AI）
  2. 监听战斗相关信号（卡牌使用、圣物受伤、敌方死亡）
  3. 同步更新UI（行动点、圣物能量、卡牌手牌）
  4. 实时判定战斗胜负
- **Godot实现要点**：
  - 绑定战斗模块信号（如CardManager的卡牌使用信号、BattleManager的胜负信号）
  - 通过UIManager实时更新战斗UI
  - 每帧调用BattleManager的回合逻辑，确保战斗流畅
  - 处理后台切出的暂停逻辑
- **切换条件**：
  - 战斗胜利/失败→ EndState
  - 点击暂停→ PauseState
  - 后台切出→ PauseState

#### PauseState（暂停状态）
- **核心功能**：
  1. 暂停战斗逻辑（停止回合计时、禁用卡牌操作）
  2. 显示暂停菜单（继续、重新开始、返回主菜单）
  3. 保存当前战斗临时进度至存档
- **Godot实现要点**：
  - 设置战斗节点的process_mode为PAUSED
  - 通过UIManager显示暂停UI
  - 调用ArchiveManager保存临时存档，确保进度不丢失
  - 暂停时音乐降速处理
- **切换条件**：
  - 点击“继续”→ RunState
  - 点击“重新开始”→ LoadState
  - 点击“返回主菜单”→ MainMenuState

#### EndState（战斗结束状态）
- **核心功能**：
  1. 显示战斗结果（胜利/失败）
  2. 结算战利品（若胜利，规则说明书未明确，预留接口）
  3. 保存战斗结果至存档
  4. 提供返回主菜单/重新挑战选项
- **Godot实现要点**：
  - 通过UIManager显示结果UI
  - 调用ArchiveManager更新存档（圣物状态、卡组变化、战斗进度）
  - 绑定结果菜单按钮信号，触发对应状态切换
- **切换条件**：
  - 点击“返回主菜单”→ MainMenuState
  - 点击“重新挑战”→ LoadState

#### QuitState（退出状态）
- **核心功能**：
  1. 保存当前游戏状态（临时存档）
  2. 释放已加载的非核心资源
  3. 关闭游戏进程，确保资源正常释放
- **Godot实现要点**：
  - 调用ArchiveManager保存退出存档
  - 使用ResourceLoader.unload()释放非核心资源
  - 调用get_tree().quit()退出游戏，贴合Godot生命周期规范
- **切换条件**：
  - 退出完成→ 游戏终止

#### ErrorState（错误状态）
- **核心功能**：
  1. 显示错误信息（如加载失败、配置错误）
  2. 提供重试/返回主菜单选项
  3. 记录错误日志
- **Godot实现要点**：
  - 通过UIManager显示错误UI
  - 提供重试按钮触发状态切换
  - 与LogManager联动，记录错误信息
- **切换条件**：
  - 点击“重试”→ 触发错误前状态
  - 点击“返回主菜单”→ MainMenuState
### 2.2.2 状态机核心实现（Godot脚本示例，符合开发规范）

```gdscript
# GameManager.gd（AutoLoad节点）
extends Node
class_name GameManager

# 状态枚举（统一管理，避免字符串硬编码）
enum GameState {
    PRELOAD,
    MAIN_MENU,
    LOAD,
    RUN,
    PAUSE,
    END,
    QUIT,
    ERROR
}

# 当前状态
var current_state: GameState = GameState.PRELOAD
# 状态实例字典（存储各状态对象，便于统一管理）
var state_instances: Dictionary = {}
# 信号优先级字典（控制信号执行顺序）
var signal_priorities: Dictionary = {
    "battle_victory": 10,
    "battle_defeat": 10,
    "sanctum_hurt": 8,
    "card_used": 7,
    "effect_trigger": 6,
    "save_trigger": 5,
    "scene_load_progress": 4,
    "preload_complete": 3,
    "scene_switch": 2
}
# 信号连接字典（用于信号注销）
var signal_connections: Dictionary = {}

# 全局管理器引用（Autoload节点加载后直接访问，规范命名）
var archive_manager: ArchiveManager
var ui_manager: UIManager
var scene_manager: SceneManager
var card_manager: CardManager
var light_manager: LightManager # 新增LightManager全局引用
var config_manager: ConfigManager # 新增ConfigManager全局引用
var resource_manager: ResourceManager # 新增ResourceManager全局引用
var player_data_manager: PlayerDataManager # 新增PlayerDataManager全局引用
var log_manager: LogManager # 新增LogManager全局引用
var network_manager: NetworkManager # 新增NetworkManager全局引用
var game_data: GameData  # 全局数据引用

func _ready():
    # 初始化全局数据（全局唯一，贯穿游戏生命周期）
    game_data = GameData.new()
    # 初始化全局管理器（通过节点路径访问，确保加载顺序）
    archive_manager = get_node("/root/ArchiveManager")
    ui_manager = get_node("/root/UIManager")
    scene_manager = get_node("/root/SceneManager")
    card_manager = get_node("/root/CardManager")
    light_manager = get_node("/root/LightManager") # 初始化LightManager
    config_manager = get_node("/root/ConfigManager") # 初始化ConfigManager
    resource_manager = get_node("/root/ResourceManager") # 初始化ResourceManager
    player_data_manager = get_node("/root/PlayerDataManager") # 初始化PlayerDataManager
    log_manager = get_node("/root/LogManager") # 初始化LogManager
    network_manager = get_node("/root/NetworkManager") # 初始化NetworkManager
    
    # 初始化所有状态（传入自身引用，便于状态访问管理器）
    state_instances[GameState.PRELOAD] = PreloadState.new(self)
    state_instances[GameState.MAIN_MENU] = MainMenuState.new(self)
    state_instances[GameState.LOAD] = LoadState.new(self)
    state_instances[GameState.RUN] = RunState.new(self)
    state_instances[GameState.PAUSE] = PauseState.new(self)
    state_instances[GameState.END] = EndState.new(self)
    state_instances[GameState.QUIT] = QuitState.new(self)
    state_instances[GameState.ERROR] = ErrorState.new(self)
    
    # 启动初始状态（预加载状态）
    enter_state(current_state)

# 状态切换核心方法（统一处理状态退出与进入）
func enter_state(new_state: GameState):
    # 退出当前状态（退出前执行清理逻辑）
    if current_state != GameState.QUIT:
        state_instances[current_state].exit()
    # 更新当前状态并进入新状态
    current_state = new_state
    state_instances[current_state].enter()
    # 场景切换时同步切换光照配置
    if new_state == GameState.MAIN_MENU:
        light_manager.switch_scene_light("main_menu")
    elif new_state == GameState.RUN:
        light_manager.switch_scene_light("battle")

# 每帧执行当前状态逻辑（普通帧，用于UI、逻辑更新）
func _process(delta: float):
    if current_state != GameState.QUIT:
        state_instances[current_state].process(delta)

# 物理帧执行当前状态逻辑（用于战斗物理交互，如碰撞检测，可选）
func _physics_process(delta: float):
    if current_state == GameState.RUN:
        state_instances[current_state].physics_process(delta)

# 全局信号分发（各模块通过此方法发送信号，避免直接绑定，降低耦合）
func dispatch_signal(signal_name: String, vararg args):
    # 按优先级排序信号执行
    emit_signal(signal_name, args)

# 全局信号绑定（各模块注册信号监听，统一管理）
func bind_signal(signal_name: String, callable: Callable):
    var connection = connect(signal_name, callable)
    if not signal_connections.has(signal_name):
        signal_connections[signal_name] = []
    signal_connections[signal_name].append(connection)

# 全局信号注销（避免内存泄漏）
func unbind_signal(signal_name: String, callable: Callable):
    if signal_connections.has(signal_name):
        for connection in signal_connections[signal_name]:
            if connection.callable == callable:
                disconnect(signal_name, callable)
                signal_connections[signal_name].erase(connection)
                break

# 调试接口（贴合学习场景，便于测试战斗逻辑）
func debug_force_victory():
    if current_state == GameState.RUN:
        dispatch_signal("battle_victory")
func debug_force_defeat():
    if current_state == GameState.RUN:
        dispatch_signal("battle_defeat")
func debug_add_action_point(count: int = 1):
    game_data.current_action_point = min(game_data.current_action_point + count, game_data.max_action_point)
    ui_manager.update_ui("UI_Battle", {"current_action_point": game_data.current_action_point})
func debug_set_sanctum_energy(energy: int):
    game_data.sanctum_energy = energy
    ui_manager.update_ui("UI_Battle", {"sanctum_energy": game_data.sanctum_energy})
func debug_unlock_all_cards():
    card_manager.unlock_all_cards()
func debug_clear_deck():
    card_manager.clear_deck()

# 异常处理方法
func handle_exception(error: String, error_type: String = "general", retryable: bool = false):
    log_manager.log("ERROR", error)
    ui_manager.show_error_message(error)
    
    # 根据错误类型执行不同的恢复策略
    match error_type:
        "resource_load":
            # 资源加载失败，尝试使用默认资源
            resource_manager.load_default_resources()
            if retryable:
                enter_state(GameState.ERROR)
            else:
                # 不可重试的资源加载错误，使用默认资源继续游戏
                ui_manager.show_error_message("资源加载失败，使用默认资源继续游戏")
        "network":
            # 网络异常，尝试重连
            if retryable:
                # 尝试断线重连
                network_manager.attempt_reconnect()
                enter_state(GameState.ERROR)
            else:
                # 网络错误不可重试，返回主菜单
                ui_manager.show_error_message("网络连接失败，返回主菜单")
                enter_state(GameState.MAIN_MENU)
        "data_corruption":
            # 数据损坏，尝试使用备份数据
            archive_manager.load_backup_save()
            if retryable:
                enter_state(GameState.ERROR)
            else:
                # 数据损坏不可恢复，返回主菜单
                ui_manager.show_error_message("数据损坏，返回主菜单")
                enter_state(GameState.MAIN_MENU)
        "general":
            # 通用错误
            if retryable:
                enter_state(GameState.ERROR)
            else:
                # 不可重试的错误，返回主菜单
                enter_state(GameState.MAIN_MENU)
```

### 2.2.3 全局总线信号设计（核心信号列表，统一管理）

所有信号由GameManager统一分发，各模块仅需监听对应信号，无需直接关联，降低耦合度，便于后续扩展和修改：

- preload_complete：预加载完成信号（触发主菜单状态切换，通知UIManager显示主菜单）

- scene_load_progress：场景加载进度信号（用于加载UI进度条更新，传递进度参数）

- battle_start：战斗开始信号（触发战斗逻辑初始化，通知各本地管理器启动）

- battle_victory：战斗胜利信号（触发结束状态切换，通知ArchiveManager保存胜利结果）

- battle_defeat：战斗失败信号（触发结束状态切换，通知ArchiveManager保存失败结果）

- card_used：卡牌使用信号（通知UI更新、战斗逻辑结算，传递卡牌ID、使用目标参数）

- sanctum_hurt：圣物受伤信号（通知UI更新圣物能量、判定失败条件，传递伤害值参数）

- save_trigger：存档触发信号（通知存档管理器保存数据，传递存档ID参数）

- effect_trigger：效果触发信号（通知EffectManager施加/移除效果，传递效果ID、目标参数）

- scene_switch：场景切换信号（通知LightManager切换对应场景光照配置，传递场景名称参数）

- game_paused：游戏暂停信号（通知各模块暂停相关逻辑，传递暂停状态参数）

- game_resumed：游戏恢复信号（通知各模块恢复相关逻辑，传递恢复状态参数）

- error_occurred：错误发生信号（通知错误处理逻辑，传递错误信息参数）

# 三、多管理器系统（模块抽象，Godot Autoload+节点树结合）

采用“全局管理器+本地管理器”双层架构，所有管理器均抽象为独立模块，实现功能模块化、可复用。全局管理器由GameManager统筹，注册为Godot Autoload节点，负责跨场景、全局生效的功能；本地管理器作为场景内节点，随场景加载/销毁，负责当前场景内的局部功能，避免全局资源占用，贴合Godot节点树的生命周期特性。

## 3.1 全局管理器（Autoload自动加载，全局唯一）

所有全局管理器均注册为Godot Autoload节点，由GameManager在预加载阶段初始化和统筹，可通过GameManager访问，也可直接通过节点路径（/root/管理器名称）访问，确保全局可调用、状态统一。

### 3.1.1 ArchiveManager（存档管理器）

核心功能：负责所有游戏数据的持久化，支持存档创建、读取、更新、删除，数据格式统一为JSON（便于Godot解析，且易修改、易学习），贴合规则说明书中的卡牌、玩家、圣物等数据需求，确保存档安全、读写高效。

- 存档路径：Godot用户目录（user://saves/），每个存档对应一个JSON文件（如save_1.json），避免系统权限问题，同时便于玩家查找和备份。

- 核心功能：

- 存档创建：新游戏时，生成默认玩家数据（PlayerData）、卡组数据、圣物数据，保存为新存档，同时记录存档时间。

- 存档读取：加载游戏时，根据存档ID读取对应JSON文件，解析为对应数据结构（PlayerData、GameData等），传递给对应管理器，支持旧存档版本兼容。

- 存档更新：战斗过程中（暂停、结束）、退出游戏时，同步更新存档数据（如圣物能量、卡组变化、战斗进度），确保进度不丢失。

- 存档删除：主菜单中提供删除存档功能，删除对应JSON文件，同时更新存档列表显示。

- 兜底处理：若存档文件损坏或不存在，自动报错并生成默认存档（避免游戏崩溃，适合学习调试阶段的错误处理）。

- 数据加密：实现简单的数据加密方案，对存档文件进行加密处理，防止玩家篡改存档数据，确保游戏公平性。

- 自动存档：支持战斗每回合自动存档，可配置自动存档频率（如每回合结束、每使用3张卡牌后），确保游戏进度不会因意外情况丢失。

- 存档回滚：提供存档回滚功能，允许玩家恢复到上一存档点，避免误操作导致的游戏进度损失。

- 多存档管理：支持多个存档的管理，包括存档数量上限（如最多10个存档）、存档重命名、覆盖、备份等功能，提升玩家体验。

- Godot实现要点：

- 使用Godot的File类操作JSON文件（file.open、file.store_line、file.get_as_text），严格遵循文件读写规范，避免文件损坏。

- 通过JSON.parse()将JSON文本解析为Dictionary，再映射为对应数据结构（如PlayerData），解析过程中添加数据校验，避免异常数据。

- 实现简单的加密算法（如XOR加密）对存档数据进行加密，确保数据安全性。

- 绑定GameManager的save_trigger信号，触发存档更新；提供存档列表查询方法，供主菜单UI显示。

- 与GameData、PlayerData深度联动，实现全局数据与存档数据的同步。

- 关联数据：PlayerData、CardData、SceneData、GameData（全局变量），所有存档数据均围绕这些核心数据结构展开。

### 3.1.2 UIManager（UI管理器）

核心功能：统一管理所有UI界面（主菜单、加载界面、战斗UI、暂停菜单、结束界面），负责UI的显示、隐藏、更新，避免UI逻辑散落在各个脚本中，贴合规则说明书中的战斗UI需求（行动点、圣物能量、卡牌手牌等），确保UI交互统一、流畅。

- UI层级设计（Godot节点树层级，从上到下，贴合Godot UI管理规范）：

- UI_Root（根节点，Control类型）：包含所有UI界面节点，设置锚点适配不同分辨率。

- UI_Preload：预加载进度条界面（仅PreloadState显示），显示资源加载进度。

- UI_MainMenu：主菜单界面（仅MainMenuState显示），包含开始游戏、加载存档等按钮。

- UI_Load：加载界面（仅LoadState显示），显示场景加载进度条。

- UI_Battle：战斗UI（仅RunState显示），包含：

  - UI_Sanctum：圣物能量显示、圣物状态提示。

  - UI_ActionPoint：行动点显示（当前/上限），实时更新。

  - UI_HandCard：手牌显示、卡牌点击交互，支持卡牌拖拽。

  - UI_UnitArea：玩家前后排区域、单位卡显示，显示单位血量、状态。

  - UI_EnemyArea：敌方区域、敌方单位显示，显示敌方血量、状态。

  - UI_FightInfo：战斗信息提示（如技能触发、伤害结算），自动消失。

- UI_Pause：暂停菜单界面（仅PauseState显示），包含继续、重新开始等选项。

- UI_End：战斗结束界面（仅EndState显示），显示战斗结果、战利品信息。

核心功能：

1. UI显示/隐藏：提供show_ui(ui_name)、hide_ui(ui_name)方法，控制对应UI节点的visible属性，避免多个UI同时显示。

2. UI更新：提供update_ui(ui_name, data)方法，根据数据更新UI（如更新圣物能量、行动点、手牌），数据格式统一为Dictionary，便于扩展。

3. UI交互绑定：统一绑定UI按钮、卡牌的点击信号，传递给对应管理器（如卡牌点击→CardManager），避免交互逻辑分散。

4. 提示信息管理：统一管理战斗提示、错误提示（如行动点不足、法强不够），避免重复创建提示节点，提升性能。

5. 多屏幕比例适配：实现不同屏幕比例（如16:9/21:9）的UI布局调整，确保在不同设备上的显示效果一致。

6. 卡牌拖拽交互：实现卡牌的拖拽判定、释放逻辑和取消处理，提升玩家操作体验。

7. UI缓存/复用：实现UI节点池设计，避免大量动态生成UI节点导致的性能下降。

8. 提示反馈体系：实现统一的提示分级（普通提示/重要提示/错误提示），并设置不同的视觉和音效反馈。

9. 设置功能落地：实现音量、画质、振动、语言等设置的持久化和实时生效逻辑。

Godot实现要点：

1. 所有UI节点均为Control类型，通过anchor_point和margin适配不同分辨率，确保在不同设备上显示正常。

2. 使用信号绑定UI交互（如按钮pressed信号→调用对应状态方法），避免硬编码回调。

3. 手牌、单位卡使用Godot的TextureRect或Sprite2D显示，通过动态生成节点实现卡牌复用（避免大量预制体，降低资源占用）。

4. 与GameManager、CardManager、BattleManager联动，接收信号并更新UI，确保UI与游戏逻辑同步。

5. 多屏幕比例适配实现：
   - 使用Container节点（如VBoxContainer、HBoxContainer）自动调整UI元素布局。
   - 针对不同屏幕比例设置不同的UI布局配置，通过代码动态调整。
   - 移动端触控区域放大处理，确保触控操作的准确性。

6. 卡牌拖拽交互实现：
   - 使用InputEvent处理鼠标/触屏拖拽事件。
   - 实现拖拽判定范围，确保拖拽操作的准确性。
   - 拖拽释放后的卡牌部署逻辑，根据释放位置判断部署区域。
   - 拖拽取消的处理，当拖拽超出有效区域时取消操作。

7. UI缓存/复用实现：
   - 实现UI节点池，预创建常用UI元素（如提示框、卡牌显示）。
   - 当需要显示UI元素时，从节点池获取，使用完毕后回收，避免频繁创建和销毁节点。
   - 针对战斗信息提示，使用对象池模式管理提示节点，提升性能。

### 3.1.3 SceneManager（场景管理器）

核心功能：负责场景的加载、卸载、切换，处理异步加载逻辑，避免场景切换时的卡顿，统筹所有游戏场景（主菜单场景、战斗场景等），贴合规则说明书中的肉鸽地图、战斗场地需求，预留随机地图生成接口。

- 场景划分（Godot场景文件，按功能分类，便于管理）：

- scene_main_menu.tscn：主菜单场景（包含UI_MainMenu节点，无战斗逻辑）。

- scene_battle.tscn：战斗场景（包含玩家区域、敌方区域、圣物节点、战斗逻辑节点，所有本地管理器均在此场景下）。

- scene_load.tscn：加载过渡场景（可选，用于场景切换过渡，提升用户体验）。

- 核心功能：

- 异步加载场景：提供load_scene_async(scene_path)方法，返回加载进度，通过scene_load_progress信号传递给UIManager更新进度条。

- 场景卸载：切换场景前，卸载当前场景（释放场景资源、销毁本地管理器），避免内存泄漏。

- 场景切换：加载完成后，切换到目标场景，初始化场景内的本地管理器（如BattleManager、AudioManager），传递必要的初始化数据。

- Roguelike地图适配：预留随机地图生成接口（规则说明书中的随机生成式Roguelike地图），可动态生成战斗场景中的地形、敌人部署，支持地图参数配置。

- Godot实现要点：

- 使用get_tree().change_scene_to_file()切换场景，异步加载使用ResourceLoader.load_async()，避免场景切换卡顿。

- 场景加载完成后，通过get_tree().current_scene获取当前场景节点，遍历场景内的本地管理器节点，调用初始化方法。

- Roguelike地图可通过TileMap节点动态生成，结合随机算法生成不同的战斗场地布局，关联roguelike_map_config配置参数。

- 与GameManager、ArchiveManager联动，接收场景切换信号，传递存档数据，恢复场景状态；与LightManager联动，场景切换时触发光照配置更新。

### 3.1.4 CardManager（卡牌管理器）

核心功能：统筹所有卡牌相关逻辑，包括卡组构筑、卡牌加载、卡牌使用、卡牌效果结算，严格贴合规则说明书中的卡牌类型（单位卡、策略卡、敌方卡牌）及使用规则，确保卡牌逻辑统一、可扩展。

- 核心功能：

- 卡牌加载：从JSON配置文件（res://config/card_config.json）中加载所有卡牌数据（CardData），缓存卡牌资源（精灵、描述），支持动态扩展卡牌（新增卡牌仅需修改JSON，无需修改核心逻辑）。

- 卡组构筑：根据玩家存档或初始配置，生成玩家卡组（无限制，贴合规则说明书），管理手牌、抽牌堆、弃牌堆的逻辑（抽牌堆耗尽时洗匀弃牌堆，转为抽牌堆）。

- 卡牌使用校验：使用卡牌前，校验使用条件（行动点是否充足、法强是否达标、区域是否符合要求、单位是否激活），不符合则通过UIManager触发提示，避免非法操作。

- 卡牌效果结算：执行卡牌使用后的效果（单位激活、技能发动、策略卡效果），触发card_used、effect_trigger等信号，通知战斗逻辑结算。

- 敌方卡牌管理：加载敌方卡牌数据（EnemyCardData），管理敌方单位的部署、行动、技能触发（贴合规则说明书中的敌方行动规则、意图-概率判定机制）。

- 卡牌接口定义：定义卡牌类型接口（IUnitCard、IStrategyCard），明确接口方法、参数和返回值，确保不同类型卡牌的实现标准统一。

- 敌方卡组构筑：实现敌方卡组的随机生成/配置加载逻辑，根据难度级别调整敌方卡组的强度和多样性，确保不同难度的游戏体验。

- 卡牌冷却/禁用逻辑：实现卡牌使用后的冷却时间计算、冷却状态管理，以及卡牌禁用的处理逻辑，确保卡牌使用规则的正确执行。

- Godot实现要点：

- 卡牌数据存储为JSON文件，通过ArchiveManager加载，映射为CardData数据结构，加载时添加数据校验，避免无效卡牌。

- 卡牌显示使用Sprite2D+Label组合，动态生成手牌、场上单位卡，绑定点击信号（如单位卡点击→激活/位移），支持卡牌状态切换（激活/冷却）。

- 卡牌效果通过接口实现（如IUnitCard、IStrategyCard），不同类型卡牌实现不同的效果逻辑，便于扩展新卡牌类型。

- 与GameManager、BattleManager、UIManager联动，接收信号、校验条件、更新UI，确保卡牌逻辑与战斗逻辑同步；与LightManager、ParticleManager联动，技能触发时同步触发光照、粒子特效。

- 关联规则：严格遵循规则说明书中的卡牌使用时机、费用规则、部署规则、效果结算规则（如法强≥技能费用、激活后位移触发冷却等），确保与规则一致。

**接口定义示例：**

```gdscript
# ICard.gd（卡牌基础接口）
class ICard:
    func use(target: Node) -> bool: pass
    func get_cost() -> int: pass
    func get_type() -> String: pass

# IUnitCard.gd（单位卡接口）
class IUnitCard extends ICard:
    func activate() -> bool: pass
    func get_health() -> int: pass
    func get_attack() -> int: pass
    func get_position() -> Vector2: pass

# IStrategyCard.gd（策略卡接口）
class IStrategyCard extends ICard:
    func get_effect_range() -> Array: pass
    func get_effect_duration() -> int: pass
```

### 3.1.5 LightManager（光照管理器，全局管理器）

核心功能：管理全游戏所有场景的光照效果，营造不同场景的氛围（主菜单静谧感、战斗场景紧张感、圣物发光效果等），属于全局视觉优化模块，贴合Godot的光照系统，提升全游戏视觉表现力，同时控制性能消耗，适配所有场景的光照需求。

- 核心功能：

- 光照初始化：游戏启动（预加载阶段）初始化全局光照配置，加载各场景对应的光照参数（主菜单、战斗场景等），场景切换时自动切换光照配置，无需重复初始化；初始化时绑定GameManager的scene_switch信号，同步响应场景切换。

- 光照切换：根据当前场景类型、游戏状态（如圣物受伤、战斗胜利、技能发动）切换光照效果，主菜单保持柔和固定光照，战斗场景根据战斗节奏动态调整（如圣物受伤时光照变暗、技能发动时光照变亮），增强视觉冲击；提供switch_scene_light(scene_name)方法，供GameManager调用切换场景光照。

- 性能优化：控制各场景光照节点数量、光照范围与强度，避免过多光照节点导致性能下降（适合学习阶段的性能控制），优先使用Godot的Light2D基础节点，降低开发复杂度；场景卸载时自动释放对应场景光照资源，避免内存泄漏。

- 全局光照统一：统一管理全游戏光照风格，确保主菜单、战斗场景等光照效果连贯统一，提升游戏整体视觉一致性；支持全局光照参数调节（如亮度、对比度），可通过设置界面配置，与UIManager联动实现参数调节。

- Godot实现要点：注册为Godot AutoLoad全局节点，确保全场景可访问；使用Godot的Light2D节点（DirectionalLight2D、PointLight2D），通过修改light_energy、light_color、light_range等属性实现光照效果切换；绑定GameManager的场景切换、战斗相关信号（如sanctum_hurt、battle_victory、scene_switch），自动触发光照变化；与ParticleManager协同，强化各场景视觉效果，适配不同场景的氛围需求；提供光照调试接口，便于学习阶段测试不同光照效果。

- 关联模块：与GameManager、SceneManager联动，接收场景切换信号，切换对应场景光照配置；与ParticleManager、CameraManager协同，优化各场景视觉层次感；与UIManager联动，支持通过设置界面调节全局光照参数，提升玩家体验；与CardManager、BattleManager联动，技能触发、战斗状态变化时同步调整光照。

### 3.1.6 ConfigManager（配置管理器，全局管理器）

核心功能：统一管理所有游戏配置文件的加载、解析、缓存与版本控制，避免配置加载逻辑分散在各管理器中，提升配置管理的一致性和可维护性，贴合“模块化解耦”的核心设计原则。

- 核心功能：

- 配置加载：从res://config/目录加载所有配置文件（卡牌配置、道具配置、效果配置、AI配置等），统一解析为标准化数据结构，支持JSON/CSV格式，确保配置数据的一致性。

- 配置缓存：缓存已加载的配置数据，避免重复加载导致性能消耗，提供配置数据的快速访问接口，供各管理器调用。

- 版本管理：支持配置文件的版本号管理，处理不同版本配置的兼容逻辑，确保游戏在配置更新后仍能正常运行。

- 多环境配置：支持开发/测试/生产环境的配置切换，通过环境变量或配置文件指定当前环境，加载对应环境的配置参数。

- 配置热更新：支持游戏运行时的配置热更新（如调整AI难度、修改卡牌属性），无需重启游戏即可生效，提升开发调试效率。

- Godot实现要点：注册为Godot AutoLoad全局节点，在预加载阶段初始化；使用File类读取配置文件，通过JSON.parse()或CSV解析器解析配置数据；维护配置缓存字典，键为配置类型，值为配置数据；提供get_config(config_type)方法，供各管理器获取配置数据；绑定GameManager的preload_complete信号，确保配置加载完成后再初始化其他管理器。

- 关联模块：与CardManager、ItemManager、BattleManager联动，提供卡牌、道具、AI等配置数据；与ArchiveManager联动，处理存档数据与配置数据的版本兼容；与LogManager联动，记录配置加载过程中的异常信息。

### 3.1.7 ResourceManager（资源管理器，全局管理器）

核心功能：统一管理游戏所有资源的加载、缓存、释放，避免资源重复加载导致内存泄漏，提升资源管理的效率和一致性，确保游戏在资源较多时仍能保持良好性能。

- 核心功能：

- 资源预加载：在PreloadState阶段，根据配置文件预加载核心资源（卡牌精灵、场景预制体、音效、粒子特效等），通过GameManager的preload_complete信号通知预加载完成。

- 资源缓存：缓存已加载的资源，避免重复加载，提供资源的快速访问接口，供各管理器调用。

- 资源释放：在场景切换、游戏退出时，释放非核心资源，避免内存泄漏，确保资源使用的合理性。

- 资源懒加载：对于非核心资源（如部分特效、音效），采用懒加载策略，仅在需要时加载，减少初始加载时间。

- 资源状态监控：监控资源加载状态，记录资源使用情况，便于调试和性能优化。

- Godot实现要点：注册为Godot AutoLoad全局节点，在预加载阶段初始化；使用ResourceLoader.load()或ResourceLoader.load_async()加载资源；维护资源缓存字典，键为资源路径，值为资源对象；提供load_resource(resource_path)、get_resource(resource_path)、unload_resource(resource_path)方法；与GameManager联动，处理预加载和资源释放逻辑；与LogManager联动，记录资源加载过程中的异常信息。

- 关联模块：与CardManager、AudioManager、ParticleManager联动，提供卡牌精灵、音效、粒子特效等资源；与SceneManager联动，处理场景资源的加载和释放；与LightManager联动，提供光照相关资源。

### 3.1.8 PlayerDataManager（玩家数据管理器，全局管理器）

核心功能：统一管理玩家数据的存储、更新、校验，处理玩家等级/成就/养成等系统，确保玩家数据的安全性和一致性，为后续扩展多人模式/养成系统奠定基础。

- 核心功能：

- 数据初始化：从ArchiveManager读取玩家存档数据，初始化PlayerData结构，确保数据的完整性和正确性。

- 数据更新：处理玩家数据的实时更新（如等级提升、成就解锁、卡组变化），确保数据的同步性。

- 数据校验：对玩家数据进行校验，防止数据篡改和异常数据，确保游戏的公平性和稳定性。

- 多存档管理：支持多个玩家存档的管理，包括存档的创建、切换、删除，确保多存档的隔离性。

- 养成系统支持：预留玩家养成系统接口，如等级提升、技能点分配、装备管理等，为后续扩展提供基础。

- Godot实现要点：注册为Godot AutoLoad全局节点，在预加载阶段初始化；与ArchiveManager联动，读取和保存玩家数据；维护PlayerData实例，提供数据访问和更新接口；实现数据校验逻辑，确保数据的合法性；提供多存档管理方法，如create_save(save_id)、load_save(save_id)、delete_save(save_id)。

- 关联模块：与ArchiveManager联动，处理玩家数据的持久化；与GameManager联动，同步玩家数据的状态变化；与UIManager联动，更新玩家数据相关的UI显示。

### 3.1.9 LogManager（日志管理器，全局管理器）

核心功能：统一管理游戏的日志系统，包括开发调试日志、运行时错误日志、玩家行为日志，提升调试和问题排查的效率，贴合学习阶段的调试需求。

- 核心功能：

- 日志分级：支持不同级别的日志（DEBUG、INFO、WARNING、ERROR、FATAL），根据日志级别控制日志的输出和存储。

- 日志输出：支持日志输出到控制台、文件、UI界面，满足不同场景的日志查看需求。

- 日志存储：将重要日志存储到本地文件（user://logs/），便于问题排查和分析。

- 错误捕获：捕获游戏运行中的异常，记录错误堆栈信息，便于定位和解决问题。

- 性能分析：记录关键操作的执行时间，便于性能优化和瓶颈定位。

- Godot实现要点：注册为Godot AutoLoad全局节点，在预加载阶段初始化；使用File类写入日志文件；提供log(level, message)方法，供各模块调用；实现错误捕获逻辑，通过try-except捕获异常并记录；与GameManager联动，处理全局异常的日志记录。

- 关联模块：与所有管理器联动，记录各模块的运行状态和异常信息；与UIManager联动，在UI界面显示重要日志信息。

### 3.1.10 NetworkManager（网络管理器，全局管理器）

核心功能：负责游戏的网络通信，包括多人模式的连接管理、数据同步和断线重连机制，为多人模式提供稳定的网络支持。

- 核心功能：
- 连接管理：处理网络连接的建立、维护和断开，支持WebSocket或TCP/IP协议。
- 数据同步：实现玩家数据、卡牌操作、战斗状态的实时同步，确保多玩家间的游戏状态一致。
- 断线重连：实现断线重连机制，当网络连接断开时，尝试自动重连，恢复游戏状态。
- 网络异常处理：处理网络延迟、丢包等异常情况，提供友好的错误提示和恢复策略。
- 流量优化：优化网络传输数据量，减少带宽占用，提升网络传输效率。
- Godot实现要点：
  - 注册为Godot Autoload全局节点，在预加载阶段初始化
  - 使用Godot的WebSocketClient实现网络通信：
    - 初始化WebSocketClient并设置服务器地址和端口
    - 连接到服务器：`websocket_client.connect_to_url(server_url)`
    - 监听连接状态信号：`connected`、`connection_closed`、`connection_error`
    - 发送数据：`websocket_client.send_text(json_string)`
    - 接收数据：通过`_on_data_received`信号处理
  - 实现连接状态管理：
    - 维护连接状态（未连接、连接中、已连接、断开）
    - 实现自动重连机制，当连接断开时尝试重新连接
  - 实现数据同步逻辑：
    - 定义数据同步协议，确保数据的一致性
    - 实现帧同步或状态同步机制
  - 与GameManager联动，处理网络状态变化和异常情况
- 关联模块：与GameManager联动，处理网络状态变化和异常情况；与PlayerDataManager联动，同步玩家数据；与BattleManager联动，同步战斗状态。

## 3.2 本地管理器（场景内节点，随场景生命周期）

本地管理器仅在对应场景内生效，场景加载时初始化，场景卸载时自动销毁，由SceneManager和当前场景节点统筹，无需注册为Autoload，避免全局资源占用，确保模块解耦，贴合Godot节点树的生命周期特性。

### 3.2.1 BattleManager（战斗管理器，战斗场景专属）

核心功能：负责战斗核心逻辑的执行，包括回合流程、敌方AI、伤害结算、胜负判定，严格贴合规则说明书中的回合流程、战斗核心规则，是战斗场景的核心逻辑模块。

- 核心功能：
  - 回合流程管理：按“回合开始→主要阶段→回合结束”执行，调用对应阶段的逻辑（行动点重置、法强结算、持续效果结算等），确保回合流程符合规则说明书。
  - 敌方AI逻辑：根据敌方卡牌的意图池、行动优先级，随机生成敌方行动（贴合规则说明书中的意图-概率判定机制），执行敌方攻击、技能触发，确保AI行为合理。
  - 伤害结算：处理玩家与敌方的攻击交互，计算伤害（普通伤害、特殊伤害），更新单位血量、圣物能量，判定单位退场/死亡，触发对应信号。
  - 胜负判定：实时检测圣物能量（降至0则失败）、敌方单位状态（全部死亡则胜利），触发battle_victory/battle_defeat信号，通知GameManager切换状态。
  - 状态与效果管理：协同EffectManager，处理增益/减益效果的存续、叠加、结算（规则说明书中“待补充”部分预留接口），确保效果逻辑准确。

- 回合流程具体执行逻辑：
  - 回合开始：重置行动点、结算持续效果（如回合开始时的伤害/治疗）、更新单位状态（如冷却结束）。
  - 主要阶段：玩家操作阶段，可使用卡牌、移动单位、使用道具，敌方AI根据意图执行行动。
  - 回合结束：结算持续效果（如回合结束时的伤害/治疗）、更新效果持续时间、敌方AI执行回合结束行动。

- 敌方AI实现逻辑：
  - 意图池配置：从配置文件加载敌方意图池，包含不同行动的概率权重。
  - 概率计算：根据意图池的权重计算每个行动的概率，随机选择行动。
  - 行动执行顺序：按照优先级执行敌方行动，如攻击>技能>移动。
  - 难度调整：根据游戏难度调整AI的意图池权重和行动策略，提升或降低AI强度。

- 胜负判定扩展：
  - 平局判定：当回合数达到上限（如50回合）仍未分胜负时，判定为平局，触发平局处理逻辑。
  - 超时判定：当玩家在规定时间内（如30秒）未执行任何操作时，自动结束当前回合。

- Godot实现要点：
      

- 作为战斗场景的子节点（Node2D类型），_ready()方法中初始化战斗数据（圣物能量、行动点、敌方部署），绑定GameManager的相关信号。

- 回合流程使用简化版状态机，每帧执行当前回合阶段的逻辑，通过信号触发阶段切换，确保回合流程流畅。

- 敌方AI使用随机算法+权重判定意图，贴合规则说明书中的“意图池概率权重”，可通过配置文件调整AI难度。

- 与CardManager、EffectManager、UIManager联动，接收卡牌使用、效果触发等信号，结算战斗逻辑、更新UI；与LightManager、ParticleManager、CameraManager联动，战斗关键节点（如圣物受伤、技能发动）触发视觉特效。

### 3.2.2 ItemManager（道具管理器，战斗场景专属）

核心功能：管理战斗场景中的道具、遗物（规则说明书中的“遗物、装备等增益效果”），负责道具的获取、使用、效果触发，贴合规则说明书中的圣物保护、部署上限提升等需求，与EffectManager协同实现道具效果。

- 核心功能：
  - 道具加载：从JSON配置文件（res://config/item_config.json）中加载道具数据（ItemData），初始化战斗中可使用的道具（如圣物保护道具、部署上限提升道具）。
  - 道具使用：响应玩家道具使用操作，校验使用条件（如道具数量、使用时机），执行道具效果（如提升圣物保护、增加行动点上限），触发effect_trigger信号。
  - 效果管理：跟踪道具的持续效果，协同EffectManager，在回合结束时结算效果存续，效果到期后移除，确保效果逻辑连贯。
  - 关联规则：道具效果严格贴合规则说明书（如提升玩家区域部署上限、给圣物添加保护机制等），预留道具扩展接口，便于新增道具类型。

- Godot实现要点：
  - 作为战斗场景的子节点（Node2D类型），初始化时加载ItemData配置，缓存道具资源，绑定UI交互信号（道具使用按钮）。
  - 与UIManager联动，显示玩家拥有的道具列表，更新道具数量；与EffectManager联动，施加道具对应的增益/减益效果；与LightManager、ParticleManager联动，道具使用时触发对应视觉特效。

### 3.2.3 其他本地管理器（可扩展，贴合战斗场景需求）

根据后续开发需求，可添加多种贴合战斗场景的本地管理器，均按“场景专属、随场景生命周期、模块化解耦”原则设计，与现有管理器协同工作，无需修改核心架构即可快速集成。以下为核心可扩展本地管理器，实现均贴合Godot特性与游戏战斗场景需求：

#### 3.2.3.1 AudioManager（音效管理器，战斗场景专属）

核心功能：负责战斗场景内所有音效的加载、播放、停止与音量控制，营造沉浸式战斗氛围，贴合卡牌战斗、技能触发、场景交互等音效需求，属于听觉优化模块，与LightManager协同提升游戏音视觉体验。

- 核心功能：
  - 音效加载：从res://resources/audio/目录加载战斗相关音效（卡牌使用、技能发动、圣物受伤、战斗胜利/失败、按钮交互等），缓存音效资源，避免重复加载导致性能消耗。
  - 音效播放：提供play_audio(audio_name, volume=1.0)方法，支持指定音效播放、音量调节，区分背景音效（循环播放）与触发音效（单次播放），设置音效优先级。
  - 音效控制：支持暂停/继续所有音效、停止指定音效，绑定战斗状态（如暂停时暂停音效、战斗结束时停止背景音效），确保音效与战斗状态同步。
  - 音效优先级：设置音效优先级（如技能音效优先级高于背景音效），避免多音效同时播放导致混乱，提升听觉体验。

- Godot实现要点：
  - 作为战斗场景的子节点（AudioStreamPlayer2D类型），初始化时加载所有战斗音效资源，存储在Dictionary中（key：音效名称，value：AudioStream），避免重复加载。
  - 使用AudioStreamPlayer2D节点播放音效，背景音效设置loop=true，触发音效设置loop=false，通过volume_db属性调节音量，支持音量全局调节。
  - 绑定战斗相关信号（如card_used、sanctum_hurt、battle_victory等），自动触发对应音效播放，无需手动调用，降低耦合。
  - 关联模块：与BattleManager、CardManager、UIManager联动，接收各模块信号触发音效；与LightManager协同优化战斗场景的音视觉体验，增强沉浸感。

#### 3.2.3.2 ParticleManager（粒子效果管理器，战斗场景专属）

核心功能：管理战斗场景内所有粒子效果（技能特效、伤害特效、圣物发光、战斗胜利/失败特效等），负责粒子预制体的加载、生成、销毁，提升战斗视觉表现力，贴合Godot粒子系统特性，与LightManager协同强化视觉效果。

- 核心功能：
  - 粒子预制体加载：从res://resources/particles/目录加载粒子预制体（如技能爆发、伤害飞溅、圣物光晕等），缓存预制体资源，支持动态生成，避免重复加载。
  - 粒子效果生成：提供spawn_particle(particle_name, position, duration=-1)方法，指定粒子类型、生成位置，可选设置粒子持续时间（默认随预制体配置），支持特效叠加。
  - 粒子效果管理：自动销毁过期粒子（粒子播放完成后删除节点），避免粒子节点堆积导致内存泄漏；支持手动销毁指定粒子效果，便于场景清理。
  - 特效适配：根据战斗状态、技能类型，适配不同的粒子效果（如圣物受伤时播放红色光晕、技能发动时播放对应元素特效），增强视觉区分度。

- Godot实现要点：
  - 作为战斗场景的子节点（Node2D类型），初始化时加载所有粒子预制体，存储在Dictionary中，避免重复加载，提升加载效率。
  - 使用Godot的CPUParticles2D或GPUParticles2D节点实现粒子效果，通过instance()方法动态生成粒子节点，设置position属性确定生成位置，适配战斗场景中的动态元素。
  - 绑定粒子播放完成信号（particles_finished），信号触发后删除粒子节点，实现自动清理；通过process方法检测粒子状态，确保及时销毁，避免内存泄漏。
  - 关联模块：与BattleManager、CardManager联动，接收卡牌使用、技能触发、战斗胜负等信号，生成对应粒子特效；与LightManager配合，强化场景视觉层次感，提升战斗沉浸感。

#### 3.2.3.3 CameraManager（镜头管理器，战斗场景专属）

核心功能：负责战斗场景的镜头控制，实现镜头跟随、焦点切换、特效镜头（如技能特写、战斗胜利镜头），提升战斗场景的沉浸感和视觉冲击力，贴合Godot的Camera2D节点特性，适配肉鸽地图的动态场景需求。

- 核心功能：
  - 镜头初始化：加载战斗场景时，初始化Camera2D节点，设置默认镜头范围、跟随目标（如玩家核心单位、圣物），适配战斗场景尺寸，确保场景完整显示。
  - 镜头跟随：支持跟随指定目标（如玩家激活的单位、圣物），设置跟随平滑度，避免镜头抖动，确保战斗焦点清晰，提升操作体验。
  - 焦点切换：接收战斗信号（如技能发动、单位死亡、圣物受伤），切换镜头焦点至对应目标，停留指定时间后恢复默认跟随，突出关键战斗瞬间。
  - 特效镜头：战斗胜利/失败时，播放镜头拉远/拉近特效；技能发动时，镜头聚焦技能释放点，增强视觉表现力；支持镜头震动（如圣物受伤时），强化反馈。
  - 镜头边界控制：限制镜头移动范围，避免镜头超出战斗场景边界，适配肉鸽地图的动态布局，确保场景显示完整。

- Godot实现要点：
  - 作为战斗场景的子节点（Camera2D类型），设置current=true，成为当前场景的活动镜头；初始化时绑定跟随目标节点，设置镜头偏移量。
  - 通过lerp方法实现镜头平滑跟随，调节镜头移动速度；使用set_position方法手动控制镜头位置，实现焦点切换，确保镜头移动流畅。
  - 镜头震动通过Tween节点实现，修改镜头position的偏移量，控制震动幅度和持续时间；特效镜头通过Tween实现镜头缩放、平移，增强视觉冲击。
  - 绑定战斗相关信号（如card_used、sanctum_hurt、battle_victory），触发对应镜头逻辑，确保镜头与战斗状态同步；与LightManager、ParticleManager联动，镜头切换时同步配合光照、粒子特效，提升视觉体验。
  - 关联模块：与BattleManager、CardManager、ParticleManager联动，接收技能、战斗状态等信号，切换镜头焦点；与SceneManager配合，适配肉鸽地图的动态场景边界，确保镜头显示合理。

#### 3.2.3.4 VibrationManager（振动管理器，战斗场景专属）

核心功能：负责设备振动反馈（适配PC、移动设备），强化战斗交互感，如技能发动、圣物受伤、战斗胜利/失败时触发振动，贴合Godot的Input类振动API，属于交互优化模块，提升玩家操作反馈体验，同时适配多设备。

- 核心功能：
- 振动初始化：加载战斗场景时，检测设备是否支持振动，初始化振动参数（幅度、持续时间），提供振动开关（可通过UIManager设置），适配不同玩家需求。

- 振动触发：提供vibrate(duration=0.2, amplitude=0.5)方法，支持指定振动持续时间和幅度，根据战斗场景触发对应振动（如技能发动振动0.2秒，圣物受伤振动0.3秒，战斗胜利/失败振动0.5秒）。

- 振动开关实现：通过UIManager的设置界面提供振动开关选项，将设置持久化到存档中，确保玩家偏好的保存。

- 设备适配：针对不同设备（PC、移动设备）的振动API差异，实现兼容逻辑，确保在不同设备上都能提供一致的振动体验。

- 振动参数配置：提供振动参数配置表，根据不同战斗事件设置不同的振动强度和持续时间，增强反馈的层次感。

- Godot实现要点：作为战斗场景的子节点（Node2D类型），初始化时检测Input.is_vibration_supported()；使用Input.start_vibration(duration, amplitude)触发振动；与UIManager联动，读取和保存振动开关设置；与BattleManager、CardManager联动，接收战斗事件信号触发振动。

- 关联模块：与UIManager联动，提供振动开关设置；与BattleManager、CardManager联动，接收战斗事件信号触发振动。

#### 3.2.3.5 InputManager（输入管理器，战斗场景专属）

核心功能：统一管理战斗场景的输入事件，处理跨设备输入适配（键鼠/手柄/触屏），避免输入逻辑分散，确保输入处理的一致性和可靠性。

- 核心功能：

- 输入初始化：加载战斗场景时，初始化输入映射表，适配不同输入设备的按键映射，确保跨设备输入的一致性。

- 输入处理：统一处理键盘、鼠标、手柄、触屏输入，将输入事件转换为统一的游戏操作，如卡牌点击、单位激活、菜单操作等。

- 输入拦截：在特定状态（如暂停、加载）下拦截非法输入，避免误操作，确保游戏状态的稳定性。

- 输入防抖：实现输入防抖逻辑，避免快速连续输入导致的操作错误，提升操作体验。

- 输入映射配置：支持自定义输入映射，允许玩家根据个人习惯调整按键设置，并将设置持久化到存档中。

- Godot实现要点：作为战斗场景的子节点（Node2D类型），通过_input(event)方法处理输入事件；维护输入映射表，将不同输入设备的事件映射为统一的游戏操作；与UIManager联动，处理UI输入事件；与BattleManager联动，处理战斗相关输入事件。

- 关联模块：与UIManager联动，处理UI输入事件；与BattleManager、CardManager联动，处理战斗相关输入事件；与GameManager联动，接收游戏状态变化信号，调整输入处理逻辑。

#### 3.2.3.6 TimeManager（计时管理器，战斗场景专属）

核心功能：统一管理战斗场景的计时任务，包括回合计时、技能冷却、效果持续时间等，确保计时逻辑的准确性和一致性。

- 核心功能：

- 计时初始化：加载战斗场景时，初始化计时系统，创建计时任务列表，准备处理各类计时需求。

- 计时任务管理：支持创建、更新、删除计时任务，如回合计时、技能冷却计时、效果持续时间计时等。

- 暂停/恢复计时：在游戏暂停时暂停所有计时任务，恢复时继续计时，确保计时的准确性。

- 计时回调：当计时任务完成时，触发回调函数，执行对应逻辑，如技能冷却结束、效果过期等。

- 计时精度控制：根据不同计时任务的需求，调整计时精度，平衡性能消耗和计时准确性。

- Godot实现要点：作为战斗场景的子节点（Node2D类型），通过_process(delta)方法更新计时任务；维护计时任务字典，键为任务ID，值为任务信息（剩余时间、回调函数等）；提供create_timer(task_id, duration, callback)、cancel_timer(task_id)方法；与BattleManager联动，处理回合计时和技能冷却计时；与EffectManager联动，处理效果持续时间计时。

- 关联模块：与BattleManager联动，处理回合计时和技能冷却计时；与EffectManager联动，处理效果持续时间计时；与GameManager联动，接收游戏暂停/恢复信号，控制计时任务的暂停和恢复。

#### 3.2.3.7 LayerManager（层级管理器，战斗场景专属）

核心功能：统一管理战斗场景的节点层级，确保卡牌、单位、特效等元素的正确显示顺序，避免图层重叠混乱，提升视觉层次感。

- 核心功能：

- 层级初始化：加载战斗场景时，初始化层级结构，创建不同层级的容器节点，如背景层、单位层、卡牌层、特效层、UI层等。

- 层级管理：提供节点添加到指定层级的方法，确保不同类型的节点放置在正确的层级，避免显示顺序错误。

- 层级优先级：设置不同层级的显示优先级，确保视觉上的正确叠加关系，如特效显示在单位上方，UI显示在最上方。

- 点击检测层级：处理不同层级的点击检测，确保点击事件能够正确传递到目标节点，避免点击检测错误。

- Godot实现要点：作为战斗场景的子节点（Node2D类型），创建层级容器节点（如BackgroundLayer、UnitLayer、CardLayer、EffectLayer、UILayer）；提供add_to_layer(node, layer_name)方法，将节点添加到指定层级；维护层级优先级列表，确保层级的正确显示顺序；与CardManager、ParticleManager联动，确保卡牌和特效显示在正确的层级。

- 关联模块：与CardManager联动，管理卡牌的显示层级；与ParticleManager联动，管理特效的显示层级；与UIManager联动，确保UI显示在最上层。

### 3.2.4 EffectManager（效果管理器，战斗场景专属）

核心功能：负责战斗场景中所有增益/减益效果的管理，包括效果的施加、叠加、存续、结算、移除，是卡牌战斗核心逻辑的重要组成部分。

- 核心功能：

- 效果加载：从JSON配置文件（res://config/effect_config.json）中加载所有效果数据（EffectData），初始化效果模板，支持动态扩展效果类型。

- 效果施加：根据卡牌、道具、技能等触发的effect_trigger信号，向目标单位或场景施加效果，处理效果的叠加规则（如相同效果的叠加方式、不同效果的共存规则）。

- 效果存续：跟踪效果的持续时间，在每回合结束时更新效果状态，处理效果的到期移除。

- 效果结算：在战斗的不同阶段（回合开始、主要阶段、回合结束）结算效果，执行效果的具体逻辑，如伤害、治疗、属性修改等。

- 效果移除：当效果持续时间结束或被其他效果抵消时，移除效果，恢复目标的原始状态。

- 效果优先级：设置效果的优先级，处理效果触发的顺序，确保效果结算的正确性。

- Godot实现要点：作为战斗场景的子节点（Node2D类型），初始化时加载EffectData配置；维护效果实例字典，键为目标ID，值为效果列表；提供apply_effect(effect_id, target, duration)、remove_effect(effect_id, target)方法；与BattleManager联动，在回合不同阶段结算效果；与CardManager、ItemManager联动，接收效果触发信号。

- 关联模块：与BattleManager联动，处理效果的结算和存续；与CardManager、ItemManager联动，接收效果触发信号；与UIManager联动，更新效果相关的UI显示。

## 3.3 模块间逻辑衔接

### 3.3.1 GameData与各管理器的同步逻辑

- 数据访问权限控制：GameData作为全局数据存储，仅允许通过GameManager进行修改，各管理器需通过GameManager的接口修改GameData，确保数据一致性。

- 数据变更通知机制：当GameData发生变更时，GameManager触发data_updated信号，通知所有订阅的管理器进行数据同步，确保UI和逻辑的实时更新。

- 数据校验：在修改GameData前，GameManager进行数据校验，确保数据的合法性和有效性，避免异常数据的产生。

### 3.3.2 本地管理器与全局管理器的联动边界

- 信号传递：本地管理器通过GameManager的dispatch_signal方法发送信号，全局管理器监听对应信号进行处理，避免直接调用。

- 数据回传：本地管理器在触发信号时，传递必要的数据参数，全局管理器接收数据并进行处理，如BattleManager触发battle_victory信号时，传递战斗结果数据，ArchiveManager接收数据并保存。

- 生命周期管理：本地管理器在场景加载时初始化，场景卸载时销毁，全局管理器在游戏启动时初始化，游戏退出时销毁，两者通过GameManager协调生命周期。

### 3.3.3 多管理器协同的执行顺序

- 信号优先级：GameManager根据信号优先级（如battle_victory > card_used > effect_trigger）控制信号的执行顺序，确保逻辑的正确性。

- 执行流程：卡牌使用时的执行顺序为：CardManager校验条件 → GameManager分发card_used信号 → BattleManager结算效果 → EffectManager处理效果 → UIManager更新UI → AudioManager播放音效 → LightManager触发光照变化 → ParticleManager生成特效。

- 异步操作协同：对于异步操作（如场景加载），SceneManager通过scene_load_progress信号实时传递进度，GameManager协调其他管理器的初始化时机，确保数据初始化与场景加载同步完成。

## 四、扩展性设计的落地细节

### 4.1 多人模式扩展

- 网络模块设计：预留NetworkManager基础框架，负责网络通信、连接管理和同步机制。

- 通信协议：采用WebSocket或TCP/IP协议进行网络通信，确保数据传输的可靠性和实时性。

- 同步机制：支持帧同步和状态同步两种同步方式，根据游戏类型和网络环境选择合适的同步方案。

- 状态机扩展：GameManager新增联机等待、对战中、观战等状态，支持多人模式的完整流程。

- 数据同步：实现玩家数据、卡牌操作、战斗状态的实时同步，确保多玩家间的游戏状态一致。

### 4.2 卡牌/道具/效果扩展

- 配置文件标准化：制定JSON配置文件的字段规范，明确必选/可选字段，确保配置文件的一致性和可扩展性。

- 版本兼容规则：实现配置文件的版本号管理，处理不同版本配置的兼容逻辑，确保游戏在配置更新后仍能正常运行。

- 新卡牌类型接口：预留新卡牌类型的接口扩展规则，如陷阱卡、环境卡等，通过继承现有接口实现功能扩展。

- 效果组合系统：设计效果组合机制，允许不同效果的组合使用，创造更多样的游戏玩法。

### 4.3 Roguelike地图扩展

- 地图生成规范：制定TileMap的瓦片配置标准，明确地图与敌人/道具的关联逻辑，确保地图生成的一致性。

- 地图难度梯度：设计地图难度的梯度变化，根据玩家进度和游戏难度调整地图的敌人强度和道具分布。

- 状态机适配：GameManager新增地图探索、事件选择等状态，支持肉鸽地图的完整流程。

- 随机事件系统：实现随机事件生成机制，在地图探索过程中触发各种事件，增加游戏的随机性和可玩性。

### 4.4 多平台适配扩展

- 跨平台统一处理：设计全局的多平台适配框架，统一处理输入、资源、UI的跨平台差异。

- 平台判定核心方法：实现平台判定的核心方法，根据不同平台执行不同的适配逻辑。

- 资源适配：针对不同平台的性能和资源限制，提供不同分辨率和质量的资源，确保游戏在各平台的流畅运行。

- 输入适配：统一处理不同平台的输入方式（键鼠、手柄、触屏），确保操作体验的一致性。

## 五、工程化与性能优化

### 5.0 项目结构

项目采用清晰的目录结构，便于管理和维护：

```
newbee/
├── assets/             # 游戏资源
│   ├── textures/       # 纹理资源
│   ├── audio/          # 音频资源
│   ├── models/         # 模型资源
│   └── particles/      # 粒子效果资源
├── config/             # 配置文件
│   ├── card_config.json    # 卡牌配置
│   ├── effect_config.json  # 效果配置
│   ├── item_config.json    # 道具配置
│   └── ai_config.json      # AI配置
├── scenes/             # 场景文件
│   ├── scene_main_menu.tscn    # 主菜单场景
│   ├── scene_battle.tscn       # 战斗场景
│   └── scene_load.tscn         # 加载过渡场景
├── scripts/            # 脚本文件
│   ├── managers/       # 管理器脚本
│   │   ├── global/     # 全局管理器
│   │   │   ├── GameManager.gd
│   │   │   ├── ArchiveManager.gd
│   │   │   ├── UIManager.gd
│   │   │   ├── SceneManager.gd
│   │   │   ├── CardManager.gd
│   │   │   ├── LightManager.gd
│   │   │   ├── ConfigManager.gd
│   │   │   ├── ResourceManager.gd
│   │   │   ├── PlayerDataManager.gd
│   │   │   ├── LogManager.gd
│   │   │   └── NetworkManager.gd
│   │   └── local/      # 本地管理器
│   │       ├── BattleManager.gd
│   │       ├── ItemManager.gd
│   │       ├── AudioManager.gd
│   │       ├── ParticleManager.gd
│   │       ├── CameraManager.gd
│   │       ├── VibrationManager.gd
│   │       ├── InputManager.gd
│   │       ├── TimeManager.gd
│   │       ├── LayerManager.gd
│   │       └── EffectManager.gd
│   ├── states/         # 状态机状态
│   │   ├── BaseState.gd
│   │   ├── PreloadState.gd
│   │   ├── MainMenuState.gd
│   │   ├── LoadState.gd
│   │   ├── RunState.gd
│   │   ├── PauseState.gd
│   │   ├── EndState.gd
│   │   ├── QuitState.gd
│   │   └── ErrorState.gd
│   ├── data/           # 数据结构
│   │   ├── GameData.gd
│   │   ├── PlayerData.gd
│   │   ├── CardData.gd
│   │   ├── ItemData.gd
│   │   └── EffectData.gd
│   └── interfaces/     # 接口定义
│       ├── ICard.gd
│       ├── IUnitCard.gd
│       └── IStrategyCard.gd
├── ui/                 # UI界面
│   ├── UI_Root.tscn
│   ├── UI_Preload.tscn
│   ├── UI_MainMenu.tscn
│   ├── UI_Load.tscn
│   ├── UI_Battle.tscn
│   ├── UI_Pause.tscn
│   └── UI_End.tscn
├── autoload/           # Autoload节点配置
│   └── autoload.cfg
├── project.godot       # 项目配置文件
└── README.md           # 项目说明文档
```

### 5.1 性能优化策略

- 节点池设计：实现节点池模式，复用频繁创建和销毁的节点（如卡牌、特效），减少内存开销。

- 资源懒加载：对于非核心资源，采用懒加载策略，仅在需要时加载，减少初始加载时间。

- 帧频控制：实现帧频控制机制，根据设备性能调整游戏帧率，确保游戏的流畅运行。

- 大场景分块加载：对于大场景，采用分块加载策略，仅加载当前视野内的场景内容，减少内存占用。

- 渲染优化：使用Godot的渲染优化功能，如 occlusion culling、LOD（Level of Detail）等，提升渲染性能。

- 内存泄漏检测：集成内存泄漏检测工具，如Valgrind（PC平台）或Godot内置的内存分析工具，定期检测内存使用情况，及时发现和解决内存泄漏问题。

- Draw Call优化：
  - 合批渲染：使用Godot的自动合批功能，将相同材质的节点合并渲染，减少Draw Call次数。
  - 静态批处理：对于静态场景元素，使用静态批处理，将多个静态节点合并为一个批次渲染。
  - 材质合并：将多个相似材质合并为一个材质，减少材质切换开销。
  - 图集（Atlas）使用：将多个小图片合并为一个图集，减少纹理切换次数，提升渲染性能。

### 5.2 代码规范

- 脚本命名：统一脚本文件命名规范，如使用PascalCase命名类，snake_case命名函数和变量。

- 变量/方法命名：制定变量和方法的命名规范，确保代码的可读性和一致性。

- 注释规范：要求关键代码添加注释，解释代码的功能和实现逻辑，便于后续维护。

- 节点路径规范：统一节点路径的访问方式，避免硬编码节点路径，提升代码的可维护性。

### 5.3 版本管理

- 配置文件版本管理：为配置文件添加版本号，确保配置更新时的兼容性。

- 资源版本命名：采用版本化的资源命名方式，如 sprite_v1.png，便于资源的管理和更新。

- 代码版本控制：使用Git等版本控制工具，管理代码的变更和回滚。

### 5.4 测试策略

#### 5.4.1 测试方法

- **单元测试**：针对每个模块的核心功能进行独立测试，确保单个模块的功能正确性。
- **集成测试**：测试模块间的交互和协同工作，确保系统整体功能的正确性。
- **回归测试**：在修改代码后，重新测试已有的功能，确保修改不会破坏现有功能。
- **性能测试**：测试游戏在不同设备和场景下的性能表现，确保游戏流畅运行。
- **兼容性测试**：测试游戏在不同平台和设备上的兼容性，确保游戏在各种环境下都能正常运行。

#### 5.4.2 测试用例设计

- **核心功能测试**：测试游戏的核心功能，如状态机切换、卡牌使用、战斗逻辑等。
- **边界条件测试**：测试游戏在边界条件下的表现，如行动点为0时的卡牌使用、圣物能量为0时的游戏结束等。
- **异常情况测试**：测试游戏在异常情况下的表现，如资源加载失败、网络连接断开等。
- **用户体验测试**：测试游戏的用户体验，如UI响应速度、操作流畅度等。

#### 5.4.3 测试流程

1. **单元测试阶段**：对每个模块进行单元测试，确保单个模块的功能正确性。
2. **集成测试阶段**：测试模块间的交互和协同工作，确保系统整体功能的正确性。
3. **性能测试阶段**：测试游戏在不同设备和场景下的性能表现，确保游戏流畅运行。
4. **兼容性测试阶段**：测试游戏在不同平台和设备上的兼容性，确保游戏在各种环境下都能正常运行。
5. **回归测试阶段**：在修改代码后，重新测试已有的功能，确保修改不会破坏现有功能。
6. **发布前测试阶段**：在发布前进行全面的测试，确保游戏的质量和稳定性。

### 5.5 安全性考虑

#### 5.5.1 防止作弊

- **服务器端验证**：对于多人模式，所有关键操作（如卡牌使用、战斗结果）都需要在服务器端进行验证，防止客户端作弊。
- **数据加密**：对存档数据和网络传输数据进行加密，防止数据被篡改。
- **防内存修改**：实现内存修改检测机制，防止玩家通过修改内存来作弊。
- **防外挂**：实现外挂检测机制，及时发现和处理外挂行为。

#### 5.5.2 数据保护

- **存档加密**：对存档文件进行加密，防止玩家篡改存档数据。
- **个人信息保护**：保护玩家的个人信息，不收集不必要的个人数据。
- **数据备份**：定期备份玩家数据，防止数据丢失。

#### 5.5.3 网络安全

- **HTTPS加密**：使用HTTPS协议进行网络通信，确保数据传输的安全性。
- **防DDoS攻击**：实现DDoS攻击防护机制，确保服务器的稳定运行。
- **防SQL注入**：对服务器端的数据库操作进行安全处理，防止SQL注入攻击。
- **权限控制**：实现严格的权限控制，确保只有授权用户才能访问特定资源。

### 5.6 打包与发布

- 资源打包格式：选择合适的资源打包格式，如PCK文件，减少游戏体积。

- 无用资源剔除：在打包前剔除无用资源，减少游戏安装包大小。

- 多平台打包配置：为不同平台（PC、移动设备、主机）设置不同的打包配置，确保游戏在各平台的正常运行。

- 发布流程：制定完整的发布流程，包括测试、打包、上传、发布等步骤，确保发布的游戏质量。

## 六、游戏体验相关的细节

### 6.1 新手引导模块

- 引导管理器：设计新手引导专属管理器，负责引导步骤的配置和执行。

- 引导步骤配置：实现引导步骤的配置化方案，通过JSON配置文件定义引导步骤，无需修改核心逻辑。

- 引导触发条件：设置引导触发的条件，如首次进入游戏、首次使用某功能等。

- 引导交互：实现引导过程中的交互逻辑，如高亮目标、强制操作、提示信息等。

### 6.2 提示反馈体系

- 提示分级：实现统一的提示分级，包括普通提示、重要提示、错误提示，设置不同的视觉和音效反馈。

- 提示消失/堆叠规则：制定提示的消失时间和堆叠规则，避免提示信息的混乱。

- 提示动画：为提示信息添加动画效果，提升视觉反馈的体验。

### 6.3 设置功能的落地

- 设置管理器：设计SettingManager，负责设置的持久化和实时生效。

- 设置项：实现音量、画质、振动、语言等设置项，允许玩家根据个人偏好进行调整。

- 实时生效：确保设置的实时生效，无需重启游戏即可应用新的设置。

- 持久化：将设置持久化到存档中，确保玩家的偏好设置在游戏重启后仍然保留。

### 6.4 暂停/恢复的细节

- 后台切出处理：实现玩家切出游戏后的自动暂停逻辑，确保游戏状态的稳定。

- 音效/音乐处理：暂停时音乐降速或静音，恢复时恢复正常，提升暂停状态的体验。

- 暂停菜单设计：设计清晰的暂停菜单，提供继续、重新开始、返回主菜单等选项。

## 七、架构整体总结

### 7.1 核心架构优势

- 模块化解耦：通过管理器模式和信号系统，实现模块间的低耦合，便于调试和扩展。

- 状态驱动：以GameManager状态机为核心，统一管理游戏生命周期，确保状态流转的清晰可追溯。

- 数据标准化：统一数据结构和配置格式，便于数据的管理和扩展。

- 可扩展性：预留多个扩展接口，支持多人模式、卡牌扩展、地图扩展等功能。

### 7.2 开发优先级建议

1. 核心架构搭建：实现GameManager、基础管理器和状态机。
2. 战斗核心逻辑：实现CardManager、BattleManager和EffectManager。
3. UI系统：实现UIManager和基础UI界面。
4. 存档系统：实现ArchiveManager和存档功能。
5. 视觉/听觉效果：实现LightManager、ParticleManager和AudioManager。
6. 扩展性功能：实现多人模式、肉鸽地图等扩展功能。

### 7.3 核心模块联调流程

1. 预加载阶段：加载配置和资源，初始化所有全局管理器。
2. 主菜单阶段：显示主菜单，响应菜单操作。
3. 加载阶段：加载战斗场景，读取存档数据，初始化战斗数据。
4. 战斗阶段：启动战斗逻辑，处理卡牌操作和敌方AI，判定胜负。
5. 结束阶段：显示战斗结果，结算战利品，保存战斗结果。

### 7.4 常见问题排查

- 资源加载失败：检查资源路径是否正确，资源文件是否存在。
- 存档读取错误：检查存档文件格式是否正确，数据是否完整。
- 战斗逻辑异常：检查卡牌使用条件、效果结算逻辑是否正确。
- UI显示异常：检查UI节点布局、锚点设置是否正确。
- 性能问题：检查节点数量、资源加载方式是否优化。

> （注：文档部分内容可能由 AI 生成）