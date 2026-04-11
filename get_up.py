#!/usr/bin/env python3
"""
起来站站 - Mac 菜单栏久坐提醒工具
"""
import time
import rumps
import subprocess

try:
    from Foundation import NSRunLoop, NSRunLoopCommonModes
except Exception:  # pragma: no cover - pyobjc/rumps runtime dependency
    NSRunLoop = None
    NSRunLoopCommonModes = None

# 预设时间间隔（分钟）
INTERVAL_OPTIONS = [20, 30, 45, 60, 90]

# 提醒站立时长（分钟）
STAND_DURATION = 5

# 喝水提醒间隔（分钟）
WATER_INTERVAL_OPTIONS = [45, 60, 90, 120]
DEFAULT_WATER_INTERVAL_MINUTES = 60
WATER_SIP_VOLUME_ML = 200

# rumps.Timer 在 start() 时会立即触发一次回调，留一点容差避免启动瞬间误触发提醒
TIMER_EARLY_FIRE_TOLERANCE_SECONDS = 0.5


def is_reminder_due(elapsed_seconds, interval_minutes, tolerance_seconds=TIMER_EARLY_FIRE_TOLERANCE_SECONDS):
    """判断是否到达提醒时间（容忍定时器轻微提前触发）"""
    return elapsed_seconds + tolerance_seconds >= interval_minutes * 60


def send_notification(title, message):
    """发送 macOS 系统通知"""
    script = f'display notification "{message}" with title "{title}" sound name "Glass"'
    subprocess.run(["osascript", "-e", script], check=False)


def enable_timer_common_modes(timer, run_loop=None, common_mode=NSRunLoopCommonModes):
    """
    将 rumps.Timer 额外挂到 CommonModes，避免菜单展开时计时器暂停。

    返回 True 表示挂载成功，False 表示当前环境不支持或挂载失败。
    """
    if NSRunLoop is None or common_mode is None:
        return False
    ns_timer = getattr(timer, "_nstimer", None)
    if ns_timer is None:
        return False
    if run_loop is None:
        run_loop = NSRunLoop.currentRunLoop()
    try:
        run_loop.addTimer_forMode_(ns_timer, common_mode)
    except Exception:
        return False
    return True


