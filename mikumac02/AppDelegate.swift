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
    
    // 菜单项引用，便于更新勾选状态
    var showEdgeItem: NSMenuItem?
    var showSpaceItem: NSMenuItem?
    var frameRateMenuItems: [NSMenuItem] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("应用程序启动完成...")
        
        // 设置应用程序策略（不在Dock中显示，但显示菜单栏图标）
        NSApp.setActivationPolicy(.accessory)
        
        // 创建状态栏图标
        setupStatusBar()
        
        // 监听太空miku分裂请求
        NotificationCenter.default.addObserver(self, selector: #selector(handleSpaceSpawnRequested(_:)), name: SpaceMikuWindow.spawnRequestedNotification, object: nil)
        
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
        
        // 重置
        let resetEdge = NSMenuItem(title: "重置 沿挂miku猫 位置", action: #selector(resetEdge(_:)), keyEquivalent: "")
        resetEdge.target = self
        menu.addItem(resetEdge)
        let resetSpace = NSMenuItem(title: "重置 太空miku猫", action: #selector(resetSpace(_:)), keyEquivalent: "")
        resetSpace.target = self
        menu.addItem(resetSpace)
        
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
        // 确保显示后再移动到目标屏右侧
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
    }
    
    private func hideSpaceWindow() {
        for w in spaceWindows { w.close() }
        spaceWindows.removeAll()
        showSpaceItem?.state = .off
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
        spaceWindows.append(w)
        showSpaceItem?.state = .on
    }
    
    @objc private func handleSpaceSpawnRequested(_ note: Notification) {
        // 仅在太空模式可见时允许分裂
        if showSpaceItem?.state == .on { spawnSpaceWindow() }
    }
    
    // NSWindowDelegate: 窗口关闭时清理数组，避免泄漏
    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? SpaceMikuWindow else { return }
        if let idx = spaceWindows.firstIndex(where: { $0 === w }) {
            spaceWindows.remove(at: idx)
        }
        if spaceWindows.isEmpty { showSpaceItem?.state = .off }
    }
    
    @objc private func selectFrameRate(_ sender: NSMenuItem) {
        let newRate = Double(sender.tag)
        AppSettings.shared.frameRate = newRate
        // update checkmarks
        for item in frameRateMenuItems {
            item.state = (item == sender) ? .on : .off
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
    
    @objc private func quitApplication(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
}
