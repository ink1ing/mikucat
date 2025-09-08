//
//  AppSettings.swift
//  mikumac02
//
//  Global app settings such as motion frame rate.
//

import Foundation
import Cocoa
import CoreGraphics

final class AppSettings {
    static let shared = AppSettings()
    static let frameRateChangedNotification = Notification.Name("AppSettings.frameRateChanged")
    static let screenScopeChangedNotification = Notification.Name("AppSettings.screenScopeChanged")
    static let physicsParamsChangedNotification = Notification.Name("AppSettings.physicsParamsChanged")
    static let edgeVisualParamsChangedNotification = Notification.Name("AppSettings.edgeVisualParamsChanged")

    // Default 60 FPS
    var frameRate: Double = 60 {
        didSet {
            if oldValue != frameRate {
                NotificationCenter.default.post(name: AppSettings.frameRateChangedNotification, object: self)
            }
        }
    }

    var frameInterval: TimeInterval { 1.0 / frameRate }

    // MARK: - 屏幕范围选择
    enum ScreenScope: String { case builtin, external }
    // 沿挂/太空分别选择屏幕范围
    var edgeScreenScope: ScreenScope = .builtin { didSet { refreshCachedBounds(); notifyScreenScopeChange() } }
    var spaceScreenScope: ScreenScope = .builtin { didSet { refreshCachedBounds(); notifyScreenScopeChange() } }

    // MARK: - 物理参数（可调）
    // 沿挂：默认重力 500，下落无弹力（0 表示不弹）
    var edgeGravity: CGFloat = 500 { didSet { notifyPhysicsChange(oldValue != edgeGravity) } }
    var edgeRestitution: CGFloat = 0 { didSet { edgeRestitution = max(0, min(1, edgeRestitution)); notifyPhysicsChange(true) } }
    // 太空：默认重力 0（无重力），弹力 1（完全弹性）
    var spaceGravity: CGFloat = 0 { didSet { notifyPhysicsChange(oldValue != spaceGravity) } }
    var spaceRestitution: CGFloat = 1 { didSet { spaceRestitution = max(0, min(1, spaceRestitution)); notifyPhysicsChange(true) } }
    
    // MARK: - 视觉参数（沿挂）
    // 右侧“紧贴补偿”（单位：像素 px）。每 +1 px，沿挂 miku 向右平移 1px。
    // 默认保持与当前版本相同的贴边偏移体验：12。
    var edgeRightCompensationPx: CGFloat = 12 {
        didSet {
            // 合理范围 0..32px
            let clamped = max(0, min(32, edgeRightCompensationPx))
            if clamped != edgeRightCompensationPx { edgeRightCompensationPx = clamped; return }
            NotificationCenter.default.post(name: AppSettings.edgeVisualParamsChangedNotification, object: self)
        }
    }
    
    private func notifyScreenScopeChange() {
        NotificationCenter.default.post(name: AppSettings.screenScopeChangedNotification, object: self)
    }
    private func notifyPhysicsChange(_ changed: Bool) {
        if changed {
            NotificationCenter.default.post(name: AppSettings.physicsParamsChangedNotification, object: self)
        }
    }
    
