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
    var edgeScreenScope: ScreenScope = .builtin { didSet { notifyScreenScopeChange() } }
    var spaceScreenScope: ScreenScope = .builtin { didSet { notifyScreenScopeChange() } }

    // MARK: - 物理参数（可调）
    // 沿挂：默认重力 500，下落无弹力（0 表示不弹）
    var edgeGravity: CGFloat = 500 { didSet { notifyPhysicsChange(oldValue != edgeGravity) } }
    var edgeRestitution: CGFloat = 0 { didSet { edgeRestitution = max(0, min(1, edgeRestitution)); notifyPhysicsChange(true) } }
    // 太空：默认重力 0（无重力），弹力 1（完全弹性）
    var spaceGravity: CGFloat = 0 { didSet { notifyPhysicsChange(oldValue != spaceGravity) } }
    var spaceRestitution: CGFloat = 1 { didSet { spaceRestitution = max(0, min(1, spaceRestitution)); notifyPhysicsChange(true) } }
    
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
    func edgeBounds() -> CGRect { bounds(for: edgeScreenScope) }
    func spaceBounds() -> CGRect {
        let group = screens(for: spaceScreenScope)
        guard let first = group.first else { return CGRect(x: 0, y: 0, width: 800, height: 600) }
        var rect = first.visibleFrame
        for s in group.dropFirst() { rect = rect.union(s.visibleFrame) }
        return rect
    }
}
