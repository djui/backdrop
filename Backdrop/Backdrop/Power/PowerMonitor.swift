import Combine
import Foundation
import IOKit.ps

/// Publishes battery AC/on-battery state and Low Power Mode.
@MainActor
final class PowerMonitor: ObservableObject {
    @Published private(set) var isOnBattery: Bool = false
    @Published private(set) var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var pollTimer: Timer?

    init() {
        refreshPowerSource()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateDidChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        // Poll power source on the main actor to avoid Swift 6 isolation issues with IOKit callbacks.
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshPowerSource()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    @objc private func powerStateDidChange() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func refreshPowerSource() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            isOnBattery = false
            return
        }

        var onBattery = false
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
            else { continue }
            let state = info[kIOPSPowerSourceStateKey] as? String
            if state == kIOPSBatteryPowerValue {
                onBattery = true
                break
            }
        }
        isOnBattery = onBattery
    }
}
