import Cocoa
import UserNotifications
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: Constants

    private let standIntervalOptions = [20, 30, 45, 60, 90]
    private let standDurationMinutes = 5
    private let defaultIntervalMinutes = 45

    private enum NotifCategory {
        static let standReminder = "com.getup.stand-reminder"
    }

    private enum NotifAction {
        static let standUp = "com.getup.action.stand-up"
        static let snooze = "com.getup.action.snooze"
    }

    private enum Keys {
        static let intervalMinutes = "intervalMinutes"
        static let hasShownPermissionAlert = "hasShownPermissionAlert"
    }

    // MARK: State

    private var statusItem: NSStatusItem!
    private var enabled = true
    private var intervalMinutes = 45
    private var startTime = Date()

    private var remindTimer: Timer?
    private var ticker: Timer?
    private var reminderPanel: ReminderPanel?

    // MARK: Dynamic menu items

    private var statusMenuItem: NSMenuItem!

    // MARK: App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSettings()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if !granted {
                DispatchQueue.main.async {
                    let alreadyShown = UserDefaults.standard.bool(forKey: Keys.hasShownPermissionAlert)
                    if !alreadyShown {
                        UserDefaults.standard.set(true, forKey: Keys.hasShownPermissionAlert)
                        self?.showNotificationPermissionDeniedAlert()
                    }
                }
            }
        }
        UNUserNotificationCenter.current().delegate = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupNotificationCategories()
        statusItem.button?.title = enabled ? "🪑" : "💤"
        buildMenu()
        startTimers()
    }

    private func setupNotificationCategories() {
        let standUpAction = UNNotificationAction(
            identifier: NotifAction.standUp,
            title: "知道了",
            options: .foreground
        )
        let snoozeAction = UNNotificationAction(
            identifier: NotifAction.snooze,
            title: "再等 5 分钟",
            options: .foreground
        )
        let category = UNNotificationCategory(
            identifier: NotifCategory.standReminder,
            actions: [standUpAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
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

    private func startTimers() {
        stopAllTimers()
        startTicker()

        guard enabled else { return }

        let delay = TimeInterval(intervalMinutes * 60)
        remindTimer = makeCommonModesTimer(interval: delay, repeats: false) { [weak self] _ in
            self?.onRemind()
        }
    }

    private func stopAllTimers() {
        ticker?.invalidate()
        ticker = nil
        remindTimer?.invalidate()
        remindTimer = nil
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

    private func performReminder() {
        enabled = false
        statusItem.button?.title = "💤"
        stopAllTimers()
        startTicker()
        buildMenu()

        // --- 浮动强提醒面板（置顶，手动关闭才消失）---
        showReminderPanel()

        // 系统通知作为后备（切换桌面/DND 时也能收到）
        sendNotification(
            title: "⏰ 该站起来了！",
            body: "你已久坐 \(intervalMinutes) 分钟，请起来活动 \(standDurationMinutes) 分钟！",
            categoryIdentifier: NotifCategory.standReminder
        )
    }

    private func showReminderPanel() {
        // 如果已有面板在显示，先关掉
        reminderPanel?.close()

        let panel = ReminderPanel(intervalMinutes: intervalMinutes, standDurationMinutes: standDurationMinutes)
        panel.onDismiss = { [weak self] in
            self?.reminderPanel = nil
            // 点击"知道了" → 保持暂停状态，用户手动重新开启
            self?.buildMenu()
        }
        panel.onSnooze = { [weak self] in
            self?.reminderPanel = nil
            self?.snoozeReminder()
        }

        reminderPanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func onRemind() {
        guard enabled else { return }
        performReminder()
    }

    private func snoozeReminder() {
        remindTimer?.invalidate()
        remindTimer = makeCommonModesTimer(interval: 5 * 60, repeats: false) { [weak self] _ in
            self?.performReminder()
        }
        startTicker()
        buildMenu()
    }

    // MARK: Notification

    private func sendNotification(title: String, body: String, categoryIdentifier: String? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let cat = categoryIdentifier {
                content.categoryIdentifier = cat
            }

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.categoryIdentifier == NotifCategory.standReminder, enabled {
            onRemind()
        }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case NotifAction.standUp, UNNotificationDefaultActionIdentifier:
            onRemind()
        case NotifAction.snooze:
            snoozeReminder()
        default:
            break
        }
        completionHandler()
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
        // 直接显示浮动面板 — 不依赖系统通知权限
        enabled = false
        statusItem.button?.title = "💤"
        stopAllTimers()
        startTicker()
        buildMenu()

        let panel = ReminderPanel(intervalMinutes: intervalMinutes, standDurationMinutes: standDurationMinutes)
        panel.onDismiss = { [weak self] in
            self?.reminderPanel = nil
            // 点击"知道了" → 保持暂停，用户手动重新开启
            self?.buildMenu()
        }
        panel.onSnooze = { [weak self] in
            self?.reminderPanel = nil
            self?.snoozeReminder()
        }

        reminderPanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 系统通知作为后备
        sendNotification(
            title: "⏰ 该站起来了！",
            body: "请起来活动 \(standDurationMinutes) 分钟！"
        )
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
