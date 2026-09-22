# Apex Circuit — GT Experience

直接用 Godot 打开 `project.godot` 并按 F5，或双击 `启动游戏.cmd`。

## 当前可玩内容

- 蒙扎、斯帕、银石三个真实地理布局的米制场景，地形、维修区、看台、森林与安全设施。
- V8 Endurance、R6 Heritage、V6 Apex 三款原创低多边形 GT，独立比例、驾驶参数和发动机音色。
- 真实车内视角、转动方向盘、动态仪表、实时后视镜，以及近/远追车视角。
- 1/3/5 圈单人计时赛：倒计时、24 个顺序检查点、三段计时、结算、分车型最佳成绩、暂停/重开。
- 键盘与手柄、音量/全屏/减少晃动设置，自动变速、辅助抓地，轮胎/路肩/碰撞/换挡声音反馈。

操作：W/S 加速与刹车倒车，A/D 转向，空格手刹，C 切换视角，R 复位，Esc 暂停。手柄 RT/LT 为油门/刹车，左摇杆转向，Start 暂停。出界或复位会使当前圈无法计入最佳成绩。

## 工程入口

正式游戏在 `godot/`；Blender 源文件在 `art/source_blender/`；实拍在 `art/previews/`；建模与验证脚本在 `tools/`。早期网页原型保留供历史参考，见 `README-web-prototype.md`。

[美术与比例依据](../art/README.md) · [自检记录](../art/VALIDATION.md) · [第三方数据声明](THIRD_PARTY_NOTICES.md)

## 实际范围

本版是完整的单人计时赛循环。没有 AI 对手、联网、改装、天气系统或专业轮胎仿真。驾驶偏易上手；画面采用原创低多边形风格。场景由真实经纬度和地形数据构建，但道路宽度、部分建筑高度、护栏及局部设施仍为近似；三车是原创设计，不能称为 ACC 等价产品或测绘级一比一复刻。

## 重建与验证

验证环境：Windows、Godot 4.7.2、Forward+、Jolt、RTX 4070。美术生成：Blender 4.5。

```powershell
./tools/build-art.ps1
./tools/test-godot.ps1 -GodotPath '<Godot exe>' -AllTracks -AllCars
```

其他专项测试：Godot 使用 `--headless --path godot --script res://tests/test_input.gd -- --test-mode` 或 `test_audio.gd`。`test_render.gd` 与 `capture_gt.gd` 需要图形渲染，不加 `--headless`。

命令示例从仓库根目录运行。游戏存档位于 Godot user://，成绩按 gt_v2/赛道/车辆隔离。
