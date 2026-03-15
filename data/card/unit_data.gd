extends Resource
class_name UnitData

@export var hp : int
@export var mp : int
@export var move_cost : CostData
@export var skill: SkillData

class SkillData : 
    extends Resource
    @export var id: StringName
    @export var name: String
    @export var description: String
    @export var icon_path: String
    @export var cost: CostData
