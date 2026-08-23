import Foundation

/// App flow state machine — port of `src/lib/reboot-store.ts`.
/// Persisted to `UserDefaults` under `reboot.state.v1` with the same JSON shape.
@MainActor
final class AppState: ObservableObject {
    enum Phase: String, Codable {
        case cinematic
        case dissolve
        case diagnosis
        case report
        case today
    }

    @Published var phase: Phase
    @Published var screen: Int
    @Published var step: Int
    @Published var answers: Answers

    private static let storageKey = "reboot.state.v1"
    /// Production domain key scrubbed on QA launches (see init).
    private static let qaLegacyKey = "reboot.state.v1"
    #if DEBUG
    private var watchTimer: Timer?
    /// QA runs read/write an ephemeral scratch domain instead of production
    /// defaults, mirroring ProductStore isolation. Nothing a QA run writes can
    /// survive into a normal launch.
    private var isQADiverted = false
    private var qaDefaults: UserDefaults?
    #endif

    init() {
        let initial = AppState.load()
        phase = initial.phase
        screen = initial.screen
        step = initial.step
        answers = initial.answers
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-qa") }) {
            isQADiverted = true
            qaDefaults = UserDefaults(suiteName: "reboot.qa.appstate.\(UUID().uuidString)")
            // Scrub any legacy QA state left in the production domain by older
            // builds so the next NORMAL launch starts clean at first launch.
            UserDefaults.standard.removeObject(forKey: Self.qaLegacyKey)
        }
        #endif
        startQaWatchIfNeeded()
    }

    // MARK: - Mutations

    func patch(phase: Phase? = nil, screen: Int? = nil, step: Int? = nil, answers: Answers? = nil) {
        if let phase { self.phase = phase }
        if let screen { self.screen = screen }
        if let step { self.step = step }
        if let answers { self.answers = answers }
        persist()
    }

    func reset() {
        phase = .cinematic
        screen = 0
        step = 0
        answers = [:]
        persist()
    }

    func advanceCinematic() {
        screen = min(screen + 1, CinematicContent.screens.count - 1)
        persist()
    }

    func backCinematic() {
        screen = max(0, screen - 1)
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        let payload: [String: Any] = [
            "phase": phase.rawValue,
            "screen": screen,
            "step": step,
            "answers": answers,
        ]
#if DEBUG
        if isQADiverted, let qaDefaults {
            qaDefaults.set(payload, forKey: Self.storageKey)
            return
        }
#endif
        UserDefaults.standard.set(payload, forKey: Self.storageKey)
    }

    private static func load() -> (phase: Phase, screen: Int, step: Int, answers: Answers) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-qaToday")
            || ProcessInfo.processInfo.arguments.contains("-qaSeed")
            || ProcessInfo.processInfo.arguments.contains("-qaTab") {
            return (.today, 0, 0, [:])
        }
        // QA state override for simulator screenshot runs: `-qaState <json file path>`.
        if let path = ProcessInfo.processInfo.arguments.valueAfter("-qaState"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let state = decodeState(data, preserveDissolve: true) {
            return state
        }
        #endif
        guard let raw = UserDefaults.standard.dictionary(forKey: storageKey),
              let state = decodeState(raw) else {
            return (.cinematic, 0, 0, [:])
        }
        return state
    }

    nonisolated private static func decodeState(_ raw: [String: Any], preserveDissolve: Bool = false) -> (phase: Phase, screen: Int, step: Int, answers: Answers)? {
        guard let phaseRaw = raw["phase"] as? String else { return nil }
        let phase: Phase
        if preserveDissolve {
            phase = Phase(rawValue: phaseRaw) ?? .cinematic
        } else {
            phase = Phase(rawValue: phaseRaw == "dissolve" ? "diagnosis" : phaseRaw) ?? .cinematic
        }
        let screen = (raw["screen"] as? Int) ?? 0
        let step = (raw["step"] as? Int) ?? 0
        let answers = (raw["answers"] as? [String: [String]]) ?? [:]
        return (phase, screen, step, answers)
    }

    nonisolated private static func decodeState(_ data: Data, preserveDissolve: Bool = false) -> (phase: Phase, screen: Int, step: Int, answers: Answers)? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return decodeState(obj, preserveDissolve: preserveDissolve)
    }

    /// QA harness: `-qaWatch <dir>` polls `<dir>/current.json` and applies it
    /// at runtime, so screenshot runs don't relaunch the app per state.
    /// Development-only: production installs never start the watcher.
    private func startQaWatchIfNeeded() {
        #if DEBUG
        guard let dir = ProcessInfo.processInfo.arguments.valueAfter("-qaWatch") else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("current.json")
        var lastMod: Date?
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let mod = attrs[.modificationDate] as? Date,
                  mod != lastMod else { return }
            lastMod = mod
            guard let data = try? Data(contentsOf: url),
                  let state = Self.decodeState(data, preserveDissolve: true) else { return }
            Task { @MainActor in
                self.phase = state.phase
                self.screen = state.screen
                self.step = state.step
                self.answers = state.answers
            }
        }
        watchTimer?.tolerance = 0.05
        #endif
    }
}

extension Array where Element == String {
    func valueAfter(_ flag: String) -> String? {
        guard let idx = firstIndex(of: flag), idx + 1 < count else { return nil }
        return self[idx + 1]
    }
}
