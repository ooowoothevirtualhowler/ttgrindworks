extends Control

const SETTINGS_MENU := preload('res://objects/general_ui/settings_menu/settings_menu.tscn')
const SFX_OPEN := preload("res://audio/sfx/ui/GUI_stickerbook_open.ogg")
const SFX_CLOSE := preload("res://audio/sfx/ui/GUI_stickerbook_delete.ogg")
const ANOMALY_ICON := preload("res://objects/player/ui/anomaly_icon.tscn")

var settings_menu: UIPanel

enum MenuPage {
	GENERAL,
	GAGS
}

@onready var StatInfo: Array = [
	[%Damage, "damage"],
	[%Defense, "defense"],
	[%Evasiveness, "evasiveness"],
	[%Luck, "luck"],
	[%Speed, "speed"],
]

@export var quest_scrolls: Array[QuestScroll]

var current_page := int(MenuPage.GENERAL)

# Hack to prevent immediately closing
var just_opened := false

func _ready() -> void:
	hide()
	
	if is_instance_valid(Util.floor_manager):
		if Util.floor_manager.floor_variant:
			%FloorLabel.set_text(Util.floor_manager.floor_variant.floor_name)
			for floor_icon: TextureRect in [%FacilityIcon, %FacilityIcon2]:
				floor_icon.texture = Util.floor_manager.floor_variant.floor_icon
			if Util.floor_manager.anomalies:
				for floor_mod: FloorModifier in Util.floor_manager.anomalies:
					var new_icon: Control = ANOMALY_ICON.instantiate()
					new_icon.instantiated_anomaly = floor_mod
					%AnomaliesContainer.add_child(new_icon)
				# Move it up to account for the anomaly icons
				%FloorMainContainer.position.y -= 68
	else:
		%FloorMainContainer.hide()
	
	sync_reward()
	
	%PageSelector.s_option_changed.connect(update_page)
	
	%VersionLabel.text = Globals.VERSION_NUMBER
	
func update_page(index: int):
	current_page = index
	
	var battle_ui := Util.get_player().battle_ui
	
	match index:
		MenuPage.GENERAL:
			# Make sure we don't detach it
			# if we somehow open this in a battle.
			battle_ui_callback(remove_child.bind(battle_ui))
			
			# Reset fudged position.
			battle_ui.offset.y = 0
			
			%FloorMainHolder.show()
			%Quests.show()
			%StatsHolder.show()
			%RewardHolder.show()
		MenuPage.GAGS:
			%FloorMainHolder.hide()
			%Quests.hide()
			%StatsHolder.hide()
			%RewardHolder.hide()
			
			if not battle_ui.is_inside_tree():
				add_child(battle_ui)
			
			# Fudge position a little so it doesn't
			# cover buttons.
			battle_ui.offset.y = -50
			
			# Don't show back up if the settings
			# were left open.
			battle_ui.reset(not(is_instance_valid(settings_menu) and settings_menu.is_visible_in_tree()))

func battle_ui_callback(callback: Callable) -> void:
	if not is_instance_valid(Util.get_player()):
		return
	
	if is_ancestor_of(Util.get_player().battle_ui):
		callback.call()

func open() -> void:
	get_tree().paused = true
	just_opened = true
	
	get_player_info()
	apply_stat_labels()
	
	# This isn't unhiding for some reason.
	%ItemDisplay.show()
	
	show()
	
	update_page(current_page)
	
	AudioManager.set_fx_music_lpfilter()
	AudioManager.play_sound(SFX_OPEN)
	
	$AnimationPlayer.play("pause_on")

func close() -> void:
	get_tree().paused = false
	
	AudioManager.reset_fx_music_lpfilter()
	AudioManager.play_sound(SFX_CLOSE)
	
	battle_ui_callback(
		func():
			var battle_ui := Util.get_player().battle_ui
			
			if battle_ui.item_panel.is_visible_in_tree():
				battle_ui.item_panel.exit()
			
			# Reset fudged position.
			battle_ui.offset.y = 0
			
			battle_ui.hide()
	)
	hide()
	
	$AnimationPlayer.play("RESET")

