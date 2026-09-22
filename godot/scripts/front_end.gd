extends Control
signal race_requested
signal car_selected(key: String)
signal volume_changed(value: float)
signal motion_changed(value: bool)
signal fullscreen_changed(value: bool)
signal exit_requested
const CARS = preload("res://scripts/car_catalog.gd").CARS
var current_car := "v8"

func _ready() -> void:
	DisplayServer.window_set_title("巅峰赛道")
	%Race.pressed.connect(func(): race_requested.emit())
	%Garage.pressed.connect(func(): open_page("garage"))
	%Settings.pressed.connect(func(): open_page("settings"))
	%Quit.pressed.connect(func(): exit_requested.emit())
	%Back.pressed.connect(func(): open_page("home"))
	%Continue.pressed.connect(func(): race_requested.emit())
	%V8.pressed.connect(func(): select_car("v8"))
	%Rally.pressed.connect(func(): select_car("r6"))
	%Prototype.pressed.connect(func(): select_car("v6"))
	%Volume.value_changed.connect(func(value: float): volume_changed.emit(value))
	%Motion.toggled.connect(func(value: bool): motion_changed.emit(value))
	%Fullscreen.toggled.connect(func(value: bool): fullscreen_changed.emit(value))
	$TopNavigation/HomeTab.pressed.connect(func(): open_page("home"))
	$TopNavigation/GarageTab.pressed.connect(func(): open_page("garage"))
	$TopNavigation/OptionsTab.pressed.connect(func(): open_page("settings"))
	open_page("home")

func select_car(key: String) -> void:
	current_car = key
	var data: Dictionary = CARS[key]
	%CarName.text = data.name
	%TopSpeed.text = "%.0f 公里/时" % (float(data.top_speed) * 3.6)
	%CarLength.text = "%.2f 米" % data.length
	car_selected.emit(key)
	for pair in [[%V8, "v8"], [%Rally, "r6"], [%Prototype, "v6"]]:
		pair[0].modulate = Color.WHITE
		if pair[1] == key and %GaragePanel.visible: pair[0].grab_focus()

func open_page(page: String) -> void:
	for pair in [[$TopNavigation/HomeTab, "home"], [$TopNavigation/GarageTab, "garage"], [$TopNavigation/OptionsTab, "settings"]]:
		pair[0].modulate = Color.WHITE if pair[1] == page else Color("82929e")
	$TilesMargin.visible = page == "home"
	$LeftShade.visible = page != "home"
	$Margin/Stack/Edition.visible = page != "home"
	$Margin/Stack/Title.text = "巅峰赛道" if page == "home" else "车库" if page == "garage" else "设置"
	$CarInfo.visible = page == "garage"
	$CarInfo.offset_top = -135
	$CarInfo.offset_bottom = -22
	%Navigation.visible = page == "home"
	%SettingsPanel.visible = page == "settings"
	%GaragePanel.visible = page == "garage"
	%Back.visible = page != "home"
	%Eyebrow.text = "车手中心" if page == "home" else "我的收藏" if page == "garage" else "驾驶偏好"
	(%Race if page == "home" else {"v8": %V8, "r6": %Rally, "v6": %Prototype}[current_car] if page == "garage" else %Volume).grab_focus()
