# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2025-09-07

### 亮点（特色）
- 沿挂模式：贴右侧边缘、可拖拽、释放后自由落体（可配置重力/弹力）。
- 太空模式：无重力弹跳、支持多窗口相互碰撞与分裂（双击）。
- 多屏支持：可在“内置/扩展”屏幕范围内运行并自动夹取到可见区域。
- 可调帧率：30/48/50/60/120 FPS，随改随生效。
- 菜单栏控制：可见性切换、重置位置、偏好设置、关于/退出。

### 修复（稳定性）
- 修复在切换“可见/不可见”时的崩溃：
  - 改为“隐藏不销毁”（orderOut/orderFront），避免关闭窗口后异步回调继续访问窗口。
  - 菜单点击仅修改期望状态，菜单关闭后统一应用，彻底规避 NSMenu 跟踪期间的 UI 重入。
  - Space 物理更新使用窗口快照，避免帧内数组被修改导致越界或对已关闭对象写入。
  - Edge 窗口关闭前停止计时器并解除监听，避免关闭后 setFrame。
- 修复初始贴边与随机 Y 在异常屏幕布局下可能使用 NaN/Infinite 导致的崩溃。

### 优化（性能）
- 活动状态感知：App 退到后台自动暂停物理计时器，回到前台再恢复。
- 仅在“太空 miku 可见”且有窗口时运行全局物理计时器。
- 边界吸附与运动采用安全夹取，避免频繁回弹造成多余计算。

### 改进（体验）
- “关于”对话框使用 Info.plist 的版本号动态展示。
- 重置与吸附的动画更平滑，并在边界极端条件下保持稳定。

### 代码结构
- AppDelegate：
  - 引入 NSMenuDelegate，在 menuDidClose 中统一应用可见性。
  - 使用 desiredEdgeVisible/desiredSpaceVisible 与 isEdgeVisible/isSpaceVisible 做幂等状态机。
  - tickPhysics() 使用 spaceWindows 快照，隐藏时严格先停表后隐藏。
- MikuWindow：
  - 新增 stopAllActivities()；重写 close() 在关闭前停止计时器/移除观察者。
- AppSettings：
  - 提供边界/物理参数通知，支持帧率与屏幕范围选择。

### 升级指南
- 无破坏性改动；若有脚本读取版本，请同步读取 Info.plist 的 CFBundleShortVersionString（现为 1.1.0）。

---

## [1.0.0] - 2025-08-31
- 初始发布：沿挂与太空两种模式、基础拖拽/重力/弹跳、多屏与帧率设置、菜单栏控制等。

[1.1.0]: https://github.com/ink1ing/mikucat/releases/tag/v1.1.0
