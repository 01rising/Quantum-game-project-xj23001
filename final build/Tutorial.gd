extends Control

const MAIN_MENU_SCENE := "res://MainMenu.tscn"

var crisis_icon_paths = {
	"Flood": "res://assets/icons/crisis/flood.png",
	"Wildfire": "res://assets/icons/crisis/wildfire.png",
	"Medical": "res://assets/icons/crisis/medical.png",
	"Infrastructure": "res://assets/icons/crisis/infrastructure.png",
	"Food Shortage": "res://assets/icons/crisis/food_shortage.png"
}

var aid_icon_paths = {
	"Water Rescue": "res://assets/icons/aid/water_rescue.png",
	"Fire Response": "res://assets/icons/aid/fire_response.png",
	"Medical Supplies": "res://assets/icons/aid/medical_supplies.png",
	"Repair Team": "res://assets/icons/aid/repair_team.png",
	"Food Aid": "res://assets/icons/aid/food_aid.png"
}

var tutorial_pages = [
	{
		"title": "OPERATION CRISIS SKIES",
		"text": "[center][font_size=22][color=#eef7ff]MISSION BACKGROUND[/color][/font_size][/center]\n\nIn the near future, climate disasters spread faster than traditional response systems can manage.\n\nThe Global Crisis Response Network has deployed quantum-assisted airlift teams to stabilize affected regions before global instability reaches critical levels."
	},
	{
		"title": "HOW TO PLAY",
		"text": "[center][font_size=22][color=#eef7ff]TURN FLOW[/color][/font_size][/center]\n\n• Deploy your active team around the crisis map.\n• Land on crisis tiles to respond to emergencies.\n• Equip the correct aid before responding.\n• Ignored crises can worsen and increase global instability.\n\nChanging aid costs a turn, so plan ahead."
	},
	{
		"title": "AID TYPES",
		"text": "[center][font_size=22][color=#eef7ff]MATCH THE RESPONSE[/color][/font_size][/center]\n\nEach crisis type requires the correct aid. Use the guide below to prepare the right response.",
		"show_icons": true
	},
	{
		"title": "QUANTUM TOOLS",
		"text": "[center][font_size=22][color=#eef7ff]QUANTUM SUPPORT[/color][/font_size][/center]\n\nQuantum tools help your teams manage uncertainty.\n\nUse prediction, amplification, stabilization, and entanglement to improve your chances when the crisis map becomes unstable.\n\nThese tools are powerful, but they do not remove risk completely."
	},
	{
		"title": "MISSION OUTCOME",
		"text": "[center][font_size=22][color=#eef7ff]FINAL REPORT[/color][/font_size][/center]\n\nYour final result depends on how many crises you resolve, how much instability remains, and how effectively your teams coordinate aid.\n\nA good response is not only about moving fast. It is about preparing the right aid at the right time."
	}
]

var current_page := 0

var crisis_legend_panel: PanelContainer = null
var crisis_legend_box: VBoxContainer = null

@onready var title_label = $TitleLabel
@onready var briefing_panel = $BriefingPanel
@onready var tutorial_text = $BriefingPanel/TutorialText
@onready var page_label = $PageLabel
@onready var back_button = $BackButton
@onready var previous_button = $PreviousButton
@onready var next_button = $NextButton


func _ready():
	style_tutorial()

	back_button.pressed.connect(_on_back_pressed)
	previous_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)

	create_crisis_icon_legend()
	update_page()


