# Apex Circuit

当前主版本是 `godot/` 中的低多边形单人计时赛车。驾驶偏辅助街机，视觉采用简洁块面、灰绿远景和暖色光照。

## 开始游戏

1. 双击 `godot/启动游戏.cmd`，或用 Godot 打开 `godot/project.godot` 后按 F5。
2. 选择赛道和 1 / 3 / 5 圈，点击开始比赛。
3. 完成检查点后查看结算，继续挑战最佳圈。

W/S 加速与刹车、A/D 转向、空格手刹、C 视角、R 复位、Esc 暂停。详见 [Godot 工程说明](godot/README.md)。

## 当前内容

- 一辆 Kenney Clubsport 运动轿车，独立轮组动画、自动变速、惯性与辅助抓地。
- 九条原型路线、24 个顺序检查点、三段计时、有效圈纪录、比赛结算。
- 近/远追车和引擎盖视角、暂停/重开、失焦自动暂停、中文 HUD、小地图。
- 音量/全屏设置与每条路线个人最佳成绩的本地存档。
- 真实道路碰撞和连续路段投影；弯道内侧草地自动避开相邻道路。

本版完成单人计时赛循环。未包含 AI 对手、开放世界、联网、车辆改装或真实轮胎仿真。九条路线是原型中心线的简化版本，菜单显示实际生成长度，不声称真实赛道精度。

## 开发与验证

验证环境：Windows / Godot 4.7.2 / Compatibility 渲染 / Jolt Physics。

```powershell
.\tools\test-godot.ps1 -GodotPath '你的Godot.exe路径' -AllTracks
```

该命令执行功能回归与九条路线实际车辆自动跑圈，经过道路碰撞及检查点后进入结算，不通过传送模拟成功。测试模式不会覆盖个人纪录。日志与画面检查输出在 `godot/test-output/`，不提交 Git。

车型来源和许可见 [Godot 素材说明](godot/THIRD_PARTY_NOTICES.md)。美术方向参考 DREDGE，未使用其游戏素材。

## 历史内容

`src/`、`public/` 和网页构建文件保留为历史 Three.js 原型及原始素材。旧说明见 [README-web-prototype.md](README-web-prototype.md)。不要用旧网页说明判断当前 Godot 功能。

迁移前两个 Godot 版本及退出主版本的烘焙道路资源保存在本机 `.local-backups/`，不提交 Git。原来的 `godot-staging/ApexCircuit` 已整理为正式 `godot/` 目录。
