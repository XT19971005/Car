extends SceneTree
var failures := 0
func _initialize(): run.call_deferred()
func check(ok: bool, title: String):
	print("SAVE ", "PASS: " if ok else "FAIL: ", title)
	if not ok: failures+=1
func run():
	var game = load("res://scenes/Main.tscn").instantiate()
	# Exercise the real save/load functions in an isolated file, never the user's save.
	game.preferences_path="res://test-output/selfcheck-driver.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.test_mode=false
	game.volume=.37
	game.selected_vehicle="r6"
	game.camera_mode=6
	game.weather_mode="rain"
	game.reduced_motion=true
	game.records={"monza:r6:rain":123.456,"monza:r6:clear":115.0}
	game._save_preferences()
	check(FileAccess.file_exists(game.preferences_path),"Actual save file written")
	game.preferences=ConfigFile.new()
	game.volume=0
	game.selected_vehicle="v8"
	game.camera_mode=0
	game.weather_mode="clear"
	game.reduced_motion=false
	game.records={}
	game._load_preferences()
	check(is_equal_approx(game.volume,.37) and game.reduced_motion,"Volume and motion settings survive reload")
	check(game.selected_vehicle=="r6" and game.camera_mode==6 and game.weather_mode=="rain","Car, camera and weather survive reload")
	check(is_equal_approx(game.best_time(),123.456),"Wet record survives reload")
	game.weather_mode="clear"
	check(is_equal_approx(game.best_time(),115.0),"Dry record remains separate")
	game.preferences.set_value("settings","vehicle","missing_car")
	game.preferences.set_value("settings","weather","missing_weather")
	game.preferences.set_value("settings","camera",99)
	game.preferences.set_value("settings","volume",5.0)
	game.preferences.set_value("settings","automatic_gears",false)
	game.preferences.save(game.preferences_path)
	game._load_preferences()
	check(game.selected_vehicle=="v8" and game.weather_mode=="clear","Unknown saved selections fall back safely")
	check(game.volume==1.0 and game.camera_mode==7 and game.automatic_gears,"Old settings clamp and retain automatic gears")
	var saved := FileAccess.get_file_as_string(game.preferences_path)
	game.test_mode=true
	game.volume=0
	game._save_preferences()
	check(saved==FileAccess.get_file_as_string(game.preferences_path),"Test mode does not write saves")
	game.queue_free()
	await process_frame
	print("SAVE RESULT: 8 checks, failures=",failures)
	quit(1 if failures else 0)
