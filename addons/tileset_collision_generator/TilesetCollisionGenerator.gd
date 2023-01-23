tool
extends VBoxContainer

onready var line2d = $TextureRect/Line2D

var tileset :TileSet = null

var directions = [
	Vector2(0, -1),
	Vector2(1, -1),
	Vector2(1, 0),
	Vector2(1, 1),
	Vector2(0, 1),
	Vector2(-1, 1),
	Vector2(-1, 0),
	Vector2(-1, -1)
]

var dir_index := 0
var start_pos := Vector2.ZERO
var walker_pos := Vector2.ZERO
var walker_cells := []
var corner_pixels := []

var image_size := Vector2(16, 16)

var points := []

var score_set := [7, 1, -1, -4]

enum {
	TOP_RIGHT,
	TOP_LEFT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT
}

func _ready():
	pass


func _on_Load_pressed():
	$LoadDialog.popup_centered()


func _on_LoadDialog_file_selected(path):
	$LoadDialog
	tileset = ResourceLoader.load(path).duplicate()

func clear_shapes() -> void:
	for i in tileset.get_tiles_ids():
		var shapes = tileset.tile_get_shapes(i)
		tileset.tile_set_shapes(i, [])


func _on_Export_pressed():
	if tileset != null:
		$SaveDialog.popup_centered()


func _on_SaveDialog_file_selected(path):
	ResourceSaver.save(path, tileset)


func _on_GenerateCollision_pressed():
	if tileset == null:
		return
	
	if $Overwrite.pressed:
		clear_shapes()
	
	$Label.text = "Generating Collision... "
	$Tiles.text = "Tiles "
	var tile_count := 0
	for tile in tileset.get_tiles_ids():
		$Tiles.text = "Tiles " + str(tile_count) + "/" + str(tileset.get_tiles_ids().size())
		tile_count += 1
		
		var cell_size = tileset.tile_get_region(tile).size / tileset.autotile_get_size(tile)
		var tile_size = tileset.autotile_get_size(tile)
		var tile_pos = tileset.tile_get_region(tile).position
		
		var tile_texture :Texture = tileset.tile_get_texture(tile)
		var index := 0
		
		var autotile_coords := []
		if not $Overwrite.pressed:
			for shape in tileset.tile_get_shapes(tile):
				autotile_coords.append(shape["autotile_coord"])
		for y in cell_size.y:
			for x in cell_size.x:
				if Vector2(x, y) in autotile_coords:
					continue
#				$Autotile.text = "Cell " + str(x + cell_size.x * y) + "/" + str(cell_size.x * cell_size.y)
				var image :Image = tile_texture.get_data()
				image = image.get_rect(Rect2(Vector2(x, y) * tile_size + tile_pos, tile_size))
				var texture = ImageTexture.new()
				texture.create_from_image(image)
				texture.flags = 0
				
				$TextureRect.texture = texture
				
				$Timer.start()
				
				if image.is_invisible():
					continue
				var collision = generate_collision(image)
				var trans = Transform2D(0, Vector2(0,0))
				tileset.tile_add_shape(tile, collision, trans, false, Vector2(x, y))
				$Timer.start()
#				yield(get_tree(), "idle_frame")
#		$Autotile.text = "Cell " + str(cell_size.x * cell_size.y) + "/" + str(cell_size.x * cell_size.y)
		yield(get_tree(), "idle_frame")
		
		
	
	$Label.text = "Generated Collision"
	$Tiles.text = "Tiles " + str(tile_count) + "/" + str(tileset.get_tiles_ids().size())

func generate_collision(image):
	
	image_size = image.get_size()
	
	start_pos = find_start_pos(image)
	walker_pos = start_pos
	walker_cells = []
	corner_pixels = []
	points = []
	$TextureRect/Line2D.clear_points()
	
	for y in image_size.y:
		var arr = []
		for x in image_size.x:
			arr.append(-1)
		walker_cells.append(arr)
	
	return walk_border(image)


func find_start_pos(image) -> Vector2:
	for x in image_size.x:
		for y in image_size.y:
			if is_pixel_visible(image, Vector2(x, y)):
				return Vector2(x, y)
	
	return Vector2(0, 0)

func is_pixel_visible(image, pos) -> bool:
	if not is_pixel_in_bounds(pos):
		return false
	image.lock()
	var success = image.get_pixelv(pos).a > 0
	image.unlock()
	return success

func set_walker_cellv(pos, id) -> void:
	walker_cells[pos.y][pos.x] = id

