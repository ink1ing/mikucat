import Cocoa

final class PreferencesWindowController: NSWindowController {
    private let tabView = NSTabView()

    // Edge controls
    private var edgeGravitySlider: NSSlider!
    private var edgeGravityField: NSTextField!
    private var edgeRestitutionSlider: NSSlider!
    private var edgeRestitutionField: NSTextField!

    // Space controls
    private var spaceGravitySlider: NSSlider!
    private var spaceGravityField: NSTextField!
    private var spaceRestitutionSlider: NSSlider!
    private var spaceRestitutionField: NSTextField!

    convenience init() {
        self.init(window: nil)
        setupWindow()
    }

    private func setupWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
                         styleMask: [.titled, .closable],
                         backing: .buffered,
                         defer: false)
        w.title = "偏好设置"
        self.window = w
        guard let content = w.contentView else { return }

        tabView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            tabView.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            tabView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8)
        ])

        let edgeItem = NSTabViewItem(identifier: "edge")
        edgeItem.label = "沿挂"
        edgeItem.view = buildEdgeTab()
        tabView.addTabViewItem(edgeItem)

        let spaceItem = NSTabViewItem(identifier: "space")
        spaceItem.label = "太空"
        spaceItem.view = buildSpaceTab()
        tabView.addTabViewItem(spaceItem)
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 12)
        return l
    }

    private func makeNumberField(value: Double, min: Double, max: Double, step: Double, action: Selector) -> NSTextField {
        let f = NSTextField()
        f.translatesAutoresizingMaskIntoConstraints = false
        f.alignment = .right
        f.stringValue = String(format: "%.2f", value)
        f.target = self
        f.action = action
        f.placeholderString = "数值"
        return f
    }

    private func buildEdgeTab() -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false

        // Gravity
        let gravLabel = makeLabel("重力 (pt/s²)")
        gravLabel.translatesAutoresizingMaskIntoConstraints = false
        edgeGravitySlider = NSSlider(value: Double(AppSettings.shared.edgeGravity), minValue: 0, maxValue: 2000, target: self, action: #selector(onEdgeGravityChanged))
        edgeGravitySlider.translatesAutoresizingMaskIntoConstraints = false
        edgeGravityField = makeNumberField(value: Double(AppSettings.shared.edgeGravity), min: 0, max: 2000, step: 10, action: #selector(onEdgeGravityFieldChanged))

        // Restitution
        let restLabel = makeLabel("弹力 (0-1)")
        restLabel.translatesAutoresizingMaskIntoConstraints = false
        edgeRestitutionSlider = NSSlider(value: Double(AppSettings.shared.edgeRestitution), minValue: 0, maxValue: 1, target: self, action: #selector(onEdgeRestitutionChanged))
        edgeRestitutionSlider.translatesAutoresizingMaskIntoConstraints = false
        edgeRestitutionField = makeNumberField(value: Double(AppSettings.shared.edgeRestitution), min: 0, max: 1, step: 0.05, action: #selector(onEdgeRestitutionFieldChanged))

        // Restore defaults
        let restoreBtn = NSButton(title: "恢复默认", target: self, action: #selector(onEdgeRestoreDefaults))
        restoreBtn.translatesAutoresizingMaskIntoConstraints = false

        [gravLabel, edgeGravitySlider, edgeGravityField, restLabel, edgeRestitutionSlider, edgeRestitutionField, restoreBtn].forEach { v.addSubview($0) }

        // Layout
        NSLayoutConstraint.activate([
            gravLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 20),
            gravLabel.topAnchor.constraint(equalTo: v.topAnchor, constant: 24),

            edgeGravitySlider.leadingAnchor.constraint(equalTo: gravLabel.leadingAnchor),
            edgeGravitySlider.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -120),
            edgeGravitySlider.centerYAnchor.constraint(equalTo: gravLabel.centerYAnchor),

            edgeGravityField.leadingAnchor.constraint(equalTo: edgeGravitySlider.trailingAnchor, constant: 8),
            edgeGravityField.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -20),
            edgeGravityField.centerYAnchor.constraint(equalTo: edgeGravitySlider.centerYAnchor),
            edgeGravityField.widthAnchor.constraint(equalToConstant: 80),

            restLabel.leadingAnchor.constraint(equalTo: gravLabel.leadingAnchor),
            restLabel.topAnchor.constraint(equalTo: edgeGravitySlider.bottomAnchor, constant: 24),

            edgeRestitutionSlider.leadingAnchor.constraint(equalTo: restLabel.leadingAnchor),
            edgeRestitutionSlider.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -120),
            edgeRestitutionSlider.centerYAnchor.constraint(equalTo: restLabel.centerYAnchor),

            edgeRestitutionField.leadingAnchor.constraint(equalTo: edgeRestitutionSlider.trailingAnchor, constant: 8),
            edgeRestitutionField.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -20),
            edgeRestitutionField.centerYAnchor.constraint(equalTo: edgeRestitutionSlider.centerYAnchor),
            edgeRestitutionField.widthAnchor.constraint(equalToConstant: 80),

            restoreBtn.topAnchor.constraint(equalTo: edgeRestitutionSlider.bottomAnchor, constant: 24),
            restoreBtn.leadingAnchor.constraint(equalTo: gravLabel.leadingAnchor)
        ])

        return v
    }

    private func buildSpaceTab() -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false

        let gravLabel = makeLabel("重力 (pt/s²)")
        gravLabel.translatesAutoresizingMaskIntoConstraints = false
        spaceGravitySlider = NSSlider(value: Double(AppSettings.shared.spaceGravity), minValue: 0, maxValue: 2000, target: self, action: #selector(onSpaceGravityChanged))
        spaceGravitySlider.translatesAutoresizingMaskIntoConstraints = false
        spaceGravityField = makeNumberField(value: Double(AppSettings.shared.spaceGravity), min: 0, max: 2000, step: 10, action: #selector(onSpaceGravityFieldChanged))

        let restLabel = makeLabel("弹力 (0-1)")
        restLabel.translatesAutoresizingMaskIntoConstraints = false
        spaceRestitutionSlider = NSSlider(value: Double(AppSettings.shared.spaceRestitution), minValue: 0, maxValue: 1, target: self, action: #selector(onSpaceRestitutionChanged))
        spaceRestitutionSlider.translatesAutoresizingMaskIntoConstraints = false
        spaceRestitutionField = makeNumberField(value: Double(AppSettings.shared.spaceRestitution), min: 0, max: 1, step: 0.05, action: #selector(onSpaceRestitutionFieldChanged))

        let restoreBtn = NSButton(title: "恢复默认", target: self, action: #selector(onSpaceRestoreDefaults))
        restoreBtn.translatesAutoresizingMaskIntoConstraints = false

        [gravLabel, spaceGravitySlider, spaceGravityField, restLabel, spaceRestitutionSlider, spaceRestitutionField, restoreBtn].forEach { v.addSubview($0) }

        NSLayoutConstraint.activate([
            gravLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 20),
            gravLabel.topAnchor.constraint(equalTo: v.topAnchor, constant: 24),

            spaceGravitySlider.leadingAnchor.constraint(equalTo: gravLabel.leadingAnchor),
            spaceGravitySlider.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -120),
            spaceGravitySlider.centerYAnchor.constraint(equalTo: gravLabel.centerYAnchor),

            spaceGravityField.leadingAnchor.constraint(equalTo: spaceGravitySlider.trailingAnchor, constant: 8),
            spaceGravityField.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -20),
            spaceGravityField.centerYAnchor.constraint(equalTo: spaceGravitySlider.centerYAnchor),
            spaceGravityField.widthAnchor.constraint(equalToConstant: 80),

            restLabel.leadingAnchor.constraint(equalTo: gravLabel.leadingAnchor),
            restLabel.topAnchor.constraint(equalTo: spaceGravitySlider.bottomAnchor, constant: 24),

            spaceRestitutionSlider.leadingAnchor.constraint(equalTo: restLabel.leadingAnchor),
            spaceRestitutionSlider.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -120),
            spaceRestitutionSlider.centerYAnchor.constraint(equalTo: restLabel.centerYAnchor),

            spaceRestitutionField.leadingAnchor.constraint(equalTo: spaceRestitutionSlider.trailingAnchor, constant: 8),
            spaceRestitutionField.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -20),
            spaceRestitutionField.centerYAnchor.constraint(equalTo: spaceRestitutionSlider.centerYAnchor),
            spaceRestitutionField.widthAnchor.constraint(equalToConstant: 80),

            restoreBtn.topAnchor.constraint(equalTo: spaceRestitutionSlider.bottomAnchor, constant: 24),
            restoreBtn.leadingAnchor.constraint(equalTo: gravLabel.leadingAnchor)
        ])

        return v
    }

    // MARK: - Actions
    @objc private func onEdgeGravityChanged() {
        AppSettings.shared.edgeGravity = CGFloat(edgeGravitySlider.doubleValue)
        edgeGravityField.stringValue = String(format: "%.2f", edgeGravitySlider.doubleValue)
    }
    @objc private func onEdgeGravityFieldChanged() {
        let v = Double(edgeGravityField.stringValue) ?? Double(AppSettings.shared.edgeGravity)
        edgeGravitySlider.doubleValue = min(2000, max(0, v))
        onEdgeGravityChanged()
    }
    @objc private func onEdgeRestitutionChanged() {
        AppSettings.shared.edgeRestitution = CGFloat(edgeRestitutionSlider.doubleValue)
        edgeRestitutionField.stringValue = String(format: "%.2f", edgeRestitutionSlider.doubleValue)
    }
    @objc private func onEdgeRestitutionFieldChanged() {
        let v = Double(edgeRestitutionField.stringValue) ?? Double(AppSettings.shared.edgeRestitution)
        edgeRestitutionSlider.doubleValue = min(1, max(0, v))
        onEdgeRestitutionChanged()
    }
    @objc private func onEdgeRestoreDefaults() {
        edgeGravitySlider.doubleValue = 500
        edgeRestitutionSlider.doubleValue = 0
        onEdgeGravityChanged(); onEdgeRestitutionChanged()
    }

    @objc private func onSpaceGravityChanged() {
        AppSettings.shared.spaceGravity = CGFloat(spaceGravitySlider.doubleValue)
        spaceGravityField.stringValue = String(format: "%.2f", spaceGravitySlider.doubleValue)
    }
    @objc private func onSpaceGravityFieldChanged() {
        let v = Double(spaceGravityField.stringValue) ?? Double(AppSettings.shared.spaceGravity)
        spaceGravitySlider.doubleValue = min(2000, max(0, v))
        onSpaceGravityChanged()
    }
    @objc private func onSpaceRestitutionChanged() {
        AppSettings.shared.spaceRestitution = CGFloat(spaceRestitutionSlider.doubleValue)
        spaceRestitutionField.stringValue = String(format: "%.2f", spaceRestitutionSlider.doubleValue)
    }
    @objc private func onSpaceRestitutionFieldChanged() {
        let v = Double(spaceRestitutionField.stringValue) ?? Double(AppSettings.shared.spaceRestitution)
        spaceRestitutionSlider.doubleValue = min(1, max(0, v))
        onSpaceRestitutionChanged()
    }
    @objc private func onSpaceRestoreDefaults() {
        spaceGravitySlider.doubleValue = 0
        spaceRestitutionSlider.doubleValue = 1
        onSpaceGravityChanged(); onSpaceRestitutionChanged()
    }
}

