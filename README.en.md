# Miku Desktop Pet · Mikucat

[中文](README.md) | [日本語](README.ja.md)

A small experiment to celebrate Hatsune Miku’s 18th anniversary on Aug 31, 2025. Special thanks to the artist X: @gomya0_0 for the image assets.

## Highlights
- Menu bar with two modes: “Edge-hanging Miku Cat” (gravity + edge behavior) and “Space Miku Cat” (zero-gravity bouncing)
- Visibility toggles and one-click reset for each mode
- Global motion frame rate: 30 / 48 / 50 / 60 / 120 FPS
- Edge mode: click=img1, drag=img1, falling=img1, landed=img3; double-click on landed state to reset
- Space mode: window moves freely, bounces on screen edges, and randomly switches among miku4~miku10 on each bounce (no immediate repeats)

## Build & Run
- Open `mikumac02.xcodeproj` in Xcode and run the `mikumac02` target
- Use the menu bar icon to toggle visibility, reset, and change frame rate
- App uses `LSUIElement` (no Dock icon)

## Credits & Notes
- Assets credit: Artist X: @gomya0_0
- For learning and celebration only; image copyrights remain with the original artist

