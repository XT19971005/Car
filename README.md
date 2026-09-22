# Apex Circuit — 静态赛道与车库版

打开 `godot/project.godot`，按 F5。先进入主界面，再选择单人计时赛或车库。

## 当前内容

- ACC 布局参考的主界面、3D 车库、独立比赛设置、暂停与结算；原生 Control 场景可编辑。
- 九张米制赛道：蒙扎、斯帕、银石、纽博格林 GP、铃鹿、伊莫拉、红牛环、巴瑟斯特、拉古纳·塞卡。
- 三种原创车身：V8 Muscle GT、Rally Hatch、Apex Prototype，独立尺寸、驾驶参数、驾驶舱和音色。
- 晴天、阴天、雨天和日落：蓝天与云层、雾、雨粒子、湿路反射、抓地和制动变化；成绩按赛道/车型/天气隔离。
- 1/3/5 圈计时赛、顺序检查点、三段计时、车内仪表与实时后视镜、键盘与手柄。

W/S 油门/制动倒车，A/D 转向，空格手刹，C 视角，**R 回到最近路面并使当前圈失效**，Esc 暂停。手柄 RT/LT 油门/制动，左摇杆转向，Start 暂停。

## 文件入口

`godot/scenes/Main.tscn` 是总入口；`FrontEnd.tscn` 主界面/车库 UI；`RaceInterface.tscn` 比赛设置/HUD；`Showroom.tscn` 车库；`Weather.tscn` 天气；`scenes/circuits/*.tscn` 九张已搭建赛道。赛道运行时直接加载保存的节点与网格，不现场生成地形、道路和建筑。

Blender 源文件在 `art/source_blender/`，引擎实拍在 `art/previews/`，建模/数据工具在 `tools/`，旧资产已移到本地 `.local-backups/`。

[场景编辑说明](godot/scenes/README.md) · [美术依据](art/README.md) · [自检记录](art/VALIDATION.md) · [素材授权](godot/THIRD_PARTY_NOTICES.md)

## 准确性与实际范围

真实中心线和地图地物投影为米制；高程来自 SRTM30m。道路宽度、缺少高度的建筑、外立面和部分安全设施仍是近似，**目前不是完整测绘级一比一复刻**。车为原创设计。当前提供单人计时赛，没有 AI 对手、联网、改装、动态昼夜或专业轮胎仿真；天气/光照为四种可选预设。

## 构建和验证

Windows / Godot 4.7.2 / Forward+ / Jolt；Blender 4.5。

```powershell
./tools/build-cars.ps1
python ./tools/build-audio.py
./tools/test-godot.ps1 -GodotPath '<Godot exe>'
./tools/test-scene-laps.ps1 -CarKeys v8,r6,v6
```

专项脚本位于 godot/tests/。test_render.gd、capture_overhaul.gd、capture_circuits.gd、capture_gt.gd 需要图形渲染。赛道离线重建会覆盖手工编辑，先阅读场景说明。
