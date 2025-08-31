//
//  AppSettings.swift
//  mikumac02
//
//  Global app settings such as motion frame rate.
//

import Foundation

final class AppSettings {
    static let shared = AppSettings()
    static let frameRateChangedNotification = Notification.Name("AppSettings.frameRateChanged")

    // Default 60 FPS
    var frameRate: Double = 60 {
        didSet {
            if oldValue != frameRate {
                NotificationCenter.default.post(name: AppSettings.frameRateChangedNotification, object: self)
            }
        }
    }

    var frameInterval: TimeInterval { 1.0 / frameRate }
}

