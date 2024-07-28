class_name GameTile

enum STATE {GROUND, CLIFF, PIT}
var tileState : STATE
var position : Vector2i
var index : int
var h_row : int
var d_row : int
var u_row : int

# Called when the node enters the scene tree for the first time.
func _init(_tileState : STATE, _position : Vector2i, _index : int):
	tileState = _tileState
	position = _position
	index = _index

