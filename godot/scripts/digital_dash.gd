extends Control
const BOLD = preload("res://assets/fonts/NotoSansSC-Bold.otf")
const REGULAR = preload("res://assets/fonts/NotoSansSC-Regular.otf")
var gear := 1
var speed := 0
var rpm := 1100
func _draw() -> void:
	draw_rect(Rect2(0,0,512,192),Color("202a31"))
	for i in 16:
		var lit := rpm > 1000 + i * 430
		var color := Color("e8eef2") if i<11 else Color("ffd45b") if i<14 else Color("f34a51")
		draw_rect(Rect2(18+i*30,12,24,8),color if lit else Color("263039"))
	draw_line(Vector2(160,38),Vector2(160,166),Color("38444e"),2)
	draw_string(REGULAR,Vector2(40,51),"挡位",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("8999a6"))
	draw_string(BOLD,Vector2(42,137),"倒" if gear<0 else "空" if gear==0 else str(gear),HORIZONTAL_ALIGNMENT_LEFT,-1,76,Color("ffd45b"))
	draw_string(BOLD,Vector2(188,128),str(speed),HORIZONTAL_ALIGNMENT_LEFT,-1,82,Color("f0f4f7"))
	draw_string(REGULAR,Vector2(374,126),"公里/时",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("8999a6"))
	draw_line(Vector2(186,145),Vector2(488,145),Color("38444e"),1)
	draw_string(REGULAR,Vector2(188,176),str(rpm),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("b7c4cf"))
	draw_string(REGULAR,Vector2(374,176),"转/分",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("8999a6"))
