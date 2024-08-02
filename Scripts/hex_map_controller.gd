extends TileMap

@export var noise_height_text : NoiseTexture2D
@onready var move_delay_timer = $MoveDelayTimer

var noise : Noise

var width : int = 10
var height : int = 10
var min_x : int
var min_y : int
var max_x : int
var max_y : int

var source_id = 2
var cliff_atlas = Vector2i(0, 0)
var land_atlas = Vector2i(1, 0)
var pit_atlas = Vector2i(2, 0)
var player_atlas = Vector2i(3, 0)
var mouse_target_atlas = Vector2i(1, 1)

var tile_dict = {}
var ground_tiles = []

enum ACTION_STATE {LOCKED, MOVE}
var current_state = ACTION_STATE.MOVE

var ground_layer : int = 0
var fog_layer : int = 1
var ui_layer : int = 2
var path_ui_layer : int = 3

var player_pos
var last_mouse_pos
var highlighted_cells = []

func _ready():
	min_x = -(width/2)
	min_y = -(height/2)
	max_x = width - (width/2) - 1
	max_y = height - (height/2) - 1
	noise = noise_height_text.noise
	generate_world()

func generate_world():
	print("started heightmap generation...")
	noise_height_text.noise.seed = Time.get_ticks_msec()
	await noise_height_text.changed
	print("heightmap generation done")
	var index = 0
	#place each tile
	for x in range(width):
		for y in range(height):
			var noise_value = noise_height_text.noise.get_noise_2d(x, y)
			var placed_location = Vector2i(x - (width/2), y - (height/2))
			var target_atlas
			var target_state
			if noise_value >= 0.2:
				#place cliff
				target_atlas = cliff_atlas
				target_state = GameTile.STATE.CLIFF
			elif noise_value >= -0.2:
				#place land
				target_atlas = land_atlas
				target_state = GameTile.STATE.GROUND
			else:
				#place pit
				target_atlas = pit_atlas
				target_state = GameTile.STATE.PIT
			set_cell(ground_layer, placed_location, source_id, target_atlas)
			tile_dict[placed_location] = GameTile.new(target_state, placed_location, index)
			index = index + 1
			if target_state == GameTile.STATE.GROUND:
				ground_tiles.append(placed_location)
	#assign everything into rows
	#horizontal rows
	var h_row = 0
	for y in range(height):
		#for each tile in the horizontal row:
		for x in range(width):
			#assign it the value of h_row
			var target_position = Vector2i(x - (width/2), y - (height/2))
			tile_dict[target_position].h_row = h_row
		h_row = h_row + 1
	#downwards diagonal
	var d_row = 0
	var starting_cell = Vector2i(min_x, min_y)
	while (starting_cell.x <= max_x):
		d_row_assign(starting_cell, d_row)
		d_row = d_row + 1
		starting_cell.x = starting_cell.x + 1
	starting_cell = Vector2i(min_x, min_y + 1)
	while (starting_cell.y <= max_y):
		d_row_assign(starting_cell, d_row)
		d_row = d_row + 1
		starting_cell.y = starting_cell.y + 2
	
	var u_row = 0
	starting_cell = Vector2i(min_x, max_y)
	while (starting_cell.x <= max_x):
		u_row_assign(starting_cell, u_row)
		u_row = u_row + 1
		starting_cell.x = starting_cell.x + 1
	var start_y = max_y if max_y % 2 == 0 else max_y - 1
	starting_cell = Vector2i(min_x, start_y)
	while (starting_cell.y >= min_y):
		u_row_assign(starting_cell, u_row)
		u_row = u_row + 1
		starting_cell.y = starting_cell.y - 2
	
	#set location	
	#select random player starting location
	var random_spawn = ground_tiles[randi() % ground_tiles.size()]
	set_cell(ui_layer, random_spawn, source_id, player_atlas)
	player_pos = random_spawn

