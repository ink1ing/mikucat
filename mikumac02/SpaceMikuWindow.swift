//
//  SpaceMikuWindow.swift
//  mikumac02
//
//  Created by INKLING on 8/31/25.
//

import Cocoa

class SpaceMikuWindow: NSWindow {
    private var imageView: NSImageView!
    private var images: [NSImage] = []
    private var currentImageIndex: Int = 0
    private var timer: Timer?
    // 公开速度用于分裂方向控制
    var velocity: CGPoint = .zero
    private let speedRange: ClosedRange<CGFloat> = 160...280
    private static let defaultWindowSize: CGSize = CGSize(width: 140, height: 140)
    var isPaused: Bool = false
    private var pendingSingleClick: DispatchWorkItem?
    static let spawnRequestedNotification = Notification.Name("SpaceMikuWindow.spawnRequested")
    static let pauseChangedNotification = Notification.Name("SpaceMikuWindow.pauseChanged")
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        commonInit()
    }
    
    convenience init() {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let size = Self.defaultWindowSize
        let startX = screen.midX - size.width/2
        let startY = screen.midY - size.height/2
        let frame = NSRect(x: startX, y: startY, width: size.width, height: size.height)
        self.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
    }
    
    private func commonInit() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        
        setupImageView()
        loadImages()
        randomizeVelocity()
        setRandomImage()
        // 交由 AppDelegate 驱动物理更新，默认不暂停
        isPaused = false
        NotificationCenter.default.addObserver(self, selector: #selector(handleFrameRateChanged), name: AppSettings.frameRateChangedNotification, object: nil)
    }

    // 允许无边框窗口成为 key，避免 makeKeyWindow 警告
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    private func setupImageView() {
        imageView = NSImageView(frame: contentView?.bounds ?? .zero)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.autoresizingMask = [.width, .height]
        contentView?.addSubview(imageView)
    }
    
    private func loadImages() {
        // Load miku4 ~ miku10 from Assets
        images = (4...10).compactMap { NSImage(named: "miku\($0)") }
        if images.isEmpty {
            // Fallback to a simple colored circle for debugging
            let fallback = NSImage(size: NSSize(width: 80, height: 80))
            fallback.lockFocus()
            NSColor.systemPink.setFill()
            let rect = NSRect(x: 0, y: 0, width: 80, height: 80)
            NSBezierPath(ovalIn: rect).fill()
            fallback.unlockFocus()
            images = [fallback]
        }
    }
    
    private func randomizeVelocity() {
        func randomSpeed() -> CGFloat { CGFloat.random(in: speedRange) * (Bool.random() ? 1 : -1) }
        var vx = randomSpeed()
        var vy = randomSpeed()
        // avoid too small values
        if abs(vx) < 80 { vx = vx < 0 ? -120 : 120 }
        if abs(vy) < 80 { vy = vy < 0 ? -120 : 120 }
        velocity = CGPoint(x: vx, y: vy)
    }

    // 以当前贴图尺寸作为“碰撞半径”的直径，使用圆形体积
    private var radius: CGFloat {
        let s = self.frame.size
        return min(s.width, s.height) * 0.5
    }
    private var center: CGPoint {
        get { CGPoint(x: frame.midX, y: frame.midY) }
        set {
            let size = frame.size
            let origin = CGPoint(x: newValue.x - size.width/2, y: newValue.y - size.height/2)
            setFrame(NSRect(origin: origin, size: size), display: true)
        }
    }
    
    private func setRandomImage() {
        guard !images.isEmpty else { return }
        var newIndex = Int.random(in: 0..<images.count)
        if images.count > 1 {
            // avoid repeating the same image
            while newIndex == currentImageIndex { newIndex = Int.random(in: 0..<images.count) }
        }
        currentImageIndex = newIndex
        imageView.image = images[newIndex]
    }

    // 外部触发：发生碰撞/反弹时切换形象
    func updateImageForImpact() {
        setRandomImage()
    }
    
    func start() { isPaused = false }
    func stop() { isPaused = true }
    
    func reset() {
        guard let screen = NSScreen.main?.frame else { return }
        let size = Self.defaultWindowSize
        let newOrigin = CGPoint(x: screen.midX - size.width/2, y: screen.midY - size.height/2)
        setFrame(NSRect(origin: newOrigin, size: size), display: true, animate: true)
        randomizeVelocity()
        setRandomImage()
    }
    
    private func tick() { /* no-op now managed globally */ }

    @objc private func handleFrameRateChanged() {
        if timer != nil { start() }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // 单击：暂停/继续；双击：请求分裂一个新的太空miku
    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            // 取消待执行的单击动作，触发分裂
            pendingSingleClick?.cancel()
            pendingSingleClick = nil
            NotificationCenter.default.post(name: Self.spawnRequestedNotification, object: self)
            return
        }
        if event.clickCount == 1 {
            pendingSingleClick?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                let willPause = !self.isPaused
                if self.isPaused { self.start() } else { self.stop() }
                NotificationCenter.default.post(name: Self.pauseChangedNotification, object: self, userInfo: ["paused": willPause])
            }
            pendingSingleClick = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }

    // 对外工具：在给定中心点与速度下放置本窗口
    func place(atCenter c: CGPoint, velocity v: CGPoint) {
        self.velocity = v
        self.center = c
    }

    // 对外可用属性，用于全局物理计算
    var bodyRadius: CGFloat { radius }
    var centerPoint: CGPoint {
        get { center }
        set { center = newValue }
    }
}