func get_walker_cellv(pos) -> int:
	var size_y = walker_cells.size()
	var size_x = walker_cells[0].size()
	if pos.x >= 0 and pos.x < size_x and pos.y >= 0 and pos.y < size_y:
		return walker_cells[pos.y][pos.x]
	else:
		return -1

func is_pixel_in_bounds(pos) -> bool:
	return pos.x >= 0 and pos.x < image_size.x and pos.y >= 0 and pos.y < image_size.y

func walk_border(image, break_walk:=false):
	#for each direction
	for i in 8:
		var index = dir_index + i
		if index >= 8:
			index -= 8
		
		var pixel_pos = walker_pos + directions[index]
		
		if is_pixel_in_bounds(pixel_pos):
			var cell_exists = get_walker_cellv(pixel_pos) != -1
			
			if not is_pixel_visible(image, pixel_pos):
				continue
				
			var new_index = index - 2
			if new_index < 0:
				new_index += 8
				
			if dir_index != new_index:
				dir_index = new_index
				if !cell_exists:
					set_walker_cellv(pixel_pos, 1)
				set_walker_cellv(walker_pos, 0)
				corner_pixels.append(walker_pos)
			elif !cell_exists:
				set_walker_cellv(pixel_pos, 1)
			walker_pos += directions[index]
			
			break
	
	if walker_pos != start_pos and not break_walk:
		return walk_border(image)
	elif break_walk:
		break_walk = false
		return walk_corners(image)
	else:
		return walk_border(image, true)


func walk_corners(image):
	for pos in corner_pixels:
		var cell_scores := []
		for dir in directions:
			var cell = get_walker_cellv(pos + dir)
			if cell == 1:
				cell_scores.append(score_set[0])
			elif cell == 0:
				cell_scores.append(score_set[1])
			elif is_pixel_visible(image, pos + dir):
				cell_scores.append(score_set[2])
			elif cell == -1:
				cell_scores.append(score_set[3])
		
		var corner = TOP_LEFT
		var lowest_score = get_corner_score(cell_scores, 5)
		
		var score = get_corner_score(cell_scores, 7)
		if score < lowest_score:
			lowest_score = score
			corner = TOP_RIGHT
		
		score = get_corner_score(cell_scores, 1)
		if score < lowest_score:
			lowest_score = score
			corner = BOTTOM_RIGHT
		
		score = get_corner_score(cell_scores, 3)
		if score < lowest_score:
			lowest_score = score
			corner = BOTTOM_LEFT
		
		var point = pos
		match corner:
			TOP_LEFT:
				point = pos
			TOP_RIGHT:
				point = pos + Vector2(1, 0)
			BOTTOM_RIGHT:
				point = pos + Vector2(1, 1)
			BOTTOM_LEFT:
				point = pos + Vector2(0, 1)
		
		points.append(point)
	
	var dir := Vector2(0, 0)
	var exclude_arr := []
	for i in points.size():
		if points[i] in line2d.points:
			continue
		
		if i != 0 and i < line2d.points.size() - 1:
			var new_dir = points[i].direction_to(points[i-1])
			if dir == new_dir:
				exclude_arr.append(i)
			dir = new_dir
		
		line2d.add_point(points[i])
	
	for i in exclude_arr.size():
		var j = exclude_arr.size() - i - 1
		line2d.remove_point(j)
	
	var collision = ConvexPolygonShape2D.new()
	var collision_points = Geometry.convex_hull_2d(line2d.points)
	if collision_points.size() > 0:
		collision_points.remove(collision_points.size() - 1)
	collision.set_points(PoolVector2Array(collision_points))
	
	line2d.add_point(points[0])
	
	if not array_has_array(collision.points, line2d.points):
		collision = ConcavePolygonShape2D.new()
		collision_points = []
		for i in line2d.points.size():
			if i == line2d.points.size() - 1:
				break
			collision_points.append(line2d.points[i])
			collision_points.append(line2d.points[i+1])
		collision.set_segments(PoolVector2Array(collision_points))
	
	return collision


func get_corner_score(cell_scores, index) -> int:
	var score := 0
	
	var zero_counter := 0
	for i in 5:
		var dir = index + i
		if dir >= 8:
			dir -= 8
		
		var cell_score = cell_scores[dir]
		if i == 0 or i == 4:
			cell_score /= 2
		elif i == 2:
			cell_score *= 1.5
		
		score += cell_score
		if cell_scores[dir] == 0:
			zero_counter += 1
	
	if zero_counter == 5:
		score = -20
	elif zero_counter >= 3:
		score -= 10
	
	return score

func array_has_array(arr1, arr2) -> bool:
	for i in arr2:
		if not (i in arr1):
			return false
	return true
