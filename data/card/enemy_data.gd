extends Resource
class_name EnemyData

@export var hp : int
@export var mp : int
var intent 

class IntentData:
    extends Resource
    enum IntentType{ATTACK, DEFENCE, BUFF, DEBUFF, UNKNOWN, DERANGE}
    var type : IntentType
    var value : int
    var target : Node
