import Cocoa

final class PreferencesWindowController: NSWindowController {
    private let tabView = NSTabView()
    private var saveButton: NSButton!

    // Edge controls
    private var edgeGravitySlider: NSSlider!
    private var edgeGravityField: NSTextField!
    private var edgeRestitutionSlider: NSSlider!
    private var edgeRestitutionField: NSTextField!
    private var edgeCompSlider: NSSlider!
    private var edgeCompField: NSTextField!

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
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
                         styleMask: [.titled, .closable],
                         backing: .buffered,
                         defer: false)
        w.title = "偏好设置"
        self.window = w
        guard let content = w.contentView else { return }

        tabView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(tabView)

        // 保存按钮（右下角）
        saveButton = NSButton(title: "保存设置", target: self, action: #selector(onSaveTapped))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(saveButton)

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            tabView.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            tabView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -8),

            saveButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
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

    // 收集当前 UI 数值并写入 AppSettings
    private func commitFieldsToSettings() {
        // 沿挂
        if let tf = edgeGravityField { AppSettings.shared.edgeGravity = CGFloat(Double(tf.stringValue) ?? edgeGravitySlider.doubleValue) }
        if let tf = edgeRestitutionField { AppSettings.shared.edgeRestitution = CGFloat(Double(tf.stringValue) ?? edgeRestitutionSlider.doubleValue) }
        if let tf = edgeCompField { AppSettings.shared.edgeRightCompensationPx = CGFloat(Double(tf.stringValue) ?? edgeCompSlider.doubleValue) }
        // 太空
        if let tf = spaceGravityField { AppSettings.shared.spaceGravity = CGFloat(Double(tf.stringValue) ?? spaceGravitySlider.doubleValue) }
        if let tf = spaceRestitutionField { AppSettings.shared.spaceRestitution = CGFloat(Double(tf.stringValue) ?? spaceRestitutionSlider.doubleValue) }
    }

    @objc private func onSaveTapped() {
        // 确保文本框未回车的输入也被采纳
        commitFieldsToSettings()
        // 持久化到用户默认
        AppSettings.shared.saveToDefaults()
        // 轻提示
        let alert = NSAlert()
        alert.messageText = "已保存设置"
        alert.informativeText = "当前参数已保存，下次启动自动生效。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    private func buildEdgeTab() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // 物理参数组
        let box = NSBox()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.title = "物理参数"
        box.contentViewMargins = NSSize(width: 12, height: 10)
        container.addSubview(box)

        // 行控件
        let gravLabel = makeLabel("重力 (pt/s²)")
        edgeGravitySlider = NSSlider(value: Double(AppSettings.shared.edgeGravity), minValue: 0, maxValue: 2000, target: self, action: #selector(onEdgeGravityChanged))
        edgeGravityField = makeNumberField(value: Double(AppSettings.shared.edgeGravity), min: 0, max: 2000, step: 10, action: #selector(onEdgeGravityFieldChanged))

        let restLabel = makeLabel("弹力 (0-1)")
        edgeRestitutionSlider = NSSlider(value: Double(AppSettings.shared.edgeRestitution), minValue: 0, maxValue: 1, target: self, action: #selector(onEdgeRestitutionChanged))
        edgeRestitutionField = makeNumberField(value: Double(AppSettings.shared.edgeRestitution), min: 0, max: 1, step: 0.05, action: #selector(onEdgeRestitutionFieldChanged))

        let compLabel = makeLabel("紧贴补偿 (px)")
        edgeCompSlider = NSSlider(value: Double(AppSettings.shared.edgeRightCompensationPx), minValue: 0, maxValue: 32, target: self, action: #selector(onEdgeCompChanged))
        edgeCompField = makeNumberField(value: Double(AppSettings.shared.edgeRightCompensationPx), min: 0, max: 32, step: 1, action: #selector(onEdgeCompFieldChanged))

        // Grid
        let grid = NSGridView(views: [
            [gravLabel, edgeGravitySlider, edgeGravityField],
            [restLabel, edgeRestitutionSlider, edgeRestitutionField],
            [compLabel, edgeCompSlider, edgeCompField]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 8
        // 列宽：第一列为标签固定最小宽度，第三列输入框固定宽度
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 2).width = 80
        if let content = box.contentView { content.addSubview(grid) }

        // 恢复默认按钮
        let restoreBtn = NSButton(title: "恢复默认", target: self, action: #selector(onEdgeRestoreDefaults))
        restoreBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(restoreBtn)

        // 布局
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            box.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            box.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),

            grid.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor),
            grid.topAnchor.constraint(equalTo: box.contentView!.topAnchor),
            grid.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor),

            restoreBtn.topAnchor.constraint(equalTo: box.bottomAnchor, constant: 16),
            restoreBtn.trailingAnchor.constraint(equalTo: box.trailingAnchor)
        ])

        return container
    }

    private func buildSpaceTab() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let box = NSBox()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.title = "物理参数"
        box.contentViewMargins = NSSize(width: 12, height: 10)
        container.addSubview(box)

        let gravLabel = makeLabel("重力 (pt/s²)")
        spaceGravitySlider = NSSlider(value: Double(AppSettings.shared.spaceGravity), minValue: 0, maxValue: 2000, target: self, action: #selector(onSpaceGravityChanged))
        spaceGravityField = makeNumberField(value: Double(AppSettings.shared.spaceGravity), min: 0, max: 2000, step: 10, action: #selector(onSpaceGravityFieldChanged))

        let restLabel = makeLabel("弹力 (0-1)")
        spaceRestitutionSlider = NSSlider(value: Double(AppSettings.shared.spaceRestitution), minValue: 0, maxValue: 1, target: self, action: #selector(onSpaceRestitutionChanged))
        spaceRestitutionField = makeNumberField(value: Double(AppSettings.shared.spaceRestitution), min: 0, max: 1, step: 0.05, action: #selector(onSpaceRestitutionFieldChanged))

        let grid = NSGridView(views: [
            [gravLabel, spaceGravitySlider, spaceGravityField],
            [restLabel, spaceRestitutionSlider, spaceRestitutionField]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 2).width = 80
        if let content = box.contentView { content.addSubview(grid) }

        let restoreBtn = NSButton(title: "恢复默认", target: self, action: #selector(onSpaceRestoreDefaults))
        restoreBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(restoreBtn)

        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            box.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            box.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),

            grid.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor),
            grid.topAnchor.constraint(equalTo: box.contentView!.topAnchor),
            grid.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor),

            restoreBtn.topAnchor.constraint(equalTo: box.bottomAnchor, constant: 16),
            restoreBtn.trailingAnchor.constraint(equalTo: box.trailingAnchor)
        ])

        return container
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
        edgeCompSlider.doubleValue = 12
        onEdgeGravityChanged(); onEdgeRestitutionChanged(); onEdgeCompChanged()
    }

    @objc private func onEdgeCompChanged() {
        AppSettings.shared.edgeRightCompensationPx = CGFloat(edgeCompSlider.doubleValue)
        edgeCompField.stringValue = String(format: "%.0f", edgeCompSlider.doubleValue)
    }
    @objc private func onEdgeCompFieldChanged() {
        let v = Double(edgeCompField.stringValue) ?? Double(AppSettings.shared.edgeRightCompensationPx)
        edgeCompSlider.doubleValue = min(32, max(0, v))
        onEdgeCompChanged()
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
