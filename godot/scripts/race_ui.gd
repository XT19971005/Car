extends CanvasLayer
signal start_requested
signal track_selected(key: String)
signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal camera_requested
signal volume_changed(value: float)
signal fullscreen_changed(value: bool)
const MapScript = preload("res://scripts/track_map.gd")
const Session = preload("res://scripts/race_session.gd")
const INK := Color("101b28")
const MUTED := Color("a2b4c2")
const ACCENT := Color("ff895c")
var root: Control
var menu: Control
var hud: Control
var modal: Control
var modal_stack: VBoxContainer
var preview: Control
var minimap: Control
var track_title: Label
var track_detail: Label
var track_best: Label
var start_button: Button
var resume_button: Button
var lap_choice: OptionButton
var volume_slider: HSlider
var fullscreen_toggle: CheckButton
var track_buttons: Dictionary = {}
var speed_label: Label
var gear_label: Label
var lap_label: Label
var timer_label: Label
var best_label: Label
var status_label: Label
var countdown_label: Label
var rpm_bar: ProgressBar
var progress_bar: ProgressBar

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 18
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	theme.default_font = font
	theme.set_color("font_color", "Label", Color("f0f4f7"))
	for kind in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, panel(Color("253547"), 12))
		theme.set_stylebox("hover", kind, panel(Color("3a4e61"), 12))
		theme.set_stylebox("pressed", kind, panel(Color("a84d31"), 12))
		var focus := panel(Color(0, 0, 0, 0), 12)
		focus.set_border_width_all(2)
		focus.border_color = ACCENT
		theme.set_stylebox("focus", kind, focus)
	root.theme = theme
	_build_menu()
	_build_hud()
	_build_modal()

static func panel(color: Color, padding := 20) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

func label(parent: Node, text: String, font_size := 18, color := Color.WHITE) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

func button(parent: Node, text: String, action: Callable, primary := false) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 44
	if primary:
		item.add_theme_stylebox_override("normal", panel(ACCENT, 14))
		item.add_theme_color_override("font_color", INK)
		item.add_theme_color_override("font_focus_color", INK)
	item.pressed.connect(action)
	parent.add_child(item)
	return item

func _build_menu() -> void:
	menu = Control.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.065, 0.1, 0.88)
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	menu.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	margin.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 530
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	label(left, "APEX / CIRCUIT", 36)
	label(left, "找到节奏，刷新你的下一圈。", 20, MUTED)
	label(left, "01  选择赛道", 18, ACCENT)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	label(left, "02  比赛设置", 18, ACCENT)
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 14)
	left.add_child(settings)
	label(settings, "单人计时赛")
	lap_choice = OptionButton.new()
	for number in [1, 3, 5]:
		lap_choice.add_item("%d 圈" % number, number)
	lap_choice.select(1)
	settings.add_child(lap_choice)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "全屏"
	fullscreen_toggle.toggled.connect(func(value: bool): fullscreen_changed.emit(value))
	settings.add_child(fullscreen_toggle)
	var audio_row := HBoxContainer.new()
	left.add_child(audio_row)
	label(audio_row, "音量  ", 17, MUTED)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.01
	volume_slider.value = 0.7
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(func(value: float): volume_changed.emit(value))
	audio_row.add_child(volume_slider)
	start_button = button(left, "开始比赛   →", func(): start_requested.emit(), true)
	start_button.custom_minimum_size.y = 52
	var help := label(left, "W / ↑ 加速    S / ↓ 刹车与倒车    A D / ← → 转向\n空格 手刹    C 切换视角    R 返回赛道    Esc 暂停\n手柄：RT 加速 · LT 刹车 · 左摇杆转向 · Start 暂停", 15, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	label(right, "CIRCUIT BRIEFING", 16, ACCENT)
	track_title = label(right, "", 30)
	track_detail = label(right, "", 17, MUTED)
	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", panel(Color("182737"), 12))
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(map_panel)
	preview = MapScript.new()
	preview.custom_minimum_size = Vector2(260, 240)
	map_panel.add_child(preview)
	track_best = label(right, "", 19, ACCENT)
	label(right, "CLUBSPORT  /  自动变速 · 辅助抓地", 18)
	label(right, "完成所有检查点即可计圈。\n驶离路面或使用复位，本圈不计最佳成绩。", 15, MUTED)
	menu.set_meta("grid", grid)

func populate_tracks(catalog: Dictionary) -> void:
	var grid: GridContainer = menu.get_meta("grid")
	for key: String in catalog:
		var item := button(grid, catalog[key].name, func(): track_selected.emit(key))
		item.custom_minimum_size = Vector2(170, 54)
		item.add_theme_font_size_override("font_size", 16)
		track_buttons[key] = item

func select_track(key: String, data: Dictionary, world: Node3D, best: float) -> void:
	track_title.text = data.name
	track_detail.text = "%s  /  原型路线 %.2f km" % [data.region, world.length / 1000.0]
	track_best.text = "个人最佳   " + Session.time_text(best)
	preview.configure(world.points)
	preview.driver = Vector2(world.points[0].x, world.points[0].z)
	minimap.configure(world.points)
	for track: String in track_buttons:
		track_buttons[track].add_theme_stylebox_override("normal", panel(Color("754431") if track == key else Color("253547"), 12))

func _build_hud() -> void:
	hud = Control.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var timing := PanelContainer.new()
	hud.add_child(timing)
	timing.position = Vector2(24, 24)
	timing.add_theme_stylebox_override("panel", panel(Color(0.04, 0.08, 0.12, 0.86)))
	var timing_stack := VBoxContainer.new()
	timing.add_child(timing_stack)
	lap_label = label(timing_stack, "", 18, ACCENT)
	timer_label = label(timing_stack, "00:00.000", 32)
	best_label = label(timing_stack, "", 16, MUTED)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(260, 6)
	progress_bar.show_percentage = false
	progress_bar.max_value = 1.0
	timing_stack.add_child(progress_bar)
	var map_panel := PanelContainer.new()
	hud.add_child(map_panel)
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_panel.offset_left = -245
	map_panel.offset_right = -25
	map_panel.offset_top = 24
	map_panel.offset_bottom = 204
	map_panel.custom_minimum_size = Vector2(220, 180)
	map_panel.add_theme_stylebox_override("panel", panel(Color(0.04, 0.08, 0.12, 0.82), 8))
	minimap = MapScript.new()
	minimap.custom_minimum_size = Vector2(200, 164)
	map_panel.add_child(minimap)
	var speed_panel := PanelContainer.new()
	hud.add_child(speed_panel)
	speed_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_panel.offset_left = -295
	speed_panel.offset_right = -25
	speed_panel.offset_top = -205
	speed_panel.offset_bottom = -45
	speed_panel.custom_minimum_size = Vector2(270, 160)
	speed_panel.add_theme_stylebox_override("panel", panel(Color(0.04, 0.08, 0.12, 0.9)))
	var speed_stack := VBoxContainer.new()
	speed_panel.add_child(speed_stack)
	speed_label = label(speed_stack, "000", 54)
	gear_label = label(speed_stack, "N   /   KM/H", 18, ACCENT)
	rpm_bar = ProgressBar.new()
	rpm_bar.custom_minimum_size.y = 8
	rpm_bar.max_value = 8000
	rpm_bar.show_percentage = false
	speed_stack.add_child(rpm_bar)
	status_label = label(hud, "", 18)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.offset_left = 28
	status_label.offset_right = 900
	status_label.offset_top = -110
	status_label.offset_bottom = -80
	var actions := HBoxContainer.new()
	hud.add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	actions.offset_left = 24
	actions.offset_right = 350
	actions.offset_top = -70
	actions.offset_bottom = -26
	actions.add_theme_constant_override("separation", 10)
	button(actions, "Esc  暂停", func(): pause_requested.emit())
	button(actions, "C  视角", func(): camera_requested.emit())
	countdown_label = label(hud, "", 76)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	countdown_label.offset_left = -240
	countdown_label.offset_right = 240
	countdown_label.offset_top = -80
	countdown_label.offset_bottom = 50
	hud.hide()

func _build_modal() -> void:
	modal = Control.new()
	root.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.05, 0.08, 0.9)
	modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var container := PanelContainer.new()
	container.custom_minimum_size.x = 540
	container.add_theme_stylebox_override("panel", panel(INK, 30))
	center.add_child(container)
	modal_stack = VBoxContainer.new()
	modal_stack.add_theme_constant_override("separation", 12)
	container.add_child(modal_stack)
	modal.hide()

