# 美术文件入口

- source_blender/：三辆 VEH_*.blend 和环境模块源文件。
- ../godot/assets/cars/：VEH_V8_Muscle_GT、VEH_Rally_Hatch、VEH_Apex_Prototype 的 GLB 和尺寸 JSON。
- previews/：HOME/GARAGE/MENU 为界面实拍，CIRCUIT 为九图检查，WEATHER 为天气，GODOT 为驾驶舱与赛道；audio/ 为实际 DSP 导出试听。
- reference_data/：中心线和 SRTM 高程资料；运行时路线数据在 godot/assets/circuits/real_circuits.json。
- tools/blender/：可重复建模脚本；旧版本资产在本地 .local-backups/retired-overhaul-v2/。

## 比例与准确性

Blender 和 Godot 均 1 单位 = 1 米。三个原创设计的长/宽/高：V8 4.746/2.049/1.238m；Rally 4.10/1.86/1.48m；Prototype 4.85/2.04/1.08m。不是三辆品牌赛车的精确复制。

七张 F1 中心线来自 bacinger/f1-circuits（MIT），巴瑟斯特和拉古纳来自 OpenStreetMap；建筑、林地、水体、维修道路和护栏也使用 OSM 地理位置。SRTM30m 高程用于地形。没有为匹配宣传圈长任意拉伸地图。

已知近似：道路宽度采用各赛道名义宽度；30 米地形采样不能复原所有路面坡度；缺少高度的建筑估算，立面使用风格化模块。部分路肩、看台、刹车牌使用通用造型。因此不是激光扫描级、全部设施逐件一比一还原。

## 音频

engine_source.wav 来自 domasx2 的 CC0 赛车循环，engine_texture.wav 由 tools/build-audio.py 处理。运行时混合采样纹理、独立发动机脉冲、换挡/轮胎/碰撞/雨声，并根据驾驶舱视角滤波。三车音色不同，但不是三辆真实赛车独立录音。

授权与网址见 ../godot/THIRD_PARTY_NOTICES.md。没有分发 ACC、DREDGE 或用户参考视频中的素材。
