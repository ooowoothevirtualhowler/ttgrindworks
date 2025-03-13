class_name ItemCustomization
extends Node

# Text when hovering over a wearable item
const HOVER_TXT := "\n[color=%s]%s[/color]"

const CLICK_TO_WEAR = "Click to wear."
var WEAR_COLOR = Color.WEB_GREEN.to_html()

const CLICK_TO_TAKE_OFF = "Click to take off."
var TAKE_OFF_COLOR = Color.RED.to_html()

const CLICK_SFX := preload("res://audio/sfx/ui/Click.ogg")

var current_accessories: Dictionary = {
	Item.ItemSlot.HAT: "",
	Item.ItemSlot.GLASSES: "",
	Item.ItemSlot.BACKPACK: ""
}

var item_hovered := false

func _ready() -> void:
	setup_current_accessories()
	setup_hover_manager()
	
	var root_tree := get_tree().get_root().get_tree()
	
	root_tree.node_removed.connect(
		func(node: Node):
			if node.name == "PauseMenu":
				ModLoaderLog.debug("Pause menu left the building", get_parent().MOD_NAME)
				
				# Set this back to false when we exit the pause menu
				# in case it was true.
				item_hovered = false
	)
	
	root_tree.node_added.connect(
		func(node: Node):
			# Finds the pause menu and manipulates it every time
			# it's added to the scene. A new instance is created
			# every time it's opened so we have to do this.
			if node.name == "PauseMenu":
				ModLoaderLog.debug("Pause menu entered", get_parent().MOD_NAME)
				
				var item_display := node.find_child("ItemDisplay")
				if item_display:
					# We gotta wait or else the items won't
					# exist yet.
					if not item_display.is_node_ready():
						await item_display.ready
					
					ModLoaderLog.debug("Trying to modify item display", get_parent().MOD_NAME)
					
					var item: Item
					for item_tex in item_display.get_child(0).get_child(0).get_children():
						# The actual item
						item = item_tex.mouse_entered.get_connections()[0]["callable"].get_bound_arguments()[0]
						ModLoaderLog.debug("Found item: %s" % item.item_name, get_parent().MOD_NAME)
						
						if item is ItemAccessory:
							ModLoaderLog.debug("Item is accessory. Making button.", get_parent().MOD_NAME)
							# This is a button now because we need to press it.
							var new_tex := TextureButton.new()
							new_tex.custom_minimum_size = Vector2(48, 48)
							new_tex.pivot_offset = Vector2(24, 24)
							new_tex.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
							new_tex.ignore_texture_size = true
							new_tex.texture_normal = item.icon
							
							new_tex.pressed.connect(item_clicked.bind(item))
							
							# We can't use the existing callback functions
							# because this is a TextureButton now.
							new_tex.mouse_entered.connect(func():
								item_hovered = true
								
								Util.do_item_hover(item)
								Sequence.new([
									LerpProperty.new(new_tex, ^"scale", 0.1, Vector2.ONE * 1.15).interp(Tween.EASE_IN_OUT, Tween.TRANS_QUAD),
								]).as_tween(item_display)
								AudioManager.play_sound(ItemDisplay.HOVER_SFX, 6.0)
							)
							new_tex.mouse_exited.connect(func():
								item_hovered = false
								
								HoverManager.stop_hover()
								Parallel.new([
									LerpProperty.new(new_tex, ^"scale", 0.1, Vector2.ONE).interp(Tween.EASE_IN_OUT, Tween.TRANS_QUAD),
								]).as_tween(item_display)
							)
							
							# Replace the old UI asset w/ this button.
							item_tex.replace_by(new_tex)
							# Clean it from memory too.
							item_tex.queue_free()
	)

func setup_current_accessories() -> void:
	if not ItemService.is_node_ready():
		await ItemService.ready
	
	# Connect a callback for any new items received
	# so we can track accessories received.
	ItemService.s_item_applied.connect(
		func(item: Item):
			if item.is_acessory:
				change_current_accessory(item.slot, item.item_name)
	)

func setup_hover_manager() -> void:
	if not HoverManager.is_node_ready():
		await HoverManager.ready
	
	HoverManager.hover_root.visibility_changed.connect(modify_hover_text)

func change_current_accessory(slot: int, item_name: String) -> void:
	ModLoaderLog.debug("Current accessory in %d is now %s" % [slot, item_name if item_name != "" else "Nothing"], get_parent().MOD_NAME)
	current_accessories[slot] = item_name

# Copied from apply_item.
# This is just the wearing part without reapplying effects.
func wear_item(item: ItemAccessory) -> void:
	var player := Util.get_player()
	
	# Player isn't ready yet.
	# Wait for their node to be ready.
	if not player.is_node_ready():
		await player.ready
	
	# Find where to put it.
	var bone := ItemAccessory.get_bone(item, player)
	
	# Take the previous one off.
	for accessory in bone.get_children():
		accessory.queue_free()
	
	if item.item_name == current_accessories[item.slot]:
		# Don't put the accessory back on if it was already on.
		
		# Indicate it was taken off too.
		change_current_accessory(item.slot, "")
		return
	
	# Set to new accessory.
	change_current_accessory(item.slot, item.item_name)
	
	# Create new instance of the model.
	var mod := item.model.instantiate()
	
	# Attach it.
	bone.add_child(mod)
	
	# Position it correctly.
	var placement := ItemAccessory.get_placement(item, player.toon.toon_dna)
	mod.position = placement.position
	mod.rotation_degrees = placement.rotation
	mod.scale = placement.scale
	
	# Some accessories require extra setup.
	if mod.has_method('setup'):
		mod.setup(item)

# The new callback for clicking an item in the menu.
# We're only adding this for accessories.
func item_clicked(item: ItemAccessory) -> void:
	# Wear the item.
	wear_item(item)
	
	# Play a click sound too.
	AudioManager.play_sound(CLICK_SFX)
	
	# Refresh hover text to show different
	# text based on if we're wearing it
	# or not.
	HoverManager.stop_hover()
	Util.do_item_hover(item)

func modify_hover_text() -> void:
	# Make sure we're only doing this on the pause menu
	# only when hovering over an inventory item.
	if item_hovered and HoverManager.hover_root.visible:
		# Find item name in the string.
		var item_desc: String = HoverManager.text
		var item_name_start := item_desc.findn("6]") + 2
		var item_name_end := item_desc.rfind("[/f")
		var item_name := item_desc.substr(item_name_start, item_name_end - item_name_start)
		
		# Find if it's an accessory. We need to loop through
		# our current items to find the Item instances.
		for item in Util.get_player().stats.items:
			if item.item_name == item_name and item.is_acessory:
				# Is it currently worn?
				if item_name in current_accessories.values():
					HoverManager.text += HOVER_TXT % [TAKE_OFF_COLOR, CLICK_TO_TAKE_OFF]
				else:
					HoverManager.text += HOVER_TXT % [WEAR_COLOR, CLICK_TO_WEAR]
				break
