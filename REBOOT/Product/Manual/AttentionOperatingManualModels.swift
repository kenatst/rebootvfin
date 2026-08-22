import Foundation

// MARK: - Manual Maturity Level

enum ManualMaturity: String, Codable, Equatable {
    case learning = "learning"
    case emergingSignal = "emerging"
    case repeatedSignal = "established"
    case mixed = "mixed"

    var displayLabel: String {
        switch self {
        case .learning: return "Still Learning"
        case .emergingSignal: return "Emerging Pattern"
        case .repeatedSignal: return "Established"
        case .mixed: return "Mixed Evidence"
        }
    }
}

// MARK: - Operating Manual Item

struct ManualItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var sectionTitle: String
    var statement: String
    var maturity: ManualMaturity
    var evidenceSource: String
    var observationCount: Int?
    var lastUpdated: Date = Date()
}

// MARK: - Attention Operating Manual

struct AttentionOperatingManual: Codable, Equatable {
    var generatedAt: Date = Date()
    var lastUpdated: Date = Date()
    var totalProtocolDays: Int
    var totalSessions: Int

    var howIStartBest: ManualItem
    var myMostCommonBreakers: ManualItem
    var myReturnStrategy: ManualItem
    var myFocusWindow: ManualItem
    var myDigitalEnvironment: ManualItem
    var myDeepWorkConditions: ManualItem
    var myRecallStrategy: ManualItem
    var myEnergyAndContext: ManualItem
    var myFlowConditions: ManualItem
    var myPersonalRules: [ManualItem]
    var whatRebootStillDoesNotKnow: [ManualItem]

    func exportAsText() -> String {
        var text = """
        ====================================================
        REBOOT — ATTENTION OPERATING MANUAL
        Generated: \(formattedDate(generatedAt)) | Last Updated: \(formattedDate(lastUpdated))
        Total Protocol Days Completed: \(totalProtocolDays) | Sessions: \(totalSessions)
        ====================================================

        1. HOW I START BEST
        [\(howIStartBest.maturity.displayLabel.uppercased())] \(howIStartBest.statement)
        Evidence: \(howIStartBest.evidenceSource) (n=\(howIStartBest.observationCount ?? 0))

        2. MY MOST COMMON BREAKERS
        [\(myMostCommonBreakers.maturity.displayLabel.uppercased())] \(myMostCommonBreakers.statement)
        Evidence: \(myMostCommonBreakers.evidenceSource) (n=\(myMostCommonBreakers.observationCount ?? 0))

        3. MY RETURN STRATEGY
        [\(myReturnStrategy.maturity.displayLabel.uppercased())] \(myReturnStrategy.statement)
        Evidence: \(myReturnStrategy.evidenceSource) (n=\(myReturnStrategy.observationCount ?? 0))

        4. MY FOCUS WINDOW
        [\(myFocusWindow.maturity.displayLabel.uppercased())] \(myFocusWindow.statement)
        Evidence: \(myFocusWindow.evidenceSource) (n=\(myFocusWindow.observationCount ?? 0))

        5. MY DIGITAL ENVIRONMENT
        [\(myDigitalEnvironment.maturity.displayLabel.uppercased())] \(myDigitalEnvironment.statement)
        Evidence: \(myDigitalEnvironment.evidenceSource) (n=\(myDigitalEnvironment.observationCount ?? 0))

        6. MY DEEP-WORK CONDITIONS
        [\(myDeepWorkConditions.maturity.displayLabel.uppercased())] \(myDeepWorkConditions.statement)
        Evidence: \(myDeepWorkConditions.evidenceSource) (n=\(myDeepWorkConditions.observationCount ?? 0))

        7. MY RECALL STRATEGY
        [\(myRecallStrategy.maturity.displayLabel.uppercased())] \(myRecallStrategy.statement)
        Evidence: \(myRecallStrategy.evidenceSource) (n=\(myRecallStrategy.observationCount ?? 0))

        8. MY ENERGY & CONTEXT
        [\(myEnergyAndContext.maturity.displayLabel.uppercased())] \(myEnergyAndContext.statement)
        Evidence: \(myEnergyAndContext.evidenceSource) (n=\(myEnergyAndContext.observationCount ?? 0))

        9. MY FLOW CONDITIONS
        [\(myFlowConditions.maturity.displayLabel.uppercased())] \(myFlowConditions.statement)
        Evidence: \(myFlowConditions.evidenceSource) (n=\(myFlowConditions.observationCount ?? 0))

        10. MY PERSONAL RULES
        """

        if myPersonalRules.isEmpty {
            text += "\nNo personal rules kept yet."
        } else {
            for rule in myPersonalRules {
                text += "\n• [\(rule.maturity.displayLabel.uppercased())] \(rule.statement) — \(rule.evidenceSource)"
            }
        }

        text += "\n\n11. WHAT REBOOT STILL DOESN'T KNOW\n"
        if whatRebootStillDoesNotKnow.isEmpty {
            text += "All core dimensions have observable evidence."
        } else {
            for unknown in whatRebootStillDoesNotKnow {
                text += "• \(unknown.statement) (\(unknown.evidenceSource))\n"
            }
        }

        text += "\n====================================================\n"
        return text
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
