extends Node

# ? Mod Label
# ? Changes the version string to include "MODDED" to indicate that the game is running with mods.

const MOD_NAME := "Ooowoo-Mod_Label" # Full ID of the mod (AuthorName-ModName)
const MOD_DIR := MOD_NAME # Name of the directory that this file is in

var mod_dir_path := ""


# ! your _ready func.
func _init() -> void:
	ModLoaderLog.info("Init", MOD_NAME)
	
	mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
	
	# See https://wiki.godotmodding.com/guides/modding/global_classes_and_child_nodes/ for why we
	# do this.
	var runner: Node = load(mod_dir_path.path_join("mod_label.gd")).new()
	runner.name = "ModLabel"
	add_child(runner)


func _ready() -> void:
	ModLoaderLog.info("Ready", MOD_NAME)