class GetUpApp(rumps.App):
    def __init__(self):
        super().__init__("🪑", quit_button=None)
        self.interval_minutes = 45  # 默认 45 分钟
        self.enabled = True
        self.start_time = time.time()
        self.water_enabled = True
        self.water_interval_minutes = DEFAULT_WATER_INTERVAL_MINUTES
        self.water_start_time = time.time()

        # 主计时器：到时提醒
        self.remind_timer = rumps.Timer(self._on_remind, self.interval_minutes * 60)
        self.remind_timer.start()
        enable_timer_common_modes(self.remind_timer)

        # 喝水计时器：到时提醒
        self.water_timer = rumps.Timer(
            self._on_water_remind, self.water_interval_minutes * 60
        )
        self.water_timer.start()
        enable_timer_common_modes(self.water_timer)

        self._build_menu()

        # 倒计时刷新器：每秒更新菜单显示
        self.ticker = rumps.Timer(self._update_countdown, 1)
        self.ticker.start()
        enable_timer_common_modes(self.ticker)

    # ------------------------------------------------------------------
    # 菜单构建
    # ------------------------------------------------------------------
    def _build_menu(self):
        self.menu.clear()

        # 开关
        toggle_title = (
            "⏸ 暂停提醒（当前已开启）"
            if self.enabled
            else "▶️ 开始提醒（当前已暂停）"
        )
        self.menu.add(rumps.MenuItem(toggle_title, callback=self.toggle_enabled))
        self.menu.add(rumps.separator)

        # 时间间隔子菜单
        interval_menu = rumps.MenuItem("⏱ 提醒间隔")
        for mins in INTERVAL_OPTIONS:
            label = f"{'✓ ' if mins == self.interval_minutes else '  '}{mins} 分钟"
            item = rumps.MenuItem(label, callback=self.set_interval)
            item._minutes = mins
            interval_menu.add(item)
        custom_label = f"{'✓ ' if self.interval_minutes not in INTERVAL_OPTIONS else '  '}自定义..."
        interval_menu.add(rumps.MenuItem(custom_label, callback=self.set_custom_interval))
        self.menu.add(interval_menu)
        self.menu.add(rumps.separator)

        # 喝水提醒开关
        water_toggle_title = (
            "💧 关闭喝水提醒（当前已开启）"
            if self.water_enabled
            else "💧 开启喝水提醒（当前已关闭）"
        )
        self.menu.add(rumps.MenuItem(water_toggle_title, callback=self.toggle_water_enabled))

        # 喝水时间间隔子菜单
        water_interval_menu = rumps.MenuItem("💧 喝水提醒间隔")
        for mins in WATER_INTERVAL_OPTIONS:
            label = f"{'✓ ' if mins == self.water_interval_minutes else '  '}{mins} 分钟"
            item = rumps.MenuItem(label, callback=self.set_water_interval)
            item._minutes = mins
            water_interval_menu.add(item)
        water_custom_label = (
            f"{'✓ ' if self.water_interval_minutes not in WATER_INTERVAL_OPTIONS else '  '}自定义..."
        )
        water_interval_menu.add(
            rumps.MenuItem(water_custom_label, callback=self.set_custom_water_interval)
        )
        self.menu.add(water_interval_menu)
        self.menu.add(rumps.separator)

        # 倒计时状态项（后续由 ticker 动态更新标题）
        self.status_item = rumps.MenuItem("")
        self.status_item.set_callback(None)
        self.menu.add(self.status_item)
        self.water_status_item = rumps.MenuItem("")
        self.water_status_item.set_callback(None)
        self.menu.add(self.water_status_item)
        self.menu.add(rumps.separator)

        # 立即提醒
        self.menu.add(rumps.MenuItem("🔔 现在提醒我站起来", callback=self.remind_now))
        self.menu.add(rumps.MenuItem("💧 现在提醒我喝水", callback=self.remind_water_now))
        self.menu.add(rumps.separator)

        # 退出
        self.menu.add(rumps.MenuItem("退出", callback=self.quit_app))

        # 立即刷新一次倒计时显示
        self._refresh_status()

    # ------------------------------------------------------------------
    # 倒计时刷新
    # ------------------------------------------------------------------
    def _update_countdown(self, _):
        self._refresh_status()

    def _refresh_status(self):
        if not self.enabled:
            self.status_item.title = "⏸ 站立提醒已暂停"
            self.water_status_item.title = "⏸ 喝水提醒已暂停"
            return
        elapsed = time.time() - self.start_time
        remaining = max(0, self.interval_minutes * 60 - elapsed)
        mins = int(remaining // 60)
        secs = int(remaining % 60)
        self.status_item.title = f"⏳ 距下次提醒：{mins:02d}:{secs:02d}"
        if not self.water_enabled:
            self.water_status_item.title = "💧 喝水提醒已关闭"
            return
        water_elapsed = time.time() - self.water_start_time
        water_remaining = max(0, self.water_interval_minutes * 60 - water_elapsed)
        water_mins = int(water_remaining // 60)
        water_secs = int(water_remaining % 60)
        self.water_status_item.title = f"💧 距下次喝水提醒：{water_mins:02d}:{water_secs:02d}"

    # ------------------------------------------------------------------
    # 计时器到时回调
    # ------------------------------------------------------------------
    def _on_remind(self, _=None):
        if not self.enabled:
            return
        elapsed = time.time() - self.start_time
        if not is_reminder_due(elapsed, self.interval_minutes):
            return
        send_notification(
            "⏰ 该站起来了！",
            f"你已久坐 {self.interval_minutes} 分钟，请起来活动 {STAND_DURATION} 分钟！",
        )
        # 提醒触发后自动暂停，等待用户手动点击“开始”进入下一轮
        self.enabled = False
        self.title = "💤"
        self.remind_timer.stop()
        self.water_timer.stop()
        self._build_menu()

    def _on_water_remind(self, _=None):
        if not self.enabled or not self.water_enabled:
            return
        elapsed = time.time() - self.water_start_time
        if not is_reminder_due(elapsed, self.water_interval_minutes):
            return
        send_notification(
            "💧 该喝水了！",
            f"建议现在小口补水约 {WATER_SIP_VOLUME_ML} ml，分次喝更轻松。",
        )
        self.water_start_time = time.time()

    def _reset_timer(self):
        """重置计时器和起始时间"""
        self.start_time = time.time()
        self.remind_timer.stop()
        self.remind_timer.interval = self.interval_minutes * 60
        self.remind_timer.start()
        enable_timer_common_modes(self.remind_timer)

    def _reset_water_timer(self):
        """重置喝水计时器和起始时间"""
        self.water_start_time = time.time()
        self.water_timer.stop()
        self.water_timer.interval = self.water_interval_minutes * 60
        self.water_timer.start()
        enable_timer_common_modes(self.water_timer)

    # ------------------------------------------------------------------
    # 菜单回调
    # ------------------------------------------------------------------
    def toggle_enabled(self, _):
        self.enabled = not self.enabled
        if self.enabled:
            self.title = "🪑"
            self._reset_timer()
            if self.water_enabled:
                self._reset_water_timer()
                send_notification(
                    "起来站站",
                    f"提醒已开启：站立每 {self.interval_minutes} 分钟，喝水每 {self.water_interval_minutes} 分钟",
                )
            else:
                send_notification(
                    "起来站站", f"提醒已开启，每 {self.interval_minutes} 分钟提醒站立一次"
                )
        else:
            self.title = "💤"
            self.remind_timer.stop()
            self.water_timer.stop()
            send_notification("起来站站", "提醒已暂停")
        self._build_menu()

    def set_interval(self, sender):
        self.interval_minutes = sender._minutes
        if self.enabled:
            self._reset_timer()
        self._build_menu()
        send_notification("起来站站", f"提醒间隔已设置为 {self.interval_minutes} 分钟")

    def set_custom_interval(self, _):
        window = rumps.Window(
            message="请输入提醒间隔（分钟）：",
            title="自定义提醒间隔",
            default_text=str(self.interval_minutes),
            ok="确定",
            cancel="取消",
            dimensions=(200, 24),
        )
        response = window.run()
        if response.clicked:
            try:
                mins = int(response.text.strip())
                if mins < 1:
                    raise ValueError
                self.interval_minutes = mins
                if self.enabled:
                    self._reset_timer()
                self._build_menu()
                send_notification("起来站站", f"提醒间隔已设置为 {self.interval_minutes} 分钟")
            except (ValueError, AttributeError):
                rumps.alert("输入无效", "请输入大于 0 的整数")

    def toggle_water_enabled(self, _):
        self.water_enabled = not self.water_enabled
        if self.water_enabled:
            if self.enabled:
                self._reset_water_timer()
            send_notification("起来站站", f"喝水提醒已开启，每 {self.water_interval_minutes} 分钟提醒一次")
        else:
            self.water_timer.stop()
            send_notification("起来站站", "喝水提醒已关闭")
        self._build_menu()

    def set_water_interval(self, sender):
        self.water_interval_minutes = sender._minutes
        if self.enabled and self.water_enabled:
            self._reset_water_timer()
        self._build_menu()
        send_notification("起来站站", f"喝水提醒间隔已设置为 {self.water_interval_minutes} 分钟")

    def set_custom_water_interval(self, _):
        window = rumps.Window(
            message="请输入喝水提醒间隔（分钟）：",
            title="自定义喝水提醒间隔",
            default_text=str(self.water_interval_minutes),
            ok="确定",
            cancel="取消",
            dimensions=(200, 24),
        )
        response = window.run()
        if response.clicked:
            try:
                mins = int(response.text.strip())
                if mins < 1:
                    raise ValueError
                self.water_interval_minutes = mins
                if self.enabled and self.water_enabled:
                    self._reset_water_timer()
                self._build_menu()
                send_notification(
                    "起来站站", f"喝水提醒间隔已设置为 {self.water_interval_minutes} 分钟"
                )
            except (ValueError, AttributeError):
                rumps.alert("输入无效", "请输入大于 0 的整数")

    def remind_now(self, _):
        send_notification(
            "⏰ 该站起来了！",
            f"请起来活动 {STAND_DURATION} 分钟！",
        )
        if self.enabled:
            self._reset_timer()

    def remind_water_now(self, _):
        send_notification(
            "💧 该喝水了！",
            f"建议现在小口补水约 {WATER_SIP_VOLUME_ML} ml。",
        )
        if self.enabled and self.water_enabled:
            self._reset_water_timer()

    def quit_app(self, _):
        rumps.quit_application()


if __name__ == "__main__":
    app = GetUpApp()
    app.run()
