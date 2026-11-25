import Dependencies
import FouleeDomain
import Foundation
import Testing
@testable import Foulee

@Suite("OutingReminderScheduler")
struct OutingReminderSchedulerTests {
    @Test("Reminder time is exactly 10 minutes before window start")
    func reminderTimeLead() {
        let time = OutingReminderScheduler.reminderTime(
            forWindowStart: TimeOfDay(hour: 12, minute: 0)
        )
        #expect(time == TimeOfDay(hour: 11, minute: 50))
    }

    @Test("Reminder time clamps to 00:00 if window start is earlier than the lead")
    func reminderTimeClamp() {
        let time = OutingReminderScheduler.reminderTime(
            forWindowStart: TimeOfDay(hour: 0, minute: 5)
        )
        #expect(time == TimeOfDay(hour: 0, minute: 0))
    }

    @Test("Produces exactly one reminder per active day, sorted Mon → Sun")
    func remindersPerActiveDay() {
        let prefs = UserPreferences(defaults: cleanDefaults())
        prefs.activeDays = [.tuesday, .friday, .monday]
        prefs.walkWindowStart = TimeOfDay(hour: 12, minute: 30)

        let reminders = OutingReminderScheduler.reminders(for: prefs)

        #expect(reminders.map(\.weekday) == [.monday, .tuesday, .friday])
        #expect(reminders.allSatisfy { $0.time == TimeOfDay(hour: 12, minute: 20) })
        #expect(reminders.map(\.identifier).count == Set(reminders.map(\.identifier)).count)
    }

    @Test("Sync sends the computed schedule to the notifications client")
    func syncCallsClient() async {
        let captured = LockedRef<[OutingReminder]>([])
        await withDependencies {
            $0.notifications = NotificationsClient(
                requestAuthorization: { true },
                replaceOutingReminders: { captured.set($0) },
                scheduleSnooze: { _ in }
            )
        } operation: {
            let prefs = UserPreferences(defaults: cleanDefaults())
            prefs.activeDays = [.monday, .wednesday]
            prefs.walkWindowStart = TimeOfDay(hour: 12, minute: 0)

            let scheduler = OutingReminderScheduler()
            await scheduler.sync(with: prefs)

            #expect(captured.value.map(\.weekday) == [.monday, .wednesday])
            #expect(captured.value.allSatisfy { $0.time == TimeOfDay(hour: 11, minute: 50) })
        }
    }

    @Test("Disabling notifications produces an empty schedule")
    func disabledFlagEmptiesSchedule() {
        let prefs = UserPreferences(defaults: cleanDefaults())
        prefs.notificationsEnabled = false
        prefs.activeDays = [.monday, .tuesday]
        #expect(OutingReminderScheduler.reminders(for: prefs).isEmpty)
    }

    @Test("A throwing client is swallowed at the scheduler boundary")
    func syncSwallowsErrors() async {
        nonisolated struct Boom: Error {}
        await withDependencies {
            $0.notifications = NotificationsClient(
                requestAuthorization: { true },
                replaceOutingReminders: { _ in throw Boom() },
                scheduleSnooze: { _ in }
            )
        } operation: {
            let prefs = UserPreferences(defaults: cleanDefaults())
            await OutingReminderScheduler().sync(with: prefs)
            // No assertion needed: the test passes by not propagating.
        }
    }

    @Test("Sync requests notification authorization when reminders are enabled")
    func syncRequestsAuthorizationWhenEnabled() async {
        let requested = LockedRef<Bool>(false)
        await withDependencies {
            $0.notifications = NotificationsClient(
                requestAuthorization: { requested.set(true); return true },
                replaceOutingReminders: { _ in },
                scheduleSnooze: { _ in }
            )
        } operation: {
            let prefs = UserPreferences(defaults: cleanDefaults())
            prefs.notificationsEnabled = true
            await OutingReminderScheduler().sync(with: prefs)
            #expect(requested.value)
        }
    }

    @Test("Sync does not prompt when reminders are disabled")
    func syncSkipsAuthorizationWhenDisabled() async {
        let requested = LockedRef<Bool>(false)
        await withDependencies {
            $0.notifications = NotificationsClient(
                requestAuthorization: { requested.set(true); return true },
                replaceOutingReminders: { _ in },
                scheduleSnooze: { _ in }
            )
        } operation: {
            let prefs = UserPreferences(defaults: cleanDefaults())
            prefs.notificationsEnabled = false
            await OutingReminderScheduler().sync(with: prefs)
            #expect(!requested.value)
        }
    }

    @Test("snooze(after:) forwards the interval to the client and absorbs throws")
    func snoozeForwardsInterval() async {
        let captured = LockedRef<TimeInterval?>(nil)
        await withDependencies {
            $0.notifications = NotificationsClient(
                requestAuthorization: { true },
                replaceOutingReminders: { _ in },
                scheduleSnooze: { interval in captured.set(interval) }
            )
        } operation: {
            await OutingReminderScheduler().snooze(after: 1_800)
            #expect(captured.value == 1_800)
        }
    }

    @Test("snooze swallows scheduling errors")
    func snoozeSwallowsErrors() async {
        nonisolated struct Boom: Error {}
        await withDependencies {
            $0.notifications = NotificationsClient(
                requestAuthorization: { true },
                replaceOutingReminders: { _ in },
                scheduleSnooze: { _ in throw Boom() }
            )
        } operation: {
            await OutingReminderScheduler().snooze(after: 30)
            // Passes by not propagating.
        }
    }

    private func cleanDefaults() -> UserDefaults {
        let suiteName = "foulee-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
