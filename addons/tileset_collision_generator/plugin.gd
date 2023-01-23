tool
extends EditorPlugin

var generator

func _enter_tree():
	generator = preload("res://addons/tileset_collision_generator/TilesetCollision.tscn").instance()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, generator)


func _exit_tree():
	remove_control_from_docks(generator)
	generator.free()
