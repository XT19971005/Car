extends RefCounted
## Ordered gates, direction and proximity are all required. Teleporting never earns progress.
const GATES := 24
var target_laps := 3
var lap := 1
var elapsed := 0.0
var lap_time := 0.0
var next_gate := 1
var valid := true
var finished := false
var laps: Array[Dictionary] = []
var previous_progress := 0.0
var sector_start := 0.0
var sectors: Array[float] = []
var last_sector := 0.0
var best := 0.0

func reset(count: int) -> void:
	target_laps = count
	lap = 1
	elapsed = 0.0
	lap_time = 0.0
	next_gate = 1
	valid = true
	finished = false
	laps.clear()
	previous_progress = 0.0
	sector_start = 0.0
	sectors.clear()
	last_sector = 0.0
	best = 0.0

func relocate(progress: float) -> void:
	previous_progress = progress
	valid = false

func tick(dt: float, progress: float, on_road: bool, forward: bool) -> String:
	if finished:
		return ""
	elapsed += dt
	lap_time += dt
	var travel := fposmod(progress - previous_progress + 0.5, 1.0) - 0.5
	var old := previous_progress
	previous_progress = progress
	if not forward or not on_road or travel <= 0.0 or travel > 0.035:
		return ""
	var gate := float(next_gate % GATES) / GATES
	var distance := fposmod(gate - old, 1.0)
	if distance <= 0.000001 or distance > travel + 0.000001:
		return ""
	next_gate += 1
	if (next_gate - 1) % 8 == 0:
		last_sector = lap_time - sector_start
		sectors.append(last_sector)
		sector_start = lap_time
	if next_gate <= GATES:
		return "sector" if (next_gate - 1) % 8 == 0 else "gate"
	laps.append({"time": lap_time, "valid": valid, "sectors": sectors.duplicate()})
	if valid and (best == 0.0 or lap_time < best):
		best = lap_time
	if lap >= target_laps:
		finished = true
		return "finish"
	lap += 1
	lap_time = 0.0
	next_gate = 1
	valid = true
	sector_start = 0.0
	sectors.clear()
	return "lap"

static func time_text(seconds: float) -> String:
	if seconds <= 0.0:
		return "—:—.———"
	var milliseconds := int(round(seconds * 1000.0))
	return "%02d:%02d.%03d" % [milliseconds / 60000, (milliseconds / 1000) % 60, milliseconds % 1000]
