extends Node

const MODDED_VERSION := " (MODDED)"

func _ready() -> void:
	var root := get_tree().get_root()
	
	root.title += MODDED_VERSION
	
	root.get_tree().node_added.connect(
		func(node: Node):
			match node.name:
				"TitleScreen":
					_entered_title_screen(node)
				"PauseMenu":
					_entered_pause_menu(node)
	)

func _entered_title_screen(node: Node) -> void:
	ModLoaderLog.debug("Title screen entered", get_parent().MOD_NAME)
	
	_find_and_set_version_label(node)

func _entered_pause_menu(node: Node) -> void:
	ModLoaderLog.debug("Pause menu entered", get_parent().MOD_NAME)
	
	if not node.is_node_ready():
		await node.ready
	
	_find_and_set_version_label(node)

func _find_and_set_version_label(node: Node) -> void:
	var version_label := node.find_child("VersionLabel")
	
	if version_label:
		# Make sure the version label is ready.
		if not version_label.is_node_ready():
			await version_label.ready
		
		version_label.text += MODDED_VERSION
