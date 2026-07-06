import Cocoa

/// 置顶浮动提醒面板 — 在所有窗口之上，用户手动关闭前不消失
final class ReminderPanel: NSPanel {

    // MARK: - Callbacks

    var onDismiss: (() -> Void)?
    var onSnooze: (() -> Void)?

    // MARK: - Init

    convenience init(intervalMinutes: Int, standDurationMinutes: Int) {
        let contentRect = NSRect(x: 0, y: 0, width: 360, height: 200)

        self.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // --- 置顶 + 跨桌面 ---
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.worksWhenModal = true
        self.becomesKeyOnlyIfNeeded = true

        // --- 外观 ---
        self.title = "⏰ 该站起来了！"
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = false
        self.backgroundColor = NSColor.windowBackgroundColor

        let bodyLabel = NSTextField(wrappingLabelWithString:
            "你已久坐 \(intervalMinutes) 分钟，\n请起来活动 \(standDurationMinutes) 分钟！")
        bodyLabel.alignment = .center
        bodyLabel.font = NSFont.systemFont(ofSize: 16)
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        // --- 按钮 ---
        let snoozeButton = NSButton(title: "再等 5 分钟", target: nil, action: nil)
        snoozeButton.bezelStyle = .rounded
        snoozeButton.keyEquivalent = "\r"          // Enter
        snoozeButton.target = self
        snoozeButton.action = #selector(snoozeTapped)

        let dismissButton = NSButton(title: "知道了", target: self, action: #selector(dismissTapped))
        dismissButton.bezelStyle = .rounded
        dismissButton.keyEquivalent = "\u{1b}"     // Esc

        let buttonStack = NSStackView(views: [dismissButton, snoozeButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // --- 布局 ---
        guard let contentView = self.contentView else { return }
        contentView.addSubview(bodyLabel)
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            bodyLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            bodyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 50),
            bodyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),

            buttonStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            buttonStack.widthAnchor.constraint(equalToConstant: 280),
        ])

        // --- 居中显示 ---
        self.center()
    }

    // MARK: - Override close to fire dismiss callback

    override func close() {
        // 点击关闭按钮（X）等同于"知道了"
        super.close()
        onDismiss?()
    }

    // MARK: - Button actions

    @objc private func dismissTapped() {
        onDismiss?()
        close()
    }

    @objc private func snoozeTapped() {
        onSnooze?()
        close()
    }
}
