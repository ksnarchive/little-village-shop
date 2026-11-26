class_name ExplorationUI
extends CanvasLayer
## Screen-space outdoor HUD; uses the existing DOM controls and shared theme.
signal modal_changed(open: bool)
signal save_requested
var modal: PanelContainer
var words: Label
var heading: Label
var hint: Label
var notice: Label
var thought: Label
var save_button: Button
var close_button: Button
var modal_kind := ""
var prompt := ""

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.theme = InventoryMenu.cozy_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := FrontendUI.label("ТИХАЯ СТАНЦИЯ   ·   Найти купленную лавку >", 13)
	title.position = Vector2(12, 8)
	title.add_theme_stylebox_override("normal", InventoryMenu._style(Color("#f3e4c5"), Color("#94513a"), 5))
	root.add_child(title)
	thought = FrontendUI.label("", 14)
	thought.position = Vector2(30, 245)
	thought.size = Vector2(580, 62)
	thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thought.add_theme_stylebox_override("normal", InventoryMenu._style(Color(0.95, 0.89, 0.77, 0.95), Color("#94513a"), 8))
	thought.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(thought)
	hint = FrontendUI.label("", 13)
	hint.position = Vector2(170, 322)
	hint.size = Vector2(300, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_stylebox_override("normal", InventoryMenu._style(Color("#f6d47d"), Color("#94513a"), 5))
	root.add_child(hint)
	notice = FrontendUI.label("", 11)
	notice.position = Vector2(12, 348)
	root.add_child(notice)
	modal = PanelContainer.new()
	modal.position = Vector2(60, 66)
	modal.size = Vector2(520, 234)
	root.add_child(modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	modal.add_child(box)
	heading = FrontendUI.label("", 20)
	box.add_child(heading)
	words = FrontendUI.label("", 15)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size = Vector2(490, 88)
	box.add_child(words)
	save_button = FrontendUI.button("Сохранить", func(): save_requested.emit())
	box.add_child(save_button)
	InventoryMenu.fit_web_button(save_button)
	close_button = FrontendUI.button("Вернуться  (Esc)", close)
	box.add_child(close_button)
	InventoryMenu.fit_web_button(close_button)
	modal.hide()
	thought.hide()
	set_prompt("")

func show_message(title: String, text: String, kind: String = "inspect") -> void:
	modal_kind = kind
	heading.text = title
	words.text = text
	save_button.visible = kind == "pause"
	modal.show()
	modal_changed.emit(true)
	set_prompt(prompt)
	close_button.grab_focus()

func close() -> void:
	modal.hide()
	modal_kind = ""
	modal_changed.emit(false)
	set_prompt(prompt)

func set_prompt(text: String) -> void:
	prompt = text
	var action := text.trim_prefix("E  ") if not modal.visible else ""
	hint.text = action if OS.has_feature("web") else ("E  " + action if not action.is_empty() else "")
	hint.visible = not action.is_empty()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.setShopAction && window.setShopAction(%s)" % JSON.stringify(action))
