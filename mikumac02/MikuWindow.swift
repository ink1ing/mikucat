//
//  MikuWindow.swift
//  mikumac02
//
//  Created by INKLING on 8/31/25.
//

import Cocoa

enum MikuState {
    case idle          // 待机状态 - miku2.png
    case dragging      // 拖拽中 - miku1.png
    case falling       // 自由落体中 - miku1.png
    case landed        // 落地静止 - miku3.png
}

class MikuWindow: NSWindow {
    private var mikuImageView: NSImageView!
    private var currentState: MikuState = .idle
    private var isDragging = false
    private var dragOffset: NSPoint = NSPoint.zero
    private var fallAnimationTimer: Timer?
    private var fallVelocity: CGFloat = 0
    private let gravity: CGFloat = 500 // 重力加速度
    private static let rightEdgeShiftForPng2: CGFloat = 12 // png2 靠右时向右偏移
    
    // Miku图片资源
    private var miku1Image: NSImage?
    private var miku2Image: NSImage?
    private var miku3Image: NSImage?
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
    }
    
    convenience init() {
        // 先用一个安全默认位置创建窗口，随后再根据屏幕调整到右侧
        self.init(contentRect: NSRect(x: 100, y: 100, width: 150, height: 200),
                  styleMask: [.borderless],
                  backing: .buffered,
                  defer: false)
        DispatchQueue.main.async { [weak self] in
            self?.moveToRightEdgeWithRandomY()
        }
    }

    // 根据当前屏幕布局，将窗口移动到“目标屏”的右侧边缘，Y 随机
    private func moveToRightEdgeWithRandomY() {
        guard let targetScreen = NSScreen.screens.max(by: { a, b in
            a.visibleFrame.maxX < b.visibleFrame.maxX
        }) else { return }
        let frame = targetScreen.visibleFrame
        // 额外健壮性保护
        guard frame.width.isFinite, frame.height.isFinite else { return }
        let desiredSize = CGSize(width: 150, height: 200)
        let usedWidth = min(desiredSize.width, max(10, frame.width))
        let usedHeight = min(desiredSize.height, max(10, frame.height))
        let size = CGSize(width: usedWidth, height: usedHeight)
        
        // 夹在 [minX, maxX - width]
        let targetXRaw = frame.maxX - size.width + Self.rightEdgeShiftForPng2
        let x = min(max(frame.minX, targetXRaw), frame.maxX - size.width)
        
        let minY = frame.minY
        let maxYCandidate = frame.maxY - size.height
        let upper = max(minY, maxYCandidate)
        let y: CGFloat
        if upper.isFinite, minY.isFinite, upper >= minY {
            y = CGFloat.random(in: minY...upper)
        } else {
            y = minY
        }
        
        let newFrame = NSRect(x: x, y: y, width: size.width, height: size.height)
        print("屏幕可见区域: \(frame), 初始窗口位置: \(newFrame)")
        self.setFrame(newFrame, display: true)
    }
    
    private func setupWindow() {
        print("开始设置窗口...")
        
        // 窗口属性设置
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        self.level = NSWindow.Level.floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = false
        
        
        // 加载图片资源
        loadMikuImages()
        
        // 创建图片视图
        setupImageView()
        
        // 设置初始状态
        setState(.idle)
        
        // 添加鼠标事件监听
        setupMouseTracking()
        
        print("窗口设置完成，当前frame: \(self.frame)")

        // 监听全局帧率变化
        NotificationCenter.default.addObserver(self, selector: #selector(handleFrameRateChanged), name: AppSettings.frameRateChangedNotification, object: nil)
    }
    
    // 重写这些方法来修复焦点问题
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    private func loadMikuImages() {
        print("开始加载图片...")
        
        // 优先尝试从Bundle中加载图片
        miku1Image = NSImage(named: "miku1")
        miku2Image = NSImage(named: "miku2") 
        miku3Image = NSImage(named: "miku3")
        
        print("Bundle图片加载结果: miku1=\(miku1Image != nil), miku2=\(miku2Image != nil), miku3=\(miku3Image != nil)")
        
        // 如果Bundle中没有，尝试从项目目录加载
        if miku1Image == nil {
            miku1Image = NSImage(contentsOfFile: "/Users/inkling/Desktop/mikumac/mikumac02/mikumac02/miku1.png")
            miku2Image = NSImage(contentsOfFile: "/Users/inkling/Desktop/mikumac/mikumac02/mikumac02/miku2.png")
            miku3Image = NSImage(contentsOfFile: "/Users/inkling/Desktop/mikumac/mikumac02/mikumac02/miku3.png")
            
            print("文件路径图片加载结果: miku1=\(miku1Image != nil), miku2=\(miku2Image != nil), miku3=\(miku3Image != nil)")
        }
        
        // 确保图片加载成功，如果没有就创建测试图片
        if miku1Image == nil || miku2Image == nil || miku3Image == nil {
            print("警告: 无法加载Miku图片资源，使用测试图片")
            // 创建简单的彩色测试图片
            miku2Image = NSImage(size: NSSize(width: 100, height: 100))
            miku2Image?.lockFocus()
            NSColor.red.set()
            NSRect(x: 0, y: 0, width: 100, height: 100).fill()
            miku2Image?.unlockFocus()
            
            miku3Image = NSImage(size: NSSize(width: 100, height: 100))
            miku3Image?.lockFocus()
            NSColor.blue.set()
            NSRect(x: 0, y: 0, width: 100, height: 100).fill()
            miku3Image?.unlockFocus()
        }
    }
    
    private func setupImageView() {
        print("设置图片视图...")
        mikuImageView = NSImageView(frame: self.contentView!.bounds)
        mikuImageView.imageScaling = .scaleProportionallyUpOrDown
        mikuImageView.imageAlignment = .alignCenter
        mikuImageView.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(mikuImageView)
        print("图片视图frame: \(mikuImageView.frame)")
    }
    
    private func setupMouseTracking() {
        let trackingArea = NSTrackingArea(
            rect: self.contentView!.bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        self.contentView?.addTrackingArea(trackingArea)
    }
    
    private func setState(_ newState: MikuState) {
        print("状态切换: \(currentState) -> \(newState)")
        currentState = newState
        
        switch newState {
        case .idle:
            mikuImageView.image = miku2Image
            print("设置为待机图片(miku2)，图片是否存在: \(miku2Image != nil)")
            stopFallAnimation()
            applyRightEdgeShiftIfNeeded()
        case .dragging:
            mikuImageView.image = miku1Image
            print("设置为拖拽图片(miku1)，图片是否存在: \(miku1Image != nil)")
            stopFallAnimation()
        case .falling:
            mikuImageView.image = miku1Image
            print("设置为下落图片(miku1)，图片是否存在: \(miku1Image != nil)")
            startFallAnimation()
        case .landed:
            mikuImageView.image = miku3Image
            print("设置为落地图片，图片是否存在: \(miku3Image != nil)")
            stopFallAnimation()
        }
    }

    // 如果当前靠近屏幕右侧，则对 png2（idle）应用额外右移，以便更贴合
    private func applyRightEdgeShiftIfNeeded() {
        guard let screen = self.screen ?? NSScreen.screens.first(where: { $0.visibleFrame.intersects(self.frame) }) ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        var win = self.frame
        // 判断是否在右侧边缘附近（允许一定误差）
        let distanceToRight = abs(win.maxX - frame.maxX)
        if distanceToRight <= 24 { // 24像素阈值
            var targetX = frame.maxX - win.width + Self.rightEdgeShiftForPng2
            // 再次夹取，避免超出屏幕
            targetX = min(max(frame.minX, targetX), frame.maxX - win.width)
            if abs(win.origin.x - targetX) > 0.5 {
                win.origin.x = targetX
                self.setFrame(win, display: true)
                print("已对png2状态应用右移偏移: \(Self.rightEdgeShiftForPng2)px, 新位置: \(win)")
            }
        }
    }
    
    private func startFallAnimation() {
        fallVelocity = 0
        fallAnimationTimer = Timer.scheduledTimer(withTimeInterval: AppSettings.shared.frameInterval, repeats: true) { [weak self] _ in
            self?.updateFallAnimation()
        }
    }
    
    private func stopFallAnimation() {
        fallAnimationTimer?.invalidate()
        fallAnimationTimer = nil
    }
    
    private func updateFallAnimation() {
        let currentScreen = self.screen ?? NSScreen.screens.first(where: { $0.visibleFrame.intersects(self.frame) }) ?? NSScreen.main
        guard let screen = currentScreen else { return }
        // 使用visibleFrame确保考虑菜单栏和Dock
        let screenFrame = screen.visibleFrame
        
        let deltaTime: CGFloat = CGFloat(1.0 / AppSettings.shared.frameRate)
        fallVelocity += gravity * deltaTime
        
        var newFrame = self.frame
        newFrame.origin.y -= fallVelocity * deltaTime
        
        // 检查是否碰撞到屏幕底部（使用visibleFrame的底部）
        if newFrame.origin.y <= screenFrame.minY {
            newFrame.origin.y = screenFrame.minY
            self.setFrame(newFrame, display: true)
            print("Miku碰撞地面，切换到落地状态")
            setState(.landed)
            return
        }
        
        self.setFrame(newFrame, display: true)
    }

    @objc private func handleFrameRateChanged() {
        if currentState == .falling {
            stopFallAnimation()
            startFallAnimation()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 鼠标事件处理
    override func mouseDown(with event: NSEvent) {
        // 双击落地状态（png3）时重置位置
        if event.clickCount == 2 && currentState == .landed {
            isDragging = false
            resetToInitialPosition()
            return
        }
        if currentState == .landed { return } // 落地后不能拖拽（除双击重置）
        
        isDragging = true
        let locationInWindow = event.locationInWindow
        dragOffset = NSPoint(x: locationInWindow.x, y: locationInWindow.y)
        // 点击时切换到 miku1（按下时显示），不立即进入拖拽状态
        stopFallAnimation()
        mikuImageView.image = miku1Image
        print("点击切换为miku1")
    }
    
    override func mouseDragged(with event: NSEvent) {
        if !isDragging { return }
        
        // 拖动开始时切换到拖拽状态（miku2）
        if currentState != .dragging {
            setState(.dragging)
        }
        
        let screenPoint = NSEvent.mouseLocation
        var newFrame = self.frame
        newFrame.origin.x = screenPoint.x - dragOffset.x
        newFrame.origin.y = screenPoint.y - dragOffset.y
        
        // 约束在可见屏幕范围内，便于“贴边”
        if let screen = self.screen ?? NSScreen.screens.first(where: { $0.visibleFrame.intersects(self.frame) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            newFrame.origin.x = min(max(frame.minX, newFrame.origin.x), frame.maxX - newFrame.size.width)
            newFrame.origin.y = min(max(frame.minY, newFrame.origin.y), frame.maxY - newFrame.size.height)
        }
        
        self.setFrame(newFrame, display: true)
    }
    
    override func mouseUp(with event: NSEvent) {
        if !isDragging { return }
        
        isDragging = false
        
        // 开始自由落体
        print("松开鼠标，开始自由落体")
        setState(.falling)
    }
    
    // MARK: - 公共方法
    func resetToInitialPosition() {
        // 停止所有动画
        stopFallAnimation()
        isDragging = false
        
        // 重新使用初始化时的位置计算逻辑
        guard let mainScreen = NSScreen.main else { return }
        
        let screenFrame = mainScreen.visibleFrame
        let desiredSize = CGSize(width: 150, height: 200)
        let usedWidth = min(desiredSize.width, max(10, screenFrame.width))
        let usedHeight = min(desiredSize.height, max(10, screenFrame.height))
        let imageSize = CGSize(width: usedWidth, height: usedHeight)
        
        let initialTargetX = screenFrame.maxX - imageSize.width + Self.rightEdgeShiftForPng2
        let initialX = min(initialTargetX, screenFrame.maxX - imageSize.width)
        
        let minY = screenFrame.minY
        let maxYCandidate = screenFrame.maxY - imageSize.height
        let maxY = max(minY, maxYCandidate)
        let randomY = CGFloat.random(in: minY...maxY)
        
        let newFrame = NSRect(x: initialX,
                              y: randomY,
                              width: imageSize.width,
                              height: imageSize.height)
        
        self.setFrame(newFrame, display: true, animate: true)
        setState(.idle)
        
        print("Miku位置已重置到: \(newFrame)")
    }
}