func style_tutorial():
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 34)

	if tutorial_text != null:
		if tutorial_text is RichTextLabel:
			tutorial_text.bbcode_enabled = true
			tutorial_text.fit_content = false
			tutorial_text.scroll_active = false
		else:
			tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if page_label != null:
		page_label.add_theme_font_size_override("font_size", 16)

	for button in [back_button, previous_button, next_button]:
		if button == null:
			continue

		button.custom_minimum_size = Vector2(160, 42)
		button.add_theme_font_size_override("font_size", 18)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.07, 0.13, 0.92)
	panel_style.border_color = Color(0.4, 0.9, 1.0, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24

	if briefing_panel != null and briefing_panel is PanelContainer:
		briefing_panel.add_theme_stylebox_override("panel", panel_style)


func update_page():
	var page = tutorial_pages[current_page]

	title_label.text = page["title"]
	tutorial_text.text = page["text"]
	page_label.text = "Page %d of %d" % [current_page + 1, tutorial_pages.size()]

	previous_button.disabled = current_page == 0
	next_button.text = "Finish" if current_page == tutorial_pages.size() - 1 else "Next"

	var show_icons = page.get("show_icons", false)

	if crisis_legend_panel != null:
		crisis_legend_panel.visible = show_icons

	var screen_size = get_viewport_rect().size
	var bottom_y = screen_size.y - 70
	var page_y = screen_size.y - 120

	if page_label != null:
		page_label.position = Vector2(screen_size.x / 2.0 - 45, page_y)
		page_label.z_index = 10

	if previous_button != null:
		previous_button.position = Vector2(screen_size.x / 2.0 - 260, bottom_y)
		previous_button.z_index = 10

	if back_button != null:
		back_button.position = Vector2(screen_size.x / 2.0 - 80, bottom_y)
		back_button.z_index = 10

	if next_button != null:
		next_button.position = Vector2(screen_size.x / 2.0 + 120, bottom_y)
		next_button.z_index = 10


func create_crisis_icon_legend():
	if crisis_legend_panel != null:
		return

	crisis_legend_panel = PanelContainer.new()
	crisis_legend_panel.name = "CrisisIconLegendPanel"
	crisis_legend_panel.position = Vector2(330, 330)
	crisis_legend_panel.size = Vector2(620, 230)
	crisis_legend_panel.custom_minimum_size = Vector2(620, 230)
	crisis_legend_panel.visible = false
	crisis_legend_panel.z_index = 2
	add_child(crisis_legend_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.13, 0.94)
	style.border_color = Color(0.4, 0.9, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	crisis_legend_panel.add_theme_stylebox_override("panel", style)

	crisis_legend_box = VBoxContainer.new()
	crisis_legend_box.name = "CrisisLegendBox"
	crisis_legend_box.add_theme_constant_override("separation", 4)
	crisis_legend_panel.add_child(crisis_legend_box)

	add_crisis_legend_row("Flood", "Water Rescue")
	add_crisis_legend_row("Wildfire", "Fire Response")
	add_crisis_legend_row("Medical", "Medical Supplies")
	add_crisis_legend_row("Infrastructure", "Repair Team")
	add_crisis_legend_row("Food Shortage", "Food Aid")


func add_crisis_legend_row(crisis_name: String, aid_name: String):
	var row = HBoxContainer.new()
	row.name = crisis_name.replace(" ", "") + "Row"
	row.custom_minimum_size = Vector2(560, 38)
	row.add_theme_constant_override("separation", 14)
	crisis_legend_box.add_child(row)

	var crisis_icon = TextureRect.new()
	crisis_icon.custom_minimum_size = Vector2(32, 32)
	crisis_icon.size = Vector2(32, 32)
	crisis_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crisis_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crisis_icon.texture = load_icon_if_exists(crisis_icon_paths.get(crisis_name, ""))
	row.add_child(crisis_icon)

	var label = Label.new()
	label.text = "%s  →  %s" % [crisis_name, aid_name]
	label.custom_minimum_size = Vector2(470, 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	row.add_child(label)


func load_icon_if_exists(path: String):
	if path == "":
		return null

	if ResourceLoader.exists(path):
		return load(path)

	print("Tutorial missing icon: ", path)
	return null


func _on_previous_pressed():
	if current_page > 0:
		current_page -= 1
		update_page()


func _on_next_pressed():
	if current_page < tutorial_pages.size() - 1:
		current_page += 1
		update_page()
	else:
		_on_back_pressed()


func _on_back_pressed():
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)