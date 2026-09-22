# 原生场景编辑

1. 在 Godot 打开 Main.tscn；F5 启动主界面。
2. FrontEnd.tscn 编辑首页/车库/设置；RaceInterface.tscn 编辑选赛道和 HUD；Showroom.tscn 编辑 3D 展厅；Weather.tscn 编辑环境和灯光。
3. circuits/ 下九个 tscn 是已保存的赛道节点。选择网格、建筑、碰撞体直接修改位置/材质。geometry/ 存放外部网格资源，须随场景保留。
4. 天气和赛道运行脚本负责交互、计时采样与材质参数，不负责运行时搭建赛道几何。

## 离线重建（会覆盖场景编辑）

只有需要重建地图来源时才使用：Python tools/build-circuit-data.py 更新数据，然后 Godot --path godot --script res://tools/save_circuit_scenes.gd。备份手动修改后再运行！必须使用真实图形渲染器，不能加 --headless；MultiMesh 实例数据需要 GPU 同步后保存。

CircuitBuilder 和 venue_scenery.gd 仅用于离线制作；最终 tscn 的根脚本是 track_world.gd。日常编辑无需重新执行生成工具。
