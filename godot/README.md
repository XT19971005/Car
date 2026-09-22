# 启动游戏

打开本目录 project.godot，按 F5。完整使用说明见 [仓库说明](../README.md)，场景编辑见 [场景说明](scenes/README.md)。

存档 user://driver.cfg，成绩按 static_v3_weather / 赛道 / 车辆 / 天气隔离。旧版本成绩保留在旧字段，不混入本版。

## 当前工程与操作

最新工程分支为 `codex/godot-complete-experience`，GitHub 默认的 `master` 尚未合并这批修改。下载时请切换到工程分支。

W/S 油门与制动倒车，A/D 转向，空格手刹，C/F1 切换视角，R 回到最近路面，Esc 暂停。默认自动挡，Q 强制降挡制动，无降挡超转保护，保挡两秒后恢复自动升挡。

更新文件后先 F8 停止旧游戏，再按 F5 重新运行。整体检查见 [自检记录](tests/自检记录.md)。