func _clear_modal() -> void:
	for child in modal_stack.get_children():
		modal_stack.remove_child(child)
		child.queue_free()
	modal.show()

func show_pause() -> void:
	_clear_modal()
	label(modal_stack, "稍作休息", 32)
	label(modal_stack, "比赛计时已暂停", 18, MUTED)
	resume_button = button(modal_stack, "继续比赛", func(): resume_requested.emit(), true)
	button(modal_stack, "重新开始", func(): restart_requested.emit())
	button(modal_stack, "返回选赛道", func(): menu_requested.emit())
	resume_button.grab_focus()

func show_results(session: RefCounted, record: bool) -> void:
	_clear_modal()
	label(modal_stack, "刷新个人最佳！" if record else "冲线完成", 32, ACCENT)
	label(modal_stack, "总用时   " + Session.time_text(session.elapsed), 24)
	label(modal_stack, "最佳有效圈   " + Session.time_text(session.best), 18, MUTED)
	for i in session.laps.size():
		var entry: Dictionary = session.laps[i]
		label(modal_stack, "%02d    %s    %s" % [i + 1, Session.time_text(entry.time), "有效圈" if entry.valid else "练习圈 · 不计纪录"], 18)
	var again := button(modal_stack, "再跑一场", func(): restart_requested.emit(), true)
	button(modal_stack, "选择其他赛道", func(): menu_requested.emit())
	again.grab_focus()

func show_menu() -> void:
	modal.hide()
	hud.hide()
	menu.show()
	start_button.grab_focus()

func show_race() -> void:
	menu.hide()
	modal.hide()
	hud.show()
	var focused := root.get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

func update_hud(car: CharacterBody3D, session: RefCounted, progress: float, personal_best: float, status: String) -> void:
	speed_label.text = "%03d" % int(absf(car.speed) * 3.6)
	gear_label.text = "%s   /   KM/H" % ("R" if car.gear < 0 else ("N" if car.gear == 0 else str(car.gear)))
	rpm_bar.value = car.rpm
	lap_label.text = "计时赛   /   第 %d / %d 圈" % [session.lap, session.target_laps]
	timer_label.text = Session.time_text(session.lap_time) if session.lap_time > 0 else "00:00.000"
	best_label.text = "个人最佳  " + Session.time_text(personal_best)
	progress_bar.value = progress
	status_label.text = status
	minimap.driver = Vector2(car.position.x, car.position.z)
	minimap.direction = Vector2(sin(car.heading), cos(car.heading))
	minimap.queue_redraw()
