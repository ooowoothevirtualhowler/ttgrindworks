extends Node

# ? Item Customization
# ? Allows selecting accessories to wear from the pause menu.

const MOD_NAME := "Ooowoo-Item_Customization" # Full ID of the mod (AuthorName-ModName)
const MOD_DIR := MOD_NAME # Name of the directory that this file is in

var mod_dir_path := ""


func _init() -> void:
	ModLoaderLog.info("Init", MOD_NAME)
	
	mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
	
	# See https://wiki.godotmodding.com/guides/modding/global_classes_and_child_nodes/ for why we
	# do this.
	var runner: Node = load(mod_dir_path.path_join("item_customization.gd")).new()
	runner.name = "ItemCustomization"
	add_child(runner)


func _ready() -> void:
	ModLoaderLog.info("Ready", MOD_NAME)
