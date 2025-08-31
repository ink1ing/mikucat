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
    private var velocity: CGPoint = .zero
    private let speedRange: ClosedRange<CGFloat> = 160...280
    private static let defaultWindowSize: CGSize = CGSize(width: 140, height: 140)
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        commonInit()
    }
    
    convenience init() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
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
        
        start()
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
    
    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: AppSettings.shared.frameInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let size = Self.defaultWindowSize
        let newOrigin = CGPoint(x: screen.midX - size.width/2, y: screen.midY - size.height/2)
        setFrame(NSRect(origin: newOrigin, size: size), display: true, animate: true)
        randomizeVelocity()
        setRandomImage()
    }
    
    private func tick() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let dt: CGFloat = CGFloat(1.0 / AppSettings.shared.frameRate)
        var frame = self.frame
        frame.origin.x += velocity.x * dt
        frame.origin.y += velocity.y * dt
        
        var bounced = false
        // Left/Right
        if frame.minX <= screen.minX {
            frame.origin.x = screen.minX
            velocity.x = abs(velocity.x)
            bounced = true
        } else if frame.maxX >= screen.maxX {
            frame.origin.x = screen.maxX - frame.size.width
            velocity.x = -abs(velocity.x)
            bounced = true
        }
        // Bottom/Top
        if frame.minY <= screen.minY {
            frame.origin.y = screen.minY
            velocity.y = abs(velocity.y)
            bounced = true
        } else if frame.maxY >= screen.maxY {
            frame.origin.y = screen.maxY - frame.size.height
            velocity.y = -abs(velocity.y)
            bounced = true
        }
        
        setFrame(frame, display: true)
        if bounced { setRandomImage() }
    }

    @objc private func handleFrameRateChanged() {
        if timer != nil { start() }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
