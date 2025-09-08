//
//  MikuWindow.swift
//  mikumac02
//
//  Created by INKLING on 8/31/25.
//

import Cocoa
import CoreGraphics

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
        // 首次显示后会自动吸附到选中屏幕的右侧
    }

    // 根据当前屏幕布局，将窗口移动到“目标屏”的右侧边缘，Y 随机
    func moveToRightEdgeWithRandomY() {
        // 在下一轮主队列再执行一次，确保屏幕信息已稳定
        let performMove: () -> Void = { [weak self] in
            guard let self = self else { return }
            // 使用用户选择的沿挂屏幕边界，避免与“扩展/内置屏幕”选择不一致
            var vf = AppSettings.shared.edgeBounds()
            // 防御：若宽高不是正数（包括 NaN 导致比较为 false）则退回主屏
            if !(vf.width > 0) || !(vf.height > 0) {
                if let main = NSScreen.main?.visibleFrame { vf = main }
                else { vf = CGRect(x: 0, y: 0, width: 800, height: 600) }
            }

            // 期望大小，并在屏幕极小或异常时进行夹取
            let desiredSize = CGSize(width: 150, height: 200)
            let safeW = (vf.width > 0) ? vf.width : desiredSize.width
            let safeH = (vf.height > 0) ? vf.height : desiredSize.height
            let usedWidth = min(desiredSize.width, max(CGFloat(10), safeW))
            let usedHeight = min(desiredSize.height, max(CGFloat(10), safeH))
            let size = CGSize(width: usedWidth, height: usedHeight)

            // X：贴右并允许补偿越界；像素对齐
            let xLower = vf.minX
            let xUpper = vf.maxX - size.width
            let scale = (self.backingScaleFactor > 0) ? self.backingScaleFactor : (NSScreen.main?.backingScaleFactor ?? 2.0)
            let compPt = AppSettings.shared.edgeRightCompensationPx / max(scale, 1)
            let upperWithComp = xUpper + compPt
            let pxMaxX = round(vf.maxX * scale)
            let pxW = round(size.width * scale)
            var targetXRaw = (pxMaxX - pxW) / scale + compPt
            let x: CGFloat
            if upperWithComp >= xLower {
                targetXRaw = min(max(xLower, targetXRaw), upperWithComp)
                x = targetXRaw
            } else {
                // 当屏幕宽度比窗口还小，退回到下限，避免产生非法范围
                x = xLower
            }

            // Y：在 [minY, maxY - height] 间随机，若无有效范围则取 minY
            let lowerY = vf.minY
            let upperCandidate = vf.maxY - size.height
            let upperY = max(lowerY, upperCandidate)
            let y: CGFloat = (upperY > lowerY) ? CGFloat.random(in: lowerY...upperY) : lowerY

            let newFrame = NSRect(x: x, y: y, width: size.width, height: size.height)
            print("屏幕可见区域: \(vf), 初始窗口位置: \(newFrame)")
            self.setFrame(newFrame, display: true)
            // 再次按像素校正（防止亚像素导致的微缝隙）
            self.applyRightEdgeShiftIfNeeded()
        }
        if Thread.isMainThread {
            DispatchQueue.main.async(execute: performMove)
        } else {
            DispatchQueue.main.async(execute: performMove)
        }
    }

    // 使用 CoreGraphics 获取最右侧显示器的像素边界，并按窗口的 backingScaleFactor 转为点坐标
    private func rightmostDisplayFrameInPoints() -> CGRect? {
        var count: UInt32 = 0
        var err = CGGetActiveDisplayList(0, nil, &count)
        if err != .success { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        err = CGGetActiveDisplayList(count, &ids, &count)
        if err != .success || ids.isEmpty { return nil }
        // 选择 maxX 最大的显示器
        let rectPixels = ids.map { CGDisplayBounds($0) }.max(by: { $0.maxX < $1.maxX })
        guard let rp = rectPixels else { return nil }
        let scale = self.backingScaleFactor > 0 ? self.backingScaleFactor : 2.0
        return CGRect(x: rp.origin.x / scale,
                      y: rp.origin.y / scale,
                      width: rp.size.width / scale,
                      height: rp.size.height / scale)
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

        // 监听全局帧率与物理参数/视觉参数变化
        NotificationCenter.default.addObserver(self, selector: #selector(handleFrameRateChanged), name: AppSettings.frameRateChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePhysicsParamsChanged), name: AppSettings.physicsParamsChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleEdgeVisualChanged), name: AppSettings.edgeVisualParamsChangedNotification, object: nil)
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
            applyRightEdgeShiftIfNeeded()
        }
    }

    // 如果当前靠近屏幕右侧，则对 png2（idle）应用额外右移，以便更贴合
    private func applyRightEdgeShiftIfNeeded() {
        let frame = AppSettings.shared.edgeBounds()
        var win = self.frame
        // 判断是否在右侧边缘附近（允许一定误差）
        let distanceToRight = abs(win.maxX - frame.maxX)
        if distanceToRight <= 32 { // 32像素阈值，吸附更稳定
            let lower = frame.minX
            let upper = frame.maxX - win.width
            let scale = (self.backingScaleFactor > 0) ? self.backingScaleFactor : (NSScreen.main?.backingScaleFactor ?? 2.0)
            let compPt = AppSettings.shared.edgeRightCompensationPx / max(scale, 1)
            var targetX = frame.maxX - win.width + compPt
            // 再次夹取，允许补偿越过右缘；当 upper < lower 时退回到 lower
            let upperWithComp = upper + compPt
            if upperWithComp >= lower {
                targetX = min(max(lower, targetX), upperWithComp)
            } else {
                targetX = lower
            }
            // 按像素对齐比较：若目标像素位置变化则移动
            let pxCur = round(win.origin.x * scale)
            let pxTar = round(targetX * scale)
            if pxCur != pxTar {
                win.origin.x = targetX
                self.setFrame(win, display: true)
                print("已应用紧贴补偿: \(AppSettings.shared.edgeRightCompensationPx)px, 新位置: \(win)")
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

    // 对外：停止一切动画/物理活动（用于隐藏时安全挂起）
    func stopAllActivities() {
        stopFallAnimation()
    }
    
    private func updateFallAnimation() {
        // 使用用户选择的沿挂屏幕边界
        let screenFrame = AppSettings.shared.edgeBounds()
        
        let deltaTime: CGFloat = CGFloat(1.0 / AppSettings.shared.frameRate)
        // 重力向下（减少 y），这里用正值重力
        fallVelocity += AppSettings.shared.edgeGravity * deltaTime
        
        var newFrame = self.frame
        newFrame.origin.y -= fallVelocity * deltaTime
        
        // 检查是否碰撞到屏幕底部
        if newFrame.origin.y <= screenFrame.minY {
            newFrame.origin.y = screenFrame.minY
            // 弹力（0..1），0 表示不弹直接落地
            let e = AppSettings.shared.edgeRestitution
            if e > 0 {
                // 反向并按弹力缩放；若过小则直接落地
                fallVelocity = -fallVelocity * e
                let minBounceSpeed: CGFloat = 90
                if abs(fallVelocity) < minBounceSpeed {
                    self.setFrame(newFrame, display: true)
                    setState(.landed)
                    return
                }
                // 否则继续弹跳
                self.setFrame(newFrame, display: true)
                return
            } else {
                self.setFrame(newFrame, display: true)
                setState(.landed)
                return
            }
        }
        
        self.setFrame(newFrame, display: true)
    }

    @objc private func handleFrameRateChanged() {
        if currentState == .falling {
            stopFallAnimation()
            startFallAnimation()
        }
    }

    @objc private func handlePhysicsParamsChanged() {
        // 无需特别处理，下一帧会用新参数；若在下落中保持计时器即可
    }
    
    @objc private func handleEdgeVisualChanged() {
        // 视觉补偿变更时，立即按当前补偿“贴到右侧”并像素对齐（不再要求必须已在右缘附近）
        let screen = AppSettings.shared.edgeBounds()
        var win = self.frame
        let scale = (self.backingScaleFactor > 0) ? self.backingScaleFactor : (NSScreen.main?.backingScaleFactor ?? 2.0)
        let compPt = AppSettings.shared.edgeRightCompensationPx / max(scale, 1)
        let lower = screen.minX
        let upper = screen.maxX - win.width
        let upperWithComp = upper + compPt
        // 目标按像素对齐（避免亚像素缝隙）
        let pxMaxX = round(screen.maxX * scale)
        let pxW = round(win.width * scale)
        var targetX = (pxMaxX - pxW) / scale + compPt
        if upperWithComp >= lower {
            targetX = min(max(lower, targetX), upperWithComp)
        } else {
            targetX = lower
        }
        let pxCur = round(win.origin.x * scale)
        let pxTar = round(targetX * scale)
        print("[EdgeComp] compPx=\(AppSettings.shared.edgeRightCompensationPx) scale=\(scale) fromX=\(win.origin.x) -> targetX=\(targetX) pxCur=\(pxCur) pxTar=\(pxTar) screen.maxX=\(screen.maxX) winW=\(win.width)")
        if pxCur != pxTar {
            win.origin.x = targetX
            self.setFrame(win, display: true)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // 窗口关闭前停止动画与移除监听，避免关闭后仍然触发 setFrame 导致崩溃
    override func close() {
        stopFallAnimation()
        NotificationCenter.default.removeObserver(self)
        super.close()
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
        
        // 约束在用户选择的沿挂屏幕范围内
        let frame = AppSettings.shared.edgeBounds()
        newFrame.origin.x = min(max(frame.minX, newFrame.origin.x), frame.maxX - newFrame.size.width)
        newFrame.origin.y = min(max(frame.minY, newFrame.origin.y), frame.maxY - newFrame.size.height)
        
        self.setFrame(newFrame, display: true)
    }
    
    override func mouseUp(with event: NSEvent) {
        if !isDragging { return }
        
        isDragging = false
        // 如果靠近右侧边缘，执行贴边吸附并保持待机；否则自由落体
        let bounds = AppSettings.shared.edgeBounds()
        let snapThreshold: CGFloat = 64
        let distanceToRight = bounds.maxX - self.frame.maxX
        if distanceToRight <= snapThreshold {
            var f = self.frame
            // 吸附到右边缘（带 png2 右移校正）
            let lower = bounds.minX
            let upper = bounds.maxX - f.size.width
            let scale = (self.backingScaleFactor > 0) ? self.backingScaleFactor : (NSScreen.main?.backingScaleFactor ?? 2.0)
            let compPt = AppSettings.shared.edgeRightCompensationPx / max(scale, 1)
            var targetX = bounds.maxX - f.size.width + compPt
            if upper + compPt >= lower {
                targetX = min(max(lower, targetX), upper + compPt)
            } else {
                targetX = lower
            }
            // 夹取 Y
            let minY = bounds.minY
            let maxY = bounds.maxY - f.size.height
            f.origin.y = min(max(minY, f.origin.y), maxY)
            f.origin.x = targetX
            self.setFrame(f, display: true, animate: true)
            print("靠近右侧，贴边吸附，进入待机")
            setState(.idle)
        } else {
            // 开始自由落体
            print("松开鼠标，开始自由落体")
            setState(.falling)
        }
    }
    
    // MARK: - 公共方法
    func resetToInitialPosition() {
        // 停止所有动画
        stopFallAnimation()
        isDragging = false
        
        // 重新使用初始化时的位置计算逻辑
        // 使用用户选择的沿挂屏幕边界
        let screenFrame = AppSettings.shared.edgeBounds()
        let desiredSize = CGSize(width: 150, height: 200)
        let usedWidth = min(desiredSize.width, max(10, screenFrame.width))
        let usedHeight = min(desiredSize.height, max(10, screenFrame.height))
        let imageSize = CGSize(width: usedWidth, height: usedHeight)
        
        let lowerX = screenFrame.minX
        let upperX = screenFrame.maxX - imageSize.width
        let scale = (self.backingScaleFactor > 0) ? self.backingScaleFactor : (NSScreen.main?.backingScaleFactor ?? 2.0)
        let compPt = AppSettings.shared.edgeRightCompensationPx / max(scale, 1)
        let initialTargetX = screenFrame.maxX - imageSize.width + compPt
        let upperWithComp = upperX + compPt
        let initialX: CGFloat = (upperWithComp >= lowerX) ? min(max(lowerX, initialTargetX), upperWithComp) : lowerX
        
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
