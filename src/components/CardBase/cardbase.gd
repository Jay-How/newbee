extends Node

var state_machine : BaseStateMachine
var card_current_state : BaseState

func _ready() -> void:
    state_machine = BaseStateMachine.new()
    state_machine.owner = self
    
    state_machine.add_state(Dragging.new())
func _process(delta: float) -> void:
        

class Dragging :
    extends BaseState
    func enter(_prev_state: BaseState = null) -> void:
        pass
    func exit(_next_state: BaseState = null) -> void:
        pass
    func update(_delta: float) -> void:
        pass
    func physics_update(_delta: float) -> void:
        pass
    
