extends ScrollContainer
class_name ItemDisplay

const HOVER_SFX := preload("res://audio/sfx/ui/GUI_rollover.ogg")
const CLICK_SFX := preload("res://audio/sfx/ui/Click.ogg")

# Text when hovering over a wearable item
const HOVER_TXT := "\n[color=%s]%s[/color]"

const CLICK_TO_WEAR = "Click to wear."
var WEAR_COLOR = Color.WEB_GREEN.to_html()

const CLICK_TO_TAKE_OFF = "Click to take off."
var TAKE_OFF_COLOR = Color.RED.to_html()

@onready var item_container: HBoxContainer = %ItemContainer

func _ready() -> void:
	ItemService.s_item_applied.connect(add_new_item)
	Util.s_floor_started.connect(func(_x=null): show())
	Util.s_floor_ended.connect(func(_x=null): hide())
	BattleService.s_battle_started.connect(func(_x=null): hide())
	BattleService.s_battle_ended.connect(func(_x=null): if Util.floor_number != -1: show())

	if not Util.get_player():
		await Util.s_player_assigned
	for item: Item in Util.get_player().stats.items:
		add_new_item(item)

func add_new_item(item: Item) -> void:
	if not item.icon:
		return
	
	var new_tex := TextureButton.new()
	new_tex.custom_minimum_size = Vector2(48, 48)
	new_tex.pivot_offset = Vector2(24, 24)
	new_tex.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	new_tex.ignore_texture_size = true
	new_tex.texture_normal = item.icon
	
	if item is ItemAccessory:
		new_tex.pressed.connect(item_clicked.bind(item))
	
	new_tex.mouse_entered.connect(hover_item.bind(item, new_tex))
	new_tex.mouse_exited.connect(stop_hover.bind(new_tex))
	item_container.add_child(new_tex)

func _do_hover(item: Item) -> void:
	var click_to_wear_txt := ''
	
	if item is ItemAccessory:
		click_to_wear_txt = HOVER_TXT
		
		if Util.get_player().is_wearing_item(item):
			click_to_wear_txt = click_to_wear_txt % [TAKE_OFF_COLOR, CLICK_TO_TAKE_OFF]
		else:
			click_to_wear_txt = click_to_wear_txt % [WEAR_COLOR, CLICK_TO_WEAR]
	
	Util.do_item_hover(item, click_to_wear_txt)

func hover_item(item: Item, tex_btn: TextureButton) -> void:
	_do_hover(item)
	
	Sequence.new([
		LerpProperty.new(tex_btn, ^"scale", 0.1, Vector2.ONE * 1.15).interp(Tween.EASE_IN_OUT, Tween.TRANS_QUAD),
	]).as_tween(self)
	AudioManager.play_sound(HOVER_SFX, 6.0)

func stop_hover(tex_btn: TextureButton) -> void:
	HoverManager.stop_hover()
	
	Parallel.new([
		LerpProperty.new(tex_btn, ^"scale", 0.1, Vector2.ONE).interp(Tween.EASE_IN_OUT, Tween.TRANS_QUAD),
	]).as_tween(self)

func item_clicked(item: ItemAccessory) -> void:
	item.wear_item(Util.get_player())
	AudioManager.play_sound(CLICK_SFX)
	
	# Refresh hover text to show different
	# text based on if we're wearing it
	# or not.
	HoverManager.stop_hover()
	_do_hover(item)
