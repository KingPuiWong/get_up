import Cocoa
import UserNotifications
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: Constants

    private let standIntervalOptions = [20, 30, 45, 60, 90]
    private let standDurationMinutes = 5
    private let defaultIntervalMinutes = 45
    private let earlyFireToleranceSeconds: TimeInterval = 30

    private enum Keys {
        static let intervalMinutes = "intervalMinutes"
    }

    // MARK: State

    private var statusItem: NSStatusItem!
    private var enabled = true
    private var intervalMinutes = 45
    private var startTime = Date()

    private var remindTimer: Timer?
    private var ticker: Timer?

    // MARK: Dynamic menu items

    private var statusMenuItem: NSMenuItem!

    // MARK: App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSettings()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if !granted {
                DispatchQueue.main.async {
                    self?.showNotificationPermissionDeniedAlert()
                }
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = enabled ? "🪑" : "💤"

        buildMenu()
        startTimers()
    }

    // MARK: Persistence

    private func loadSettings() {
        let saved = UserDefaults.standard.integer(forKey: Keys.intervalMinutes)
        if saved > 0 {
            intervalMinutes = saved
        }
    }

    private func saveInterval() {
        UserDefaults.standard.set(intervalMinutes, forKey: Keys.intervalMinutes)
    }

    // MARK: Launch at login

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: Menu

    private func buildMenu() {
        let menu = NSMenu()

        let toggleTitle = enabled
            ? "⏸ 暂停站立提醒（当前已开启）"
            : "▶️ 开始站立提醒（当前已暂停）"
        menu.addItem(makeMenuItem(title: toggleTitle, action: #selector(toggleEnabled)))
        menu.addItem(.separator())

        let intervalItem = NSMenuItem(title: "⏱ 站立提醒间隔", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for mins in standIntervalOptions {
            let prefix = mins == intervalMinutes ? "✓ " : "  "
            let item = makeMenuItem(title: "\(prefix)\(mins) 分钟", action: #selector(setInterval(_:)))
            item.tag = mins
            intervalMenu.addItem(item)
        }
        intervalMenu.addItem(.separator())
        let customPrefix = standIntervalOptions.contains(intervalMinutes) ? "  " : "✓ "
        intervalMenu.addItem(makeMenuItem(title: "\(customPrefix)自定义...", action: #selector(setCustomInterval)))
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)
        menu.addItem(.separator())

        let si = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        si.isEnabled = false
        menu.addItem(si)
        self.statusMenuItem = si
        menu.addItem(.separator())

        menu.addItem(makeMenuItem(title: "🔔 现在提醒我站起来", action: #selector(remindNow)))
        menu.addItem(.separator())

        let loginTitle = isLoginItemEnabled ? "✓ 开机启动" : "  开机启动"
        menu.addItem(makeMenuItem(title: loginTitle, action: #selector(toggleLoginItem)))
        menu.addItem(.separator())

        menu.addItem(makeMenuItem(title: "退出", action: #selector(quitApp)))

        statusItem.menu = menu
        refreshStatus()
    }

    private func makeMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: Status refresh

    @objc private func refreshStatus() {
        guard let item = statusMenuItem else { return }

        if !enabled {
            item.title = "⏸ 站立提醒已暂停"
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = max(0, Double(intervalMinutes * 60) - elapsed)
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        item.title = "⏳ 距下次站立提醒：\(String(format: "%02d:%02d", mins, secs))"
    }

    // MARK: Timers

    private func startTimers() {
        stopAllTimers()
        startTicker()

        if enabled {
            remindTimer = makeCommonModesTimer(interval: TimeInterval(intervalMinutes * 60), repeats: true) { [weak self] _ in
                self?.onRemind()
            }
        }
    }

    private func stopAllTimers() {
        remindTimer?.invalidate()
        ticker?.invalidate()
        remindTimer = nil
        ticker = nil
    }

    private func startTicker() {
        ticker = makeCommonModesTimer(interval: 1, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    private func makeCommonModesTimer(interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: block)
        RunLoop.current.add(timer, forMode: .common)
        return timer
    }

    // MARK: Reminder

    private func resetTimer() {
        startTime = Date()
        stopAllTimers()
        startTimers()
    }

    private func onRemind() {
        guard enabled else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed + earlyFireToleranceSeconds >= Double(intervalMinutes * 60) else { return }

        sendNotification(
            title: "⏰ 该站起来了！",
            body: "你已久坐 \(intervalMinutes) 分钟，请起来活动 \(standDurationMinutes) 分钟！"
        )

        enabled = false
        statusItem.button?.title = "💤"
        stopAllTimers()
        startTicker()
        buildMenu()
    }

    // MARK: Notification

    private func sendNotification(title: String, body: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func showNotificationPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "需要通知权限"
        alert.informativeText = "请前往「系统设置 → 通知 → GetUp」开启通知权限，否则站立提醒将无法显示。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: Menu callbacks

    @objc private func toggleEnabled() {
        enabled.toggle()

        if enabled {
            statusItem.button?.title = "🪑"
            resetTimer()
            sendNotification(title: "起来站站", body: "站立提醒已开启，每 \(intervalMinutes) 分钟提醒一次")
        } else {
            statusItem.button?.title = "💤"
            stopAllTimers()
            startTicker()
            sendNotification(title: "起来站站", body: "站立提醒已暂停")
        }

        buildMenu()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        intervalMinutes = sender.tag
        saveInterval()
        if enabled { resetTimer() }
        buildMenu()
        sendNotification(title: "起来站站", body: "站立提醒间隔已设置为 \(intervalMinutes) 分钟")
    }

    @objc private func setCustomInterval() {
        let alert = NSAlert()
        alert.messageText = "自定义提醒间隔"
        alert.informativeText = "请输入提醒间隔（分钟）："
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = String(intervalMinutes)
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let mins = Int(input.stringValue.trimmingCharacters(in: .whitespaces)), mins > 0 else {
            let err = NSAlert()
            err.messageText = "输入无效"
            err.informativeText = "请输入大于 0 的整数"
            err.runModal()
            return
        }

        intervalMinutes = mins
        saveInterval()
        if enabled { resetTimer() }
        buildMenu()
        sendNotification(title: "起来站站", body: "站立提醒间隔已设置为 \(intervalMinutes) 分钟")
    }

    @objc private func remindNow() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if settings.authorizationStatus == .authorized {
                    self.sendNotification(
                        title: "⏰ 该站起来了！",
                        body: "请起来活动 \(self.standDurationMinutes) 分钟！"
                    )
                } else {
                    let alert = NSAlert()
                    alert.messageText = "⏰ 该站起来了！"
                    alert.informativeText = "请起来活动 \(self.standDurationMinutes) 分钟！"
                    alert.addButton(withTitle: "知道了")
                    alert.runModal()
                }

                if self.enabled { self.resetTimer() }
            }
        }
    }

    @objc private func toggleLoginItem() {
        do {
            if isLoginItemEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            buildMenu()
        } catch {
            let alert = NSAlert()
            alert.messageText = "操作失败"
            alert.informativeText = "无法修改开机启动设置：\(error.localizedDescription)"
            alert.runModal()
        }
    }

    @objc private func quitApp() {
        stopAllTimers()
        NSApp.terminate(nil)
    }
}