    // 根据 scope 计算矩形边界（合并所有符合条件的屏幕）
    private func screens(for scope: ScreenScope) -> [NSScreen] {
        let screens = NSScreen.screens
        if screens.isEmpty { return [] }
        func isBuiltin(_ s: NSScreen) -> Bool {
            if let num = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                let did = CGDirectDisplayID(num.uint32Value)
                return CGDisplayIsBuiltin(did) != 0
            }
            return false
        }
        switch scope {
        case .builtin:
            let group = screens.filter { isBuiltin($0) }
            return group.isEmpty ? (NSScreen.main.map { [$0] } ?? [screens[0]]) : group
        case .external:
            let group = screens.filter { !isBuiltin($0) }
            return group.isEmpty ? (NSScreen.main.map { [$0] } ?? [screens[0]]) : group
        }
    }

    // union of frames
    func bounds(for scope: ScreenScope) -> CGRect {
        let group = screens(for: scope)
        guard let first = group.first else { return CGRect(x: 0, y: 0, width: 800, height: 600) }
        var rect = first.frame
        for s in group.dropFirst() { rect = rect.union(s.frame) }
        return rect
    }

    // 沿挂使用 frame 范围；太空模式使用 visibleFrame（避开菜单栏/坞）
    private var cachedEdgeRect: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
    private var cachedSpaceRect: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)

    func edgeBounds() -> CGRect { cachedEdgeRect }
    func spaceBounds() -> CGRect { cachedSpaceRect }

    private func computeEdgeBounds() -> CGRect { bounds(for: edgeScreenScope) }
    private func computeSpaceBounds() -> CGRect {
        let group = screens(for: spaceScreenScope)
        guard let first = group.first else { return CGRect(x: 0, y: 0, width: 800, height: 600) }
        var rect = first.visibleFrame
        for s in group.dropFirst() { rect = rect.union(s.visibleFrame) }
        return rect
    }

    private func refreshCachedBounds() {
        cachedEdgeRect = computeEdgeBounds()
        cachedSpaceRect = computeSpaceBounds()
    }

    private init() {
        refreshCachedBounds()
        loadFromDefaults()
        // 屏幕参数变化时刷新缓存
        NotificationCenter.default.addObserver(self, selector: #selector(onScreensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func onScreensChanged() {
        refreshCachedBounds()
        notifyScreenScopeChange()
    }

    // MARK: - 持久化
    private enum Keys {
        static let edgeGravity = "edgeGravity"
        static let edgeRestitution = "edgeRestitution"
        static let spaceGravity = "spaceGravity"
        static let spaceRestitution = "spaceRestitution"
        static let edgeRightCompensationPx = "edgeRightCompensationPx"
        static let frameRate = "frameRate"
        static let edgeScope = "edgeScreenScope"
        static let spaceScope = "spaceScreenScope"
    }

    func saveToDefaults() {
        let d = UserDefaults.standard
        d.set(Double(edgeGravity), forKey: Keys.edgeGravity)
        d.set(Double(edgeRestitution), forKey: Keys.edgeRestitution)
        d.set(Double(spaceGravity), forKey: Keys.spaceGravity)
        d.set(Double(spaceRestitution), forKey: Keys.spaceRestitution)
        d.set(Double(edgeRightCompensationPx), forKey: Keys.edgeRightCompensationPx)
        d.set(frameRate, forKey: Keys.frameRate)
        d.set(edgeScreenScope.rawValue, forKey: Keys.edgeScope)
        d.set(spaceScreenScope.rawValue, forKey: Keys.spaceScope)
        d.synchronize()
    }

    func loadFromDefaults() {
        let d = UserDefaults.standard
        if d.object(forKey: Keys.edgeGravity) != nil { edgeGravity = CGFloat(d.double(forKey: Keys.edgeGravity)) }
        if d.object(forKey: Keys.edgeRestitution) != nil { edgeRestitution = CGFloat(d.double(forKey: Keys.edgeRestitution)) }
        if d.object(forKey: Keys.spaceGravity) != nil { spaceGravity = CGFloat(d.double(forKey: Keys.spaceGravity)) }
        if d.object(forKey: Keys.spaceRestitution) != nil { spaceRestitution = CGFloat(d.double(forKey: Keys.spaceRestitution)) }
        if d.object(forKey: Keys.edgeRightCompensationPx) != nil { edgeRightCompensationPx = CGFloat(d.double(forKey: Keys.edgeRightCompensationPx)) }
        if d.object(forKey: Keys.frameRate) != nil { frameRate = d.double(forKey: Keys.frameRate) }
        if let raw = d.string(forKey: Keys.edgeScope), let s = ScreenScope(rawValue: raw) { edgeScreenScope = s }
        if let raw = d.string(forKey: Keys.spaceScope), let s = ScreenScope(rawValue: raw) { spaceScreenScope = s }
    }
}
