#!/usr/bin/env python3
import time
import unittest
from unittest import mock

from get_up import GetUpApp, enable_timer_common_modes, is_reminder_due


class DummyApp:
    def __init__(self, interval_minutes, start_time, enabled=True):
        self.interval_minutes = interval_minutes
        self.start_time = start_time
        self.enabled = enabled
        self.title = "🪑"
        self.remind_timer = mock.Mock()
        self.menu_rebuilt = False

    def _build_menu(self):
        self.menu_rebuilt = True


class ReminderDueTests(unittest.TestCase):
    def test_not_due_before_interval(self):
        self.assertFalse(is_reminder_due(10, 1))

    def test_due_after_interval(self):
        self.assertTrue(is_reminder_due(61, 1))


class OnRemindTests(unittest.TestCase):
    def test_ignore_early_fire(self):
        app = DummyApp(interval_minutes=45, start_time=time.time())
        with mock.patch("get_up.send_notification") as notify:
            GetUpApp._on_remind(app)
        notify.assert_not_called()

    def test_notify_when_due_and_pause_until_manual_start(self):
        old_start = time.time() - 46 * 60
        app = DummyApp(interval_minutes=45, start_time=old_start)
        with mock.patch("get_up.send_notification") as notify:
            GetUpApp._on_remind(app)
        notify.assert_called_once()
        self.assertEqual(app.start_time, old_start)
        self.assertFalse(app.enabled)
        self.assertEqual(app.title, "💤")
        app.remind_timer.stop.assert_called_once()
        self.assertTrue(app.menu_rebuilt)


class TimerModeTests(unittest.TestCase):
    def test_enable_timer_common_modes_returns_false_when_not_started(self):
        timer = object()
        self.assertFalse(enable_timer_common_modes(timer, run_loop=mock.Mock(), common_mode="common"))

    def test_enable_timer_common_modes_registers_common_mode(self):
        ns_timer = object()
        timer = mock.Mock()
        timer._nstimer = ns_timer
        run_loop = mock.Mock()

        result = enable_timer_common_modes(timer, run_loop=run_loop, common_mode="common")

        self.assertTrue(result)
        run_loop.addTimer_forMode_.assert_called_once_with(ns_timer, "common")


if __name__ == "__main__":
    unittest.main()
