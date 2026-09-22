# 美术文件入口

当前内容：蒙扎、斯帕、银石三个米制场景，三款原创 GT 赛车，驾驶舱与实时后视镜。视频仅参考低多边形轮廓、色彩和柔和光照；地点使用真实赛道地理资料重建。

## 文件分类

- `source_blender/`：三款 `VEH_*.blend` 和 `ENV_Circuit_Stylized_Library.blend`，可直接在 Blender 编辑。
- `../godot/assets/cars/`：三款正式 GLB 与米制尺寸 JSON；`environment/circuit_kit/`：18 个环境模块。
- `previews/`：`VEH_`、`ENV_` 为 Blender 预览，`GODOT_地点_镜头` 为引擎实拍，`audio/` 为运行时 DSP 导出的声音试听。
- `reference_data/`：中心线、SRTM 高程和地图下载缓存；运行时数据在 `../godot/assets/circuits/real_circuits.json`。
- `../tools/blender/`：可重复生成模型的脚本；`build_logs/`：本地日志；被替换的首版资产在项目 `.local-backups/retired-art/`，不进入 Git。

## 尺寸与准确性

Blender 和 Godot 均采用 1 单位 = 1 米。GLB 从 Z-up 转换为 Y-up，车辆向 +Z 行驶，运行时不再统一缩放到 4.4 米。三个车身的长/宽/高目标分别为：V8 4.746/2.049/1.238m，R6 4.619/2.050/1.300m，V6 4.565/2.050/1.250m。这些是原创车型的设计尺寸，不是三辆品牌赛车的精确复制。

中心线来自 [bacinger/f1-circuits](https://github.com/bacinger/f1-circuits)，经纬度直接投影为米，不强行拉伸到宣传圈长。建筑、维修区和林地轮廓来自 [OpenStreetMap](https://www.openstreetmap.org/copyright)。高程来自 [OpenTopoData SRTM30m](https://www.opentopodata.org/datasets/srtm/)。银石起点使用 Hamilton Straight 的 OSM 标记。

已知近似：道路统一宽度为蒙扎12m、斯帕14m、银石15m；高程是30米地形采样，不是赛道路面测绘；未标高度的建筑使用估算；外立面、护栏距离、刹车牌和植被为风格化布置。不能称为激光扫描级、毫米级或全部设施逐件一比一还原。

车辆比例参考：[Porsche 992 GT3 R 官方资料](https://newsroom.porsche.com/en_US/2022/motorsport/porsche-911-gt3-r-generation-992-customer-racing-car-premiere-29222.html)、Mercedes-AMG GT3/GT4 官方手册、[SRO Ferrari 296 GT3 发布资料](https://www.gt-world-challenge-europe.com/news/2378/ferrari-296-gt3-a-v6-for-a-new-sporting-history)。R6 高度、V8 轴距、V6 长度与高度采用设计目标；其他已核对尺寸也不表示外形获得厂商认证。

美术参考：[用户视频](https://www.bilibili.com/video/BV1UrYy6ZEu4/)。没有复制视频、ACC 或 DREDGE 的模型、贴图和声音。

## 重建

运行 `tools/build-art.ps1` 生成环境和三车（Blender 4.5，factory-startup，不修改用户插件配置）。重新获取地图数据用 `tools/fetch-venue-features.ps1`，高程用 `fetch-circuit-elevation.ps1` 和 `fetch-terrain.ps1`；最后 Python 3 + numpy 运行 `tools/build-circuit-data.py`。联网脚本需要 PowerShell 7。历史地图会更新，重下载结果不保证与当前缓存相同。

引擎截图：Godot `--path godot --script res://tests/capture_gt.gd -- --test-mode`。详见 [自检记录](VALIDATION.md)。
