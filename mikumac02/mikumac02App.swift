//
//  mikumac02App.swift
//  mikumac02
//
//  Created by INKLING on 8/31/25.
//

import Cocoa

@main
struct mikumac02App {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}