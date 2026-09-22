extends CanvasLayer
signal home_requested
signal weather_selected(key: String)
signal start_requested
signal track_selected(key: String)
signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal camera_requested
signal volume_changed(value: float)
signal fullscreen_changed(value: bool)
signal vehicle_selected(key: String)
signal cockpit_selected(enabled: bool)
signal reduced_motion_changed(enabled: bool)
const MapScript = preload("res://scripts/track_map.gd")
const Session = preload("res://scripts/race_session.gd")
const INK := Color("101b28")
const MUTED := Color("a2b4c2")
const ACCENT := Color("eb3147")
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
var vehicle_choice: OptionButton
var cockpit_choice: CheckButton
var reduced_motion: CheckButton
var vehicle_detail: Label

func _ready() -> void:
	layer = 10
	var paths: Dictionary = get_meta("control_paths")
	for field: String in paths:
		if field != "grid": set(field, get_node(paths[field]))
	menu.set_meta("grid", get_node(paths.grid))
	start_button.pressed.connect(func(): start_requested.emit())
	volume_slider.value_changed.connect(func(value: float): volume_changed.emit(value))
	fullscreen_toggle.toggled.connect(func(value: bool): fullscreen_changed.emit(value))
	cockpit_choice.toggled.connect(func(value: bool): cockpit_selected.emit(value))
	reduced_motion.toggled.connect(func(value: bool): reduced_motion_changed.emit(value))
	for i in vehicle_choice.item_count:
		vehicle_choice.set_item_metadata(i, ["v8", "r6", "v6"][i])
	vehicle_choice.item_selected.connect(func(index: int): vehicle_selected.emit(vehicle_choice.get_item_metadata(index)))
	var weather_choice := find_child("WeatherChoice", true, false) as OptionButton
	for i in weather_choice.item_count:
		weather_choice.set_item_metadata(i, preload("res://scripts/weather_controller.gd").KEYS[i])
	weather_choice.item_selected.connect(func(index: int): weather_selected.emit(weather_choice.get_item_metadata(index)))
	for item in root.find_children("*", "Button", true, false):
		if item.text.begins_with("←"): item.pressed.connect(func(): home_requested.emit())
		elif item.text.begins_with("Esc"): item.pressed.connect(func(): pause_requested.emit())
		elif item.text.begins_with("C "): item.pressed.connect(func(): camera_requested.emit())

static func panel(color: Color, padding := 20) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(2)
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
		item.add_theme_color_override("font_color", Color.WHITE)
		item.add_theme_color_override("font_focus_color", Color.WHITE)
	item.pressed.connect(action)
	parent.add_child(item)
	return item

func populate_tracks(catalog: Dictionary) -> void:
	var grid: GridContainer = menu.get_meta("grid")
	for child in grid.get_children():
		var key: String = child.get_meta("track_key")
		track_buttons[key] = child
		child.pressed.connect(func(): track_selected.emit(key))

func select_track(key: String, data: Dictionary, world: Node3D, best: float) -> void:
	track_title.text = data.name
	track_detail.text = "%s  /  全长 %.3f 公里" % [data.region, world.length / 1000.0]
	track_best.text = "个人最佳   " + Session.time_text(best)
	preview.configure(world.points)
	preview.driver = Vector2(world.points[0].x, world.points[0].z)
	minimap.configure(world.points)
	for track: String in track_buttons:
		track_buttons[track].add_theme_stylebox_override("normal", panel(Color("8e2431") if track == key else Color("191c22"), 12))

func _clear_modal() -> void:
	for child in modal_stack.get_children():
		modal_stack.remove_child(child)
		child.queue_free()
	modal.show()

func show_pause() -> void:
	_clear_modal()
	label(modal_stack, "暂停", 32)
	label(modal_stack, "比赛计时已暂停", 18, MUTED)
	resume_button = button(modal_stack, "继续比赛", func(): resume_requested.emit(), true)
	button(modal_stack, "重新开始", func(): restart_requested.emit())
	button(modal_stack, "返回主界面", func(): menu_requested.emit())
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
	button(modal_stack, "返回主界面", func(): menu_requested.emit())
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
	speed_label.text = str(int(absf(car.speed) * 3.6))
	var gear_text := "倒" if car.gear < 0 else "空" if car.gear == 0 else str(car.gear)
	root.find_child("GearLarge",true,false).text = gear_text
	gear_label.text = "公里/时    ·    " + ("自动换挡" if car.automatic_gears else "手动换挡")
	rpm_bar.value = car.rpm
	lap_label.text = "计时赛   /   第 %d / %d 圈" % [session.lap, session.target_laps]
	timer_label.text = Session.time_text(session.lap_time) if session.lap_time > 0 else "00:00.000"
	best_label.text = "个人最佳  " + Session.time_text(personal_best)
	progress_bar.value = progress
	status_label.text = status
	minimap.driver = Vector2(car.position.x, car.position.z)
	minimap.direction = Vector2(sin(car.heading), cos(car.heading))
	minimap.queue_redraw()
