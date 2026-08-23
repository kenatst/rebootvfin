import Foundation

/// Builds the user-facing whole-app data export (data portability).
/// One JSON document covering every meaningful piece of personal state
/// REBOOT holds. Contains no opaque Screen Time tokens and no StoreKit
/// internals — those are either opaque or Apple-owned.
@MainActor
enum RebootDataExport {

    struct Document: Encodable {
        var formatVersion: Int = 1
        var exportedAt: Date = Date()
        var appVersion: String = AppConfig.appVersion
        var diagnosisAnswers: Answers
        var profile: AttentionProfile
        var program: ProgramState
        var sessions: [SessionRecord]
        var personalRules: [PersonalRule]
        var observations: [EvidenceObservation]
        var personalLab: PersonalLabState
        var fuel: FuelState
        var flow: FlowState
        var digitalEnvironment: DigitalEnvironmentState
        var guidanceDecisions: [GuidanceDecision]
        var weeklyReviews: [WeeklyReviewRecord]
        var operatingManual: AttentionOperatingManual
    }

    /// Builds the export document from the live product state plus the
    /// diagnosis answers held by AppState.
    static func document(product: ProductStore, answers: Answers) -> Document {
        Document(
            diagnosisAnswers: answers,
            profile: product.profile,
            program: product.programState,
            sessions: product.allSessions,
            personalRules: product.personalRules,
            observations: product.observations,
            personalLab: product.labState,
            fuel: product.fuelState,
            flow: product.flowState,
            digitalEnvironment: product.digitalEnvironmentState,
            guidanceDecisions: product.guidanceDecisions,
            weeklyReviews: product.programState.reviews,
            operatingManual: product.operatingManual
        )
    }

    /// Pretty-printed JSON payload of the whole export document.
    static func jsonString(product: ProductStore, answers: Answers) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(document(product: product, answers: answers)),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    /// Writes a timestamped .json file into tmp and returns its URL, ready for
    /// ShareLink. Returns nil only if the document cannot be encoded.
    @discardableResult
    static func writeFile(product: ProductStore, answers: Answers) -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(document(product: product, answers: answers)) else { return nil }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("REBOOT-export-\(stamp).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
