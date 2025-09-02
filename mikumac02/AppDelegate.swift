//
//  AppDelegate.swift
//  mikumac02
//
//  Created by INKLING on 8/31/25.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    // 沿挂 miku 猫（重力/贴边）
    var mikuWindow: MikuWindow?
    // 太空 miku 猫（弹跳）—— 支持多窗口
    var spaceWindows: [SpaceMikuWindow] = []
    
    var statusItem: NSStatusItem?
    // 全局物理计时器（统一驱动太空 miku）
    var physicsTimer: Timer?
    
    // 菜单项引用，便于更新勾选状态
    var showEdgeItem: NSMenuItem?
    var showSpaceItem: NSMenuItem?
    var frameRateMenuItems: [NSMenuItem] = []
    var edgeScopeMenuItems: [NSMenuItem] = []
    var spaceScopeMenuItems: [NSMenuItem] = []
    var prefsWindowController: PreferencesWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("应用程序启动完成...")
        
        // 设置应用程序策略（不在Dock中显示，但显示菜单栏图标）
        NSApp.setActivationPolicy(.accessory)
        
        // 创建状态栏图标
        setupStatusBar()
        
        // 监听太空miku分裂请求
        NotificationCenter.default.addObserver(self, selector: #selector(handleSpaceSpawnRequested(_:)), name: SpaceMikuWindow.spawnRequestedNotification, object: nil)
        // 帧率变化时重启物理计时器
        NotificationCenter.default.addObserver(self, selector: #selector(handleFrameRateChanged), name: AppSettings.frameRateChangedNotification, object: nil)
        
        // 默认显示：沿挂miku猫 可见；太空miku猫默认隐藏
        showEdgeWindow()
        
        print("应用程序初始化完成")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hideEdgeWindow()
        hideSpaceWindow()
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // 不要在窗口关闭时退出应用
    }
    
    // MARK: - 状态栏设置
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Miku桌宠")
            button.image?.size = NSSize(width: 16, height: 16)
        }
        
        // 创建菜单
        let menu = NSMenu()
        
        // 可见性勾选：沿挂 miku 猫
        let edgeItem = NSMenuItem(title: "沿挂miku猫 可见", action: #selector(toggleEdgeVisible(_:)), keyEquivalent: "")
        edgeItem.target = self
        edgeItem.state = .off
        self.showEdgeItem = edgeItem
        menu.addItem(edgeItem)
        
        // 可见性勾选：太空 miku 猫
        let spaceItem = NSMenuItem(title: "太空miku猫 可见", action: #selector(toggleSpaceVisible(_:)), keyEquivalent: "")
        spaceItem.target = self
        spaceItem.state = .off
        self.showSpaceItem = spaceItem
        menu.addItem(spaceItem)
        
        // 帧率子菜单
        let rateRoot = NSMenuItem(title: "运动帧率", action: nil, keyEquivalent: "")
        let rateMenu = NSMenu()
        let rates: [Int] = [30, 48, 50, 60, 120]
        for r in rates {
            let item = NSMenuItem(title: "\(r) FPS", action: #selector(selectFrameRate(_:)), keyEquivalent: "")
            item.target = self
            item.tag = r
            if Int(AppSettings.shared.frameRate) == r { item.state = .on }
            rateMenu.addItem(item)
            frameRateMenuItems.append(item)
        }
        rateRoot.submenu = rateMenu
        menu.addItem(rateRoot)
        
        // 屏幕范围：沿挂 miku 猫
        let edgeScopeRoot = NSMenuItem(title: "沿挂屏幕", action: nil, keyEquivalent: "")
        let edgeScopeMenu = NSMenu()
        let edgeScopes: [(String, AppSettings.ScreenScope)] = [("内置屏幕", .builtin), ("扩展屏幕", .external)]
        for (title, scope) in edgeScopes {
            let item = NSMenuItem(title: title, action: #selector(selectEdgeScope(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scope.rawValue
            if AppSettings.shared.edgeScreenScope == scope { item.state = .on }
            edgeScopeMenu.addItem(item)
            edgeScopeMenuItems.append(item)
        }
        edgeScopeRoot.submenu = edgeScopeMenu
        menu.addItem(edgeScopeRoot)

        // 屏幕范围：太空 miku 猫
        let spaceScopeRoot = NSMenuItem(title: "太空屏幕", action: nil, keyEquivalent: "")
        let spaceScopeMenu = NSMenu()
        let spaceScopes: [(String, AppSettings.ScreenScope)] = [("内置屏幕", .builtin), ("扩展屏幕", .external)]
        for (title, scope) in spaceScopes {
            let item = NSMenuItem(title: title, action: #selector(selectSpaceScope(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scope.rawValue
            if AppSettings.shared.spaceScreenScope == scope { item.state = .on }
            spaceScopeMenu.addItem(item)
            spaceScopeMenuItems.append(item)
        }
        spaceScopeRoot.submenu = spaceScopeMenu
        menu.addItem(spaceScopeRoot)

        // 重置
        let resetEdge = NSMenuItem(title: "重置 沿挂miku猫 位置", action: #selector(resetEdge(_:)), keyEquivalent: "")
        resetEdge.target = self
        menu.addItem(resetEdge)
        let resetSpace = NSMenuItem(title: "重置 太空miku猫", action: #selector(resetSpace(_:)), keyEquivalent: "")
        resetSpace.target = self
        menu.addItem(resetSpace)
        
        // 偏好设置
        let prefsItem = NSMenuItem(title: "偏好设置…", action: #selector(openPreferences(_:)), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 关于菜单项
        let aboutItem = NSMenuItem(title: "关于Miku桌宠", action: #selector(showAbout(_:)), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出菜单项
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApplication(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - 桌宠控制
    private func showEdgeWindow() {
        guard mikuWindow == nil else { return }
        mikuWindow = MikuWindow()
        mikuWindow?.makeKeyAndOrderFront(nil)
        mikuWindow?.orderFrontRegardless()
        // 首次显示后，自动贴到用户选择的“沿挂屏幕”右侧
        DispatchQueue.main.async { [weak self] in
            self?.mikuWindow?.moveToRightEdgeWithRandomY()
        }
        showEdgeItem?.state = .on
    }
    
    private func hideEdgeWindow() {
        mikuWindow?.close()
        mikuWindow = nil
        showEdgeItem?.state = .off
    }
    
    private func showSpaceWindow() {
        // 如果已存在至少一个窗口，则不重复创建
        if spaceWindows.isEmpty {
            spawnSpaceWindow()
        }
        showSpaceItem?.state = .on
        startPhysicsTimerIfNeeded()
    }
    
    private func hideSpaceWindow() {
        for w in spaceWindows { w.close() }
        spaceWindows.removeAll()
        showSpaceItem?.state = .off
        stopPhysicsTimerIfIdle()
    }
    
    // MARK: - 菜单动作
    @objc private func toggleEdgeVisible(_ sender: NSMenuItem) {
        if mikuWindow == nil { showEdgeWindow() } else { hideEdgeWindow() }
    }
    
    @objc private func toggleSpaceVisible(_ sender: NSMenuItem) {
        if spaceWindows.isEmpty { showSpaceWindow() } else { hideSpaceWindow() }
    }
    
    @objc private func resetEdge(_ sender: NSMenuItem) {
        guard let window = mikuWindow else { return }
        window.resetToInitialPosition()
    }
    
    @objc private func resetSpace(_ sender: NSMenuItem) {
        if spaceWindows.isEmpty { return }
        for w in spaceWindows { w.reset() }
    }

    // MARK: - Space miku helpers
    private func spawnSpaceWindow() {
        let w = SpaceMikuWindow()
        w.delegate = self
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
        // 确保初始位置在所选空间范围内
        let b = spaceBounds()
        var c = CGPoint(x: w.frame.midX, y: w.frame.midY)
        let r = min(w.frame.width, w.frame.height) * 0.5
        c.x = min(max(b.minX + r, c.x), b.maxX - r)
        c.y = min(max(b.minY + r, c.y), b.maxY - r)
        w.centerPoint = c
        spaceWindows.append(w)
        showSpaceItem?.state = .on
        startPhysicsTimerIfNeeded()
    }

    private func spawnSpaceWindow(oppositeFrom source: SpaceMikuWindow) {
        // 基于源窗口位置和速度，生成一个反向运动的新窗口
        let srcCenter = CGPoint(x: source.frame.midX, y: source.frame.midY)
        var v = source.velocity
        // 若速度过小则随机化，防止停在边缘只沿一条边移动
        let minSpeed: CGFloat = 120
        let speed = max(minSpeed, hypot(v.x, v.y))
        if speed < 1 { // 极端情况
            let angles: [CGFloat] = [0, CGFloat.pi/4, CGFloat.pi/2, 3 * CGFloat.pi / 4, CGFloat.pi, -CGFloat.pi/2]
            let a = angles.randomElement() ?? (CGFloat.pi/3)
            v = CGPoint(x: cos(a) * minSpeed, y: sin(a) * minSpeed)
        }
        // 反向速度，保留模长
        let inv = CGPoint(x: -v.x, y: -v.y)
        // 稍微偏移出生点，避免完全重叠
        let offsetScale: CGFloat = 1.1
        let r = min(source.frame.width, source.frame.height) * 0.5
        let offMag = r * offsetScale
        let len = max(1, hypot(inv.x, inv.y))
        let dir = CGPoint(x: inv.x/len, y: inv.y/len)
        let spawnCenter = CGPoint(x: srcCenter.x + dir.x * offMag, y: srcCenter.y + dir.y * offMag)

        let w = SpaceMikuWindow()
        w.delegate = self
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
        // 设置位置与速度，并夹取到屏幕内
        let b = spaceBounds()
        let sr = min(w.frame.width, w.frame.height) * 0.5
        var sc = spawnCenter
        sc.x = min(max(b.minX + sr, sc.x), b.maxX - sr)
        sc.y = min(max(b.minY + sr, sc.y), b.maxY - sr)
        w.place(atCenter: sc, velocity: CGPoint(x: dir.x * speed, y: dir.y * speed))
        spaceWindows.append(w)
        showSpaceItem?.state = .on
        startPhysicsTimerIfNeeded()
    }
    
    @objc private func handleSpaceSpawnRequested(_ note: Notification) {
        // 仅在太空模式可见时允许分裂
        guard showSpaceItem?.state == .on else { return }
        if let src = note.object as? SpaceMikuWindow {
            spawnSpaceWindow(oppositeFrom: src)
        } else {
            spawnSpaceWindow()
        }
    }
    
    // NSWindowDelegate: 窗口关闭时清理数组，避免泄漏
    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? SpaceMikuWindow else { return }
        if let idx = spaceWindows.firstIndex(where: { $0 === w }) {
            spaceWindows.remove(at: idx)
        }
        if spaceWindows.isEmpty {
            showSpaceItem?.state = .off
            stopPhysicsTimerIfIdle()
        }
    }
    
    @objc private func selectFrameRate(_ sender: NSMenuItem) {
        let newRate = Double(sender.tag)
        AppSettings.shared.frameRate = newRate
        // update checkmarks
        for item in frameRateMenuItems {
            item.state = (item == sender) ? .on : .off
        }
    }

    @objc private func selectEdgeScope(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let scope = AppSettings.ScreenScope(rawValue: raw) else { return }
        AppSettings.shared.edgeScreenScope = scope
        // update checkmarks
        for item in edgeScopeMenuItems {
            let isSel = (item.representedObject as? String) == raw
            item.state = isSel ? .on : .off
        }
        // 约束沿挂窗口在新的边界内
        if let w = mikuWindow {
            let b = AppSettings.shared.edgeBounds()
            var f = w.frame
            f.origin.x = min(max(b.minX, f.origin.x), b.maxX - f.size.width)
            f.origin.y = min(max(b.minY, f.origin.y), b.maxY - f.size.height)
            w.setFrame(f, display: true)
        }
    }

    @objc private func selectSpaceScope(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let scope = AppSettings.ScreenScope(rawValue: raw) else { return }
        AppSettings.shared.spaceScreenScope = scope
        // update checkmarks
        for item in spaceScopeMenuItems {
            let isSel = (item.representedObject as? String) == raw
            item.state = isSel ? .on : .off
        }
        // 将所有太空 miku 立即夹取到新边界内
        let b = AppSettings.shared.spaceBounds()
        for w in spaceWindows {
            var c = w.centerPoint
            let r = w.bodyRadius
            c.x = min(max(b.minX + r, c.x), b.maxX - r)
            c.y = min(max(b.minY + r, c.y), b.maxY - r)
            w.centerPoint = c
        }
    }
    
    @objc private func showAbout(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Miku桌面宠物 v1.0"
        alert.informativeText = "一个可爱的Miku桌面宠物应用\n\n功能:\n• 拖拽互动\n• 重力模拟\n• 可爱动画\n\n使用方法:\n• 长按拖动Miku\n• 释放后观看重力效果\n• 使用菜单栏控制启停"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    @objc private func openPreferences(_ sender: NSMenuItem) {
        if prefsWindowController == nil { prefsWindowController = PreferencesWindowController() }
        prefsWindowController?.showWindow(nil)
        prefsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApplication(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    // MARK: - 全局物理更新（全屏+相互碰撞）
    private func startPhysicsTimerIfNeeded() {
        guard physicsTimer == nil, !spaceWindows.isEmpty else { return }
        physicsTimer = Timer.scheduledTimer(timeInterval: AppSettings.shared.frameInterval, target: self, selector: #selector(tickPhysics), userInfo: nil, repeats: true)
    }
    
    private func stopPhysicsTimerIfIdle() {
        if spaceWindows.isEmpty {
            physicsTimer?.invalidate()
            physicsTimer = nil
        }
    }
    
    @objc private func handleFrameRateChanged() {
        // 重启物理计时器以应用新的帧率
        physicsTimer?.invalidate()
        physicsTimer = nil
        startPhysicsTimerIfNeeded()
    }
    
    private func spaceBounds() -> CGRect {
        AppSettings.shared.spaceBounds()
    }
    
    @objc private func tickPhysics() {
        guard !spaceWindows.isEmpty else { return }
        let dt = CGFloat(1.0 / AppSettings.shared.frameRate)
        let bounds = spaceBounds()
        // 为避免沿边缘“走线”（垂直或水平分量接近 0 ），对速度分量设置一个最小阈值
        let minComponentSpeed: CGFloat = 80
        let e = AppSettings.shared.spaceRestitution
        let g = AppSettings.shared.spaceGravity

        // 读取状态
        let count = spaceWindows.count
        var centers = [CGPoint](repeating: .zero, count: count)
        var radii = [CGFloat](repeating: 0, count: count)
        var vels = [CGPoint](repeating: .zero, count: count)
        var paused = [Bool](repeating: false, count: count)
        var hitWall = [Bool](repeating: false, count: count)
        var hitOther = [Bool](repeating: false, count: count)
        for (i, w) in spaceWindows.enumerated() {
            centers[i] = w.centerPoint
            radii[i] = w.bodyRadius
            vels[i] = w.velocity
            paused[i] = w.isPaused
        }

        // 边界积分 + 反弹
        for i in 0..<count {
            if paused[i] { continue }
            var c = centers[i]
            var v = vels[i]
            let r = radii[i]
            // 重力：向下（减少 y 速度）
            if g != 0 { v.y -= g * dt }
            let eps: CGFloat = 1.0
            c.x += v.x * dt
            c.y += v.y * dt
            // 左右
            if c.x - r <= bounds.minX {
                c.x = bounds.minX + r + eps
                // 反弹 + 保证水平分量不至于过小
                let newMag = max(abs(v.x) * e, minComponentSpeed)
                v.x = newMag
                hitWall[i] = true
            } else if c.x + r >= bounds.maxX {
                c.x = bounds.maxX - r - eps
                let newMag = max(abs(v.x) * e, minComponentSpeed)
                v.x = -newMag
                hitWall[i] = true
            }
            // 上下
            if c.y - r <= bounds.minY {
                c.y = bounds.minY + r + eps
                let newMag = max(abs(v.y) * e, minComponentSpeed)
                v.y = newMag
                hitWall[i] = true
            } else if c.y + r >= bounds.maxY {
                c.y = bounds.maxY - r - eps
                let newMag = max(abs(v.y) * e, minComponentSpeed)
                v.y = -newMag
                hitWall[i] = true
            }
            centers[i] = c
            vels[i] = v
        }

        // 相互碰撞（弹性、等质量）
        for i in 0..<count {
            if paused[i] { continue }
            for j in (i+1)..<count {
                if paused[j] { continue }
                let dx = centers[j].x - centers[i].x
                let dy = centers[j].y - centers[i].y
                var dist = sqrt(dx*dx + dy*dy)
                let minDist = radii[i] + radii[j]
                if dist < minDist {
                    // 法向量
                    var nx: CGFloat = 1
                    var ny: CGFloat = 0
                    if dist > 0.0001 { nx = dx / dist; ny = dy / dist } else {
                        // 重合时随机一个方向
                        let angle = CGFloat.random(in: 0..<(2 * .pi))
                        nx = cos(angle); ny = sin(angle)
                        dist = minDist
                    }
                    // 位置校正：各退让一半
                    let overlap = minDist - dist
                    if overlap > 0 {
                        centers[i].x -= nx * overlap * 0.5
                        centers[i].y -= ny * overlap * 0.5
                        centers[j].x += nx * overlap * 0.5
                        centers[j].y += ny * overlap * 0.5
                    }
                    // 速度分解到法线与切线
                    let tx = -ny, ty = nx
                    let v1 = vels[i], v2 = vels[j]
                    let v1n = v1.x*nx + v1.y*ny
                    let v1t = v1.x*tx + v1.y*ty
                    let v2n = v2.x*nx + v2.y*ny
                    let v2t = v2.x*tx + v2.y*ty
                    // 等质量，系数 e 的碰撞：
                    // v1n' = (u1 + u2 - e*(u1 - u2))/2
                    // v2n' = (u1 + u2 + e*(u1 - u2))/2
                    let u1 = v1n, u2 = v2n
                    let v1n2 = (u1 + u2 - e*(u1 - u2)) * 0.5
                    let v2n2 = (u1 + u2 + e*(u1 - u2)) * 0.5
                    let nv1 = CGPoint(x: v1n2*nx + v1t*tx, y: v1n2*ny + v1t*ty)
                    let nv2 = CGPoint(x: v2n2*nx + v2t*tx, y: v2n2*ny + v2t*ty)
                    // 防止生成近零分量：维持每个轴的最小速度，方向不变
                    func clampComponent(_ v: CGPoint) -> CGPoint {
                        var out = v
                        if abs(out.x) < minComponentSpeed { out.x = (out.x >= 0 ? 1 : -1) * minComponentSpeed }
                        if abs(out.y) < minComponentSpeed { out.y = (out.y >= 0 ? 1 : -1) * minComponentSpeed }
                        return out
                    }
                    vels[i] = clampComponent(nv1)
                    vels[j] = clampComponent(nv2)
                    hitOther[i] = true
                    hitOther[j] = true
                }
            }
        }

        // 再进行一次边界校正，避免碰撞分离把物体推到边界之外
        for i in 0..<count {
            if paused[i] { continue }
            var c = centers[i]
            var v = vels[i]
            let r = radii[i]
            let eps: CGFloat = 1.0
            if c.x - r < bounds.minX { c.x = bounds.minX + r + eps; v.x = max(abs(v.x), minComponentSpeed) }
            if c.x + r > bounds.maxX { c.x = bounds.maxX - r - eps; v.x = -max(abs(v.x), minComponentSpeed) }
            if c.y - r < bounds.minY { c.y = bounds.minY + r + eps; v.y = max(abs(v.y), minComponentSpeed) }
            if c.y + r > bounds.maxY { c.y = bounds.maxY - r - eps; v.y = -max(abs(v.y), minComponentSpeed) }
            centers[i] = c
            vels[i] = v
        }

        // 回写
        for i in 0..<count {
            let w = spaceWindows[i]
            w.velocity = vels[i]
            if !paused[i] { w.centerPoint = centers[i] }
            if (hitWall[i] || hitOther[i]) {
                w.updateImageForImpact()
            }
        }
    }
}