func _input(event):
	if current_state == ACTION_STATE.MOVE:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				var global_clicked = get_local_mouse_position()
				var pos_clicked = local_to_map(to_local(global_clicked))
				var associated_object = tile_dict[pos_clicked]
				if (associated_object):
					try_move_player(pos_clicked)
		if event is InputEventMouseMotion:
			var global_pos = get_local_mouse_position()
			var map_pos = local_to_map(to_local(global_pos))
			if(last_mouse_pos != map_pos):
				if(last_mouse_pos != null):
					set_cell(path_ui_layer, last_mouse_pos, -1, mouse_target_atlas)
				last_mouse_pos = map_pos
				if(validCoord(map_pos)):
					set_cell(path_ui_layer, map_pos, source_id, mouse_target_atlas)
					if(map_pos == player_pos):
						return
					for i in range(highlighted_cells.size()):
						if(highlighted_cells[i] != map_pos):
							set_cell(path_ui_layer, highlighted_cells[i], -1, mouse_target_atlas)
					highlighted_cells = []
					var player_cell = tile_dict[player_pos]
					var mouse_cell = tile_dict[map_pos]
					if(player_cell.h_row == mouse_cell.h_row):
						if(player_cell.x < mouse_cell.x):
							
				#if (last_mouse_pos.size() > 0):
					#for pos in last_mouse_pos.size():
						#set_cell(path_ui_layer, last_mouse_pos[pos], -1, target_atlas)
						#last_mouse_pos.erase(last_mouse_pos[pos])
					##set_cell(path_ui_layer, last_mouse_pos, -1, target_atlas)
				#last_mouse_pos.append(map_pos)
				#set_cell(path_ui_layer, map_pos, source_id, target_atlas)

func validCoord(c : Vector2i):
	return (c.x <= max_x && c.x >= min_x && c.y <= max_y && c.y >= min_y)

func d_row_assign(start_cell : Vector2i, row : int):
	var current_cell = start_cell
	while(validCoord(current_cell)):
		tile_dict[current_cell].d_row = row
		current_cell.y = current_cell.y + 1
		if (current_cell.y % 2 == 0):
			current_cell.x = current_cell.x + 1

func u_row_assign(start_cell : Vector2i, row : int):
	var current_cell = start_cell
	while(validCoord(current_cell)):
		tile_dict[current_cell].u_row = row
		current_cell.y = current_cell.y - 1
		if (current_cell.y % 2 == 0):
			current_cell.x = current_cell.x + 1

func try_move_player(target_pos : Vector2i):
	if(!validCoord(target_pos)):
		return false
	#temp: just move the player to the position if valid
	var target_cell : GameTile = tile_dict[target_pos]
	var current_cell : GameTile = tile_dict[player_pos]
	if (target_cell.tileState != GameTile.STATE.GROUND || 
	   (target_cell.h_row != current_cell.h_row &&
		target_cell.u_row != current_cell.u_row &&
		target_cell.d_row != current_cell.d_row)):
		return false
	
	if (target_pos == player_pos):
		return false
	
	current_state = ACTION_STATE.LOCKED
	
	#pick a direction and loop towards it
	if (target_cell.h_row == current_cell.h_row):
		if(target_pos.x < player_pos.x):
			while (player_pos != target_pos):
				set_player_pos(Vector2i(player_pos.x - 1, player_pos.y))
				move_delay_timer.start()
				await move_delay_timer.timeout
		else:
			while (player_pos != target_pos):
				set_player_pos(Vector2i(player_pos.x + 1, player_pos.y))
				move_delay_timer.start()
				await move_delay_timer.timeout
	elif (target_cell.u_row == current_cell.u_row):
		if (target_pos.y < player_pos.y):
			while (player_pos != target_pos):
				var new_pos = Vector2i(player_pos.x, player_pos.y - 1)
				if (new_pos.y % 2 == 0):
					new_pos.x = new_pos.x + 1
				set_player_pos(new_pos)
				move_delay_timer.start()
				await move_delay_timer.timeout
		else:
			while (player_pos != target_pos):
				var new_pos = Vector2i(player_pos.x, player_pos.y + 1)
				if (new_pos.y % 2 != 0):
					new_pos.x = new_pos.x - 1
				set_player_pos(new_pos)
				move_delay_timer.start()
				await move_delay_timer.timeout
	else: 
		if (target_pos.y < player_pos.y):
			while (player_pos != target_pos):
				var new_pos = Vector2i(player_pos.x, player_pos.y - 1)
				if (new_pos.y % 2 != 0):
					new_pos.x = new_pos.x - 1
				set_player_pos(new_pos)
				move_delay_timer.start()
				await move_delay_timer.timeout
		else:
			while (player_pos != target_pos):
				var new_pos = Vector2i(player_pos.x, player_pos.y + 1)
				if (new_pos.y % 2 == 0):
					new_pos.x = new_pos.x + 1
				set_player_pos(new_pos)
				move_delay_timer.start()
				await move_delay_timer.timeout
		
	current_state = ACTION_STATE.MOVE
	return true

func set_player_pos(new_position : Vector2i):
	set_cell(ui_layer, player_pos, -1, land_atlas)
	player_pos = new_position
	set_cell(ui_layer, player_pos, source_id, player_atlas)

func swap_state(new_state : ACTION_STATE):
	pass
