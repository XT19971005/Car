from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

W,H=1334,750
im=Image.new('RGB',(W,H),'#91c6d9'); d=ImageDraw.Draw(im)
fp='C:/Windows/Fonts/msyh.ttc'; bp='C:/Windows/Fonts/msyhbd.ttc'
def F(n,b=False): return ImageFont.truetype(bp if b else fp,n)
def txt(x,y,s,n,fill='#fff',b=False,anchor=None): d.text((x,y),s,font=F(n,b),fill=fill,anchor=anchor)
def rr(box,r,fill,outline=None,w=1): d.rounded_rectangle(box,r,fill=fill,outline=outline,width=w)

# sky / low-poly environment
for y in range(H):
    t=y/H; c=(int(112+45*t),int(182+24*t),int(210+8*t)); d.line((0,y,W,y),fill=c)
d.polygon([(0,244),(110,185),(200,247),(300,152),(398,250),(510,176),(630,250),(740,160),(865,250),(1000,145),(1140,248),(1260,171),(1334,240),(1334,420),(0,420)],fill='#608d8e')
d.polygon([(0,279),(170,219),(310,290),(455,218),(640,296),(790,213),(960,296),(1120,211),(1334,286),(1334,438),(0,438)],fill='#487471')
d.rectangle((0,390,W,H),fill='#5c965d')

# track perspective / curb
d.polygon([(458,360),(876,360),(1334,750),(0,750)],fill='#353d42')
d.polygon([(440,360),(458,360),(0,750),(0,700)],fill='#efe2b3')
d.polygon([(876,360),(895,360),(1334,700),(1334,750)],fill='#efe2b3')
for i in range(9):
    y=405+i*38
    # center line segments
    seg=24+int(i*2.2); x=667-seg//2
    d.rectangle((x,y,x+seg,y+4),fill='#f5f2d8')
    # red/white edge dashes
    d.polygon([(int(458-(y-360)*1.14),y), (int(475-(y-360)*1.14),y), (int(470-(y-360)*1.14),y+18),(int(450-(y-360)*1.14),y+18)],fill='#df5d55' if i%2==0 else '#f4ead4')
    d.polygon([(int(876+(y-360)*1.14),y), (int(893+(y-360)*1.14),y), (int(900+(y-360)*1.14),y+18),(int(881+(y-360)*1.14),y+18)],fill='#df5d55' if i%2==0 else '#f4ead4')

# scenery props
def tree(x,y,s):
    d.polygon([(x,y-s*2),(x-s*.55,y-s*.55),(x-s*.2,y-s*.55),(x-s*.75,y),(x+s*.75,y),(x+s*.2,y-s*.55),(x+s*.55,y-s*.55)],fill='#2f633f')
    d.polygon([(x-s*.1,y),(x+s*.1,y),(x+s*.16,y+s*.7),(x-s*.16,y+s*.7)],fill='#765137')
for x,y,s in [(90,420,75),(190,380,50),(1080,395,58),(1210,430,82),(980,370,34),(330,410,30)]: tree(x,y,s)
d.polygon([(1030,332),(1044,293),(1058,332)],fill='#f4c84a'); d.rectangle((1043,331,1046,367),fill='#674a32')

# car shadow and low-poly car
d.ellipse((515,624,820,704),fill='#172027',width=0)
d.polygon([(575,610),(604,535),(666,503),(730,535),(760,610),(735,669),(600,669)],fill='#c84343',outline='#f57964')
d.polygon([(604,535),(666,503),(730,535),(713,576),(618,576)],fill='#ee695a')
d.polygon([(622,539),(666,516),(710,539),(699,562),(634,562)],fill='#293e4d')
d.polygon([(575,610),(600,589),(620,593),(609,662),(574,654)],fill='#222b31')
d.polygon([(760,610),(735,589),(715,593),(726,662),(761,654)],fill='#222b31')
for x in (594,738):
    d.rounded_rectangle((x,604,x+28,681),8,fill='#1b2024',outline='#4d5961',width=2)
    d.rectangle((x+8,620,x+20,670),fill='#313b42')
d.rectangle((624,651,708,666),fill='#7d222a'); d.rectangle((639,655,693,663),fill='#f16d5e')

# HUD glass panels
rr((34,30,314,166),16,'#10283bdd','#91afbd',2); txt(58,56,'RACE 01',14,'#ffda61',True); txt(58,87,'第 1 名',30,'#fff',True); txt(58,126,'1 / 8 车手',14,'#bfd0d7'); txt(230,87,'圈数',12,'#a9c1ca'); txt(230,113,'1 / 3',24,'#fff',True)
rr((1018,30,1298,192),16,'#10283bdd','#91afbd',2); txt(1042,57,'赛道地图',13,'#ffda61',True)
pts=[(1050,145),(1081,105),(1144,83),(1218,104),(1264,146),(1235,171),(1156,169),(1094,154),(1050,145)]
d.line(pts,fill='#93afbb',width=4,joint='curve'); d.ellipse((1071,95,1089,113),fill='#ffcf4a',outline='#fff',width=2); d.ellipse((1248,137,1266,155),fill='#e75b56',outline='#fff',width=2); txt(1042,178,'主直道 · 发夹弯 · S 弯',11,'#bed0d7')

# speedometer
rr((35,570,365,720),18,'#10283ddd','#91afbd',2); txt(60,594,'速度',12,'#b8ccd4'); txt(60,622,'182',56,'#fff',True); txt(208,653,'KM/H',13,'#b8ccd4',True); txt(283,604,'4',40,'#ffda61',True); txt(279,646,'挡位',11,'#b8ccd4')
d.arc((190,587,330,727),200,340,fill='#385365',width=9); d.arc((190,587,330,727),200,300,fill='#ffcf4a',width=9)
for i in range(6): d.line((56+i*36,696,78+i*36,696),fill='#67828f',width=4)

# right telemetry / controls
rr((997,580,1298,720),18,'#10283ddd','#91afbd',2); txt(1020,607,'引擎转速',12,'#b8ccd4'); rr((1020,634,1275,651),8,'#344e5e'); rr((1020,634,1190,651),8,'#e45a52'); txt(1020,681,'油门',11,'#b8ccd4'); rr((1066,678,1275,687),4,'#344e5e'); rr((1066,678,1205,687),4,'#ffcf4a'); txt(1213,681,'68%',11,'#fff',True)

# center race feedback
rr((530,42,804,87),12,'#10283dcc','#91afbd',1); txt(667,64,'01:24.682',24,'#fff',True,'mm'); txt(667,94,'下一个检查点  380 m',12,'#e4f0f2',False,'mm')
rr((555,188,779,229),12,'#0c2132cc','#ffcf4a',2); txt(667,209,'保持线路 · 准备刹车',14,'#ffdb61',True,'mm')
txt(667,740,'W 加速   S 刹车 / 倒车   A / D 转向   R 重置车辆',12,'#d6e3e7',False,'mm')

im.save('ue_car_prototype.png',optimize=True)
print('ue_car_prototype.png')
