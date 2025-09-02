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
    
    private func notifyScreenScopeChange() {
        NotificationCenter.default.post(name: AppSettings.screenScopeChangedNotification, object: self)
    }
    
    // 根据 scope 计算矩形边界（合并所有符合条件的屏幕）
    func bounds(for scope: ScreenScope) -> CGRect {
        let screens = NSScreen.screens
        if screens.isEmpty { return CGRect(x: 0, y: 0, width: 800, height: 600) }
        func isBuiltin(_ s: NSScreen) -> Bool {
            if let num = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                let did = CGDirectDisplayID(num.uint32Value)
                return CGDisplayIsBuiltin(did) != 0
            }
            return false
        }
        let group: [NSScreen]
        switch scope {
        case .builtin:
            group = screens.filter { isBuiltin($0) }
            if group.isEmpty { return NSScreen.main?.frame ?? screens[0].frame }
        case .external:
            group = screens.filter { !isBuiltin($0) }
            if group.isEmpty { return (NSScreen.main?.frame ?? screens[0].frame) }
        }
        var rect = group[0].frame
        for s in group.dropFirst() { rect = rect.union(s.frame) }
        return rect
    }
    
    func edgeBounds() -> CGRect { bounds(for: edgeScreenScope) }
    func spaceBounds() -> CGRect { bounds(for: spaceScreenScope) }
}
