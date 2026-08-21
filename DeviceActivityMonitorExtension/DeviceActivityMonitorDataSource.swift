import DeviceActivity
import Foundation

/// Minimal monitor: only records OUR OWN event names (never Apple activity
/// tokens) into the shared app-group container.
final class DeviceActivityMonitorDataSource: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        let record = MonitorEventRecord(name: event.rawValue, date: Date())
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.kenatst.reboot")?
            .appendingPathComponent("threshold-events.json")
        append(record, to: url)
    }

    private func append(_ record: MonitorEventRecord, to url: URL?) {
        guard let url else { return }
        var list: [MonitorEventRecord] = []
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONDecoder().decode([MonitorEventRecord].self, from: data) {
            list = existing
        }
        list.append(record)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// Same coding shape as the app-side `ThresholdEventRecord`.
struct MonitorEventRecord: Codable {
    var name: String
    var date: Date
}