func apply_stat_labels() -> void:
	for stat_array: Array in StatInfo:
		stat_array[0].text = '%s: %.2f' % [
			stat_array[1].capitalize(),
			Util.get_player().stats.get_stat(stat_array[1])
		]

func get_player_info() -> void:
	var player := Util.get_player()
	if not is_instance_valid(player):
		return
	
	# Get player quests
	var quests: Array[Quest] = player.stats.quests
	for i in quest_scrolls.size():
		var scroll := quest_scrolls[i]
		if quests.size() < i + 1:
			scroll.hide()
		else:
			scroll.quest = quests[i]
		
		# Hook up player rerolls
		scroll.set_rerolls(player.stats.quest_rerolls)
		
		if not scroll.s_quest_rerolled.is_connected(on_quest_rerolled):
			scroll.s_quest_rerolled.connect(on_quest_rerolled)
	
	# Make quests uncompletable if not in walk state
	if not player.state == Player.PlayerState.WALK:
		for scroll in quest_scrolls:
			scroll.collect_button.set_disabled(true)

func quit() -> void:
	var battle_ui := Util.get_player().battle_ui
	
	# Hide it so the quit panel doesn't get obscured.
	battle_ui_callback(battle_ui.hide)
	
	var quit_panel := Util.acknowledge("Quit game?")
	quit_panel.cancelable = true
	quit_panel.get_node('Panel/GeneralButton').pressed.connect(
		func():
			battle_ui.queue_free()
			
			SceneLoader.clear_persistent_nodes()
			SceneLoader.load_into_scene("res://scenes/title_screen/title_screen.tscn")
			
			close()
			
			queue_free()
	)
	
	# When this whole menu is closed, close the quit
	# panel too.
	hidden.connect(quit_panel.close, CONNECT_ONE_SHOT)
	
	# And show it again after we close the quit panel.
	quit_panel.s_closed.connect(
		func():
			# Don't show back up if we closed the menu
			# while the quit panel was still open.
			if is_visible_in_tree():
				battle_ui_callback(battle_ui.show),
	CONNECT_ONE_SHOT)
	quit_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	tree_exited.connect(quit_panel.queue_free)

func open_settings() -> void:
	var battle_ui := Util.get_player().battle_ui
	
	# Hide it so the settings don't get obscured.
	battle_ui_callback(battle_ui.hide)
	
	if not is_instance_valid(settings_menu):
		settings_menu = SETTINGS_MENU.instantiate()
	
	add_child(settings_menu)
	
	tree_exited.connect(settings_menu.queue_free)
	
	# And show it again after we close the settings.
	settings_menu.s_closed.connect(battle_ui_callback.bind(battle_ui.show), CONNECT_ONE_SHOT)

func on_quest_rerolled() -> void:
	Util.get_player().stats.quest_rerolls -= 1
	for scroll: QuestScroll in quest_scrolls:
		scroll.set_rerolls(Util.get_player().stats.quest_rerolls)

func _physics_process(_delta : float) -> void:
	# Hack to prevent immediately closing
	if Input.is_action_just_pressed('pause') and not just_opened:
		close()
	
	if just_opened:
		just_opened = false

#region Reward Display
func sync_reward() -> void:
	var game_floor := Util.floor_manager
	if is_instance_valid(game_floor) and game_floor.floor_variant and game_floor.floor_variant.reward:
			set_reward(game_floor.floor_variant.reward)
			%NoReward.hide()
	else:
		%NoReward.show()

func set_reward(item: Item) -> void:
	# Add new reward to menu
	var reward_model = item.model.instantiate()
	%RewardView.camera_position_offset = item.ui_cam_offset
	%RewardView.node = reward_model
	%RewardView.want_spin_tween = item.want_ui_spin
	
	# Let item set itself up
	if reward_model.has_method('setup'):
		reward_model.setup(item)

	%RewardView.mouse_entered.connect(hover_floor_reward.bind(item))
	%RewardView.mouse_exited.connect(HoverManager.stop_hover)

func hover_floor_reward(item: Item) -> void:
	Util.do_item_hover(item)
#endregion
