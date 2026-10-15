extends Control
## All interface layout and visual state live here; callbacks are intent signals.
signal primary_pressed
signal pause_pressed
signal restart_pressed
signal sound_pressed
signal home_pressed
const FONT = preload("res://assets/fonts/NotoSansCJK.ttc")
const TEXT := Color("e2f2ed")
const MUTED := Color("75949c")
const MINT := Color("8bf0c1")
var score_label: Label
var best_label: Label
var brand: Label
var pause_button: Button
var mute_button: Button
var overlay: Control
var shade: ColorRect
var stack: VBoxContainer
var eyebrow: Label
var title_label: Label
var detail_label: Label
var result_score: Label
var primary: Button
var secondary: Button
var help_button: Button
var footnote: Label
var modal_mode: String = "ready"
var previous_modal: String = "ready"
var last_score: int = 0
var last_best: int = 0
var sound_muted: bool = false

func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 20
	theme = ui_theme
	brand = _label("S N A K E", 21, MUTED)
	add_child(brand)
	score_label = _label("0", 46, TEXT)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(score_label)
	best_label = _label("最佳  0", 18, MUTED)
	add_child(best_label)
	mute_button = _button("♪", false)
	mute_button.add_theme_font_size_override("font_size", 24)
	mute_button.tooltip_text = "声音开关"
	mute_button.pressed.connect(func(): sound_pressed.emit())
	add_child(mute_button)
	pause_button = _button("Ⅱ", false)
	pause_button.add_theme_font_size_override("font_size", 26)
	pause_button.tooltip_text = "暂停 / Esc"
	pause_button.pressed.connect(func(): pause_pressed.emit())
	add_child(pause_button)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	shade = ColorRect.new()
	shade.color = Color(0.025, 0.075, 0.10, 0.89)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	overlay.add_child(stack)
	eyebrow = _label("C L A S S I C   S N A K E", 14, MINT)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(eyebrow)
	title_label = _label("从一口开始。", 58, TEXT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title_label)
	detail_label = _label("吃下光点，把每一步走得更远。", 20, MUTED)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size.y = 50
	stack.add_child(detail_label)
	result_score = _label("0", 76, MINT)
	result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(result_score)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	stack.add_child(spacer)
	primary = _button("开始游戏", true)
	primary.custom_minimum_size = Vector2(280, 64)
	primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	primary.pressed.connect(func():
		if modal_mode == "help":
			show_modal(previous_modal, last_score, last_best)
		else:
			primary_pressed.emit())
	stack.add_child(primary)
	secondary = _button("重新开始", false)
	secondary.custom_minimum_size = Vector2(280, 50)
	secondary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	secondary.pressed.connect(func(): restart_pressed.emit())
	stack.add_child(secondary)
	help_button = _button("玩法", false)
	help_button.custom_minimum_size = Vector2(180, 46)
	help_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	help_button.pressed.connect(_show_help)
	stack.add_child(help_button)
	footnote = _label("", 15, MUTED)
	footnote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(footnote)
	# Utility controls stay reachable above modal shading, including on touch.
	move_child(mute_button, -1)
	move_child(pause_button, -1)
	resized.connect(_layout)
	show_modal("ready", 0, 0)
	_layout()

func _layout() -> void:
	if brand == null:
		return
	var width := size.x
	var margin := clampf(width * 0.035, 18.0, 54.0)
	brand.position = Vector2(margin, 34)
	score_label.position = Vector2(width * 0.5 - 70, 13)
	score_label.size = Vector2(140, 80)
	best_label.position = Vector2(width - margin - 310, 37)
	pause_button.position = Vector2(width - margin - 48, 24)
	pause_button.size = Vector2(48, 48)
	mute_button.position = Vector2(width - margin - 110, 24)
	mute_button.size = Vector2(48, 48)
	stack.size.x = minf(620, width - 48)
	stack.position.x = (width - stack.size.x) * 0.5
	# VBox recalculates height after text/visibility changes; defer final centering.
	_center_stack.call_deferred()

func _center_stack() -> void:
	stack.size.y = stack.get_combined_minimum_size().y
	stack.position.y = maxf(122, (size.y - stack.size.y) * 0.50 + 30)

func update_values(score: int, best: int) -> void:
	last_score = score
	last_best = best
	score_label.text = str(score)
	best_label.text = "最佳  %d" % best

func set_sound_muted(value: bool) -> void:
	sound_muted = value
	mute_button.text = "×" if value else "♪"
	mute_button.tooltip_text = "开启声音" if value else "关闭声音"

func hide_modal() -> void:
	overlay.hide()
	pause_button.show()

func show_modal(mode: String, score: int, best: int, is_record: bool = false) -> void:
	modal_mode = mode
	last_score = score
	last_best = best
	overlay.show()
	pause_button.visible = mode == "paused"
	result_score.hide()
	secondary.hide()
	help_button.show()
	footnote.text = ""
	title_label.add_theme_font_size_override("font_size", 58)
	eyebrow.text = "C L A S S I C   S N A K E"
	match mode:
		"ready":
			title_label.text = "从一口开始。"
			detail_label.text = "吃下光点，把每一步走得更远。"
			primary.text = "开始游戏"
			footnote.text = "Enter 开始"
		"paused":
			eyebrow.text = "T A K E   A   B R E A T H"
			title_label.text = "稍作停留。"
			detail_label.text = "当前得分  %d" % score
			primary.text = "继续游戏"
			secondary.show()
			footnote.text = "Esc / 空格 继续"
		"dead", "won":
			eyebrow.text = "N E W   B E S T" if is_record else "W E L L   P L A Y E D"
			title_label.text = "再来一局？" if mode == "dead" else "你填满了整片棋场！"
			title_label.add_theme_font_size_override("font_size", 48)
			detail_label.text = "新的最佳纪录，漂亮。" if is_record else "每一口，都算数。"
			if mode == "won":
				detail_label.text = "完美通关。每一步都恰到好处。"
			result_score.text = str(score)
			result_score.show()
			primary.text = "再玩一次"
			footnote.text = "Enter 再玩"
		"help":
			eyebrow.text = "H O W   T O   P L A Y"
			title_label.text = "简单。再长一点。"
			title_label.add_theme_font_size_override("font_size", 42)
			detail_label.text = "方向键 / WASD 转向，触屏滑动也可以。\n吃到橙色光点 +10 分，身体变长，速度逐渐提升。\n撞到边缘或自己的身体，游戏结束。\n\nEsc / 空格 暂停　·　R 重新开始"
			primary.text = "知道了"
			help_button.hide()
	stack.reset_size()
	_layout()

func _show_help() -> void:
	previous_modal = modal_mode
	show_modal("help", last_score, last_best)

func close_help() -> void:
	if modal_mode == "help":
		show_modal(previous_modal, last_score, last_best)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, filled: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("173c37") if filled else MUTED)
	button.add_theme_color_override("font_hover_color", Color("12332d") if filled else TEXT)
	button.add_theme_color_override("font_pressed_color", Color("12332d") if filled else MINT)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(14)
		style.content_margin_left = 20.0 if filled else 8.0
		style.content_margin_right = 20.0 if filled else 8.0
		if filled:
			style.bg_color = Color("8bf0c1")
			if state_name == "hover":
				style.bg_color = Color("b2ffdb")
			elif state_name == "pressed":
				style.bg_color = Color("60cca2")
		else:
			style.bg_color = Color(0.25, 0.48, 0.49, 0.12 if state_name == "hover" else 0.0)
		button.add_theme_stylebox_override(state_name, style)
	return button
