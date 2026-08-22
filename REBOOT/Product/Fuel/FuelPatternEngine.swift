import Foundation

// MARK: - Pattern maturity (qualitative only, no percentages)

enum FuelPatternMaturity: String, Codable, Equatable {
    /// One compatible observation — never surfaced as a pattern.
    case learning
    /// Two compatible observations.
    case earlySignal
    /// Three or more compatible observations.
    case repeatedSignal
    /// Enough supporting and contradicting evidence to say "mixed recently".
    case mixed

    var label: String {
        switch self {
        case .learning: return "Learning"
        case .earlySignal: return "Early signal"
        case .repeatedSignal: return "Repeated signal"
        case .mixed: return "Mixed recently"
        }
    }
}

/// An observational association between a Fuel context dimension and a
/// session outcome. Association language only — never causation, never advice.
struct FuelPattern: Identifiable, Equatable {
    var id: String
    var dimension: FuelContextField
    var dimensionLabel: String
    var maturity: FuelPatternMaturity
    var statement: String
    var supportingSessions: Int
    var contradictingSessions: Int
    var knownSessions: Int
    var sessionIDs: [UUID]
    /// Personal Lab test that could genuinely resolve this question, when one
    /// is actually executable. Nil means observation only.
    var suggestsTestTemplateID: String?
    /// Whether this pattern answers the open question for its dimension.
    /// Timestamp-derived patterns (daypart) do not answer e.g. the energy
    /// question, so they must not hide it.
    var claimsDimensionForQuestions: Bool = true
}

/// An unresolved Fuel question with too little evidence to say anything.
struct FuelOpenQuestion: Identifiable, Equatable {
    var id: String { dimension.rawValue }
    var dimension: FuelContextField
    var question: String
    var knownSessions: Int
}

// MARK: - Deterministic observational pattern engine

/// Evaluates candidate context ↔ outcome relationships over completed
/// sessions that carry Fuel context. Uses only compatible observations,
/// counts contradictions honestly, and never manufactures a conclusion.
enum FuelPatternEngine {
    /// Most recent sessions considered, so old evidence fades naturally.
    static let windowSize = 20
    /// A pattern never surfaces from a single observation.
    static let minimumSupporting = 2

    static func evaluate(sessions: [SessionRecord]) -> (patterns: [FuelPattern], openQuestions: [FuelOpenQuestion]) {
        let relevant = sessions
            .filter { $0.completed && $0.fuelContext != nil && !$0.fuelContext!.isEmpty }
            .suffix(windowSize)

        var patterns: [FuelPattern?] = []
        patterns.append(energyDifficultyPattern(relevant))
        patterns.append(energyCompletionPattern(relevant))
        patterns.append(sleepEasierPattern(relevant))
        patterns.append(morningSteadierPattern(relevant))
        patterns.append(walkStartEasePattern(relevant))
        patterns.append(noInputBreakReturnPattern(relevant))
        patterns.append(caffeineContextPattern(relevant))
        let surfaced = patterns.compactMap { $0 }

        let open = openQuestions(sessions: Array(relevant), surfaced: surfaced)
        return (surfaced, open)
    }

    // MARK: Energy ↔ difficulty

    private static func energyDifficultyPattern(_ sessions: ArraySlice<SessionRecord>) -> FuelPattern? {
        let low = sessions.filter { $0.fuelContext?.energy == .low }
        let hard = low.filter { ($0.difficulty ?? 0) >= 4 }
        let easy = low.filter { ($0.difficulty ?? 0) <= 2 }
        guard hard.count >= minimumSupporting, hard.count > easy.count else { return nil }
        return makePattern(
            id: "energy.difficulty",
            dimension: .energy,
            statement: "Low-energy sessions have recently felt harder.",
            supporting: hard,
            contradicting: easy,
            known: low.filter { $0.difficulty != nil }
        )
    }

    // MARK: Energy ↔ completion

    private static func energyCompletionPattern(_ sessions: ArraySlice<SessionRecord>) -> FuelPattern? {
        let low = sessions.filter { $0.fuelContext?.energy == .low }
        let incomplete = low.filter { !$0.completed || $0.endedEarly }
        // Completion is only interesting when low energy keeps showing up with
        // unfinished sessions against a backdrop of finishing other sessions
        // where energy was actually reported.
        let others = sessions.filter {
            guard let energy = $0.fuelContext?.energy else { return false }
            return energy != .low
        }
        guard incomplete.count >= minimumSupporting,
              incomplete.count > low.count - incomplete.count,
              others.filter(\.completed).count >= 2 else { return nil }
        return makePattern(
            id: "energy.completion",
            dimension: .energy,
            statement: "Sessions started with low energy have recently been the ones left unfinished.",
            supporting: incomplete,
            contradicting: low.filter { $0.completed && !$0.endedEarly },
            known: low
        )
    }

    // MARK: Sleep ↔ felt easier (observational only)

    private static func sleepEasierPattern(_ sessions: ArraySlice<SessionRecord>) -> FuelPattern? {
        let good = sessions.filter { $0.fuelContext?.sleepQuality == .good }
        let easy = good.filter { ($0.difficulty ?? 0) <= 2 }
        let hard = good.filter { ($0.difficulty ?? 0) >= 4 }
        guard easy.count >= minimumSupporting, easy.count > hard.count else { return nil }
        return makePattern(
            id: "sleep.easier",
            dimension: .sleepQuality,
            statement: "Your recent sessions after better-reported sleep have tended to feel easier.",
            supporting: easy,
            contradicting: hard,
            known: good.filter { $0.difficulty != nil }
        )
    }

    // MARK: Daypart ↔ switches

    private static func morningSteadierPattern(_ sessions: ArraySlice<SessionRecord>) -> FuelPattern? {
        let withSwitches = sessions.filter { $0.mode == .stay && $0.switches != nil }
        let morning = withSwitches.filter { $0.fuelContext?.daypart == .morning }
        let afternoon = withSwitches.filter { $0.fuelContext?.daypart == .afternoon }
        let morningSteady = morning.filter { ($0.switches ?? 0) <= 2 }
        let morningRough = morning.filter { ($0.switches ?? 0) >= 4 }
        let afternoonRough = afternoon.filter { ($0.switches ?? 0) >= 3 }
        guard morningSteady.count >= minimumSupporting,
              morningSteady.count > morningRough.count,
              afternoonRough.count >= 1 || morningSteady.count >= 3 else { return nil }
        return makePattern(
            id: "daypart.morning.switches",
            dimension: .energy, // grouped under energy & context for display
            statement: "Your recent demanding sessions before noon have involved fewer reported switches.",
            supporting: morningSteady,
            contradicting: morningRough,
            known: morning + afternoon,
            claimsDimension: false // a timestamp-derived signal does not answer the energy question
        )
    }

    // MARK: Movement (short walk) ↔ start ease

    private static func walkStartEasePattern(_ sessions: ArraySlice<SessionRecord>) -> FuelPattern? {
        let walk = sessions.filter { $0.fuelContext?.movement == .shortWalkBefore }
        let easier = walk.filter { $0.startedEasierSelfReport == true || $0.environment?.startedEasierSelfReport == true }
        guard easier.count >= minimumSupporting else { return nil }
        let harder = walk.filter { $0.startedEasierSelfReport == false }
        guard easier.count > harder.count else { return nil }
        return makePattern(
            id: "movement.startease",
            dimension: .movement,
            statement: "Starting has recently felt easier after a short walk.",
            supporting: easier,
            contradicting: harder,
            known: walk,
            suggestsTest: ExperimentTemplateLibrary.shortWalkBeforeFocus.id
        )
    }

    // MARK: No-input break ↔ returning ease

    private static func noInputBreakReturnPattern(_ sessions: ArraySlice<SessionRecord>) -> FuelPattern? {
        let returning = sessions.filter { $0.fuelContext?.breakState == .returningFromBreak }
        let noInput = returning.filter { $0.fuelContext?.breakType == .noInput }
        let easier = noInput.filter { $0.startedEasierSelfReport == true || $0.environment?.startedEasierSelfReport == true }
        guard easier.count >= minimumSupporting else { return nil }
        let harder = noInput.filter { $0.startedEasierSelfReport == false }
        guard easier.count > harder.count else { return nil }
        return makePattern(
            id: "break.noinput.return",
            dimension: .breakType,
            statement: "Returning after a no-input break has recently felt easier.",
            supporting: easier,
            contradicting: harder,
            known: noInput,
            suggestsTest: ExperimentTemplateLibrary.noInputBreak.id
        )
    }

    // MARK: Caffeine ↔ outcome (needs more evidence, observational only)

    private static func caffeineContextPattern(_ sessions: ArraySlice<SessionRecord>) -> FuelPattern? {
        let recent = sessions.filter { $0.fuelContext?.caffeineRecency == .recently }
        let smooth = recent.filter { ($0.difficulty ?? 0) <= 2 }
        let hard = recent.filter { ($0.difficulty ?? 0) >= 4 }
        // Caffeine language stays strictly observational and needs extra evidence.
        guard smooth.count >= 3, smooth.count > hard.count else { return nil }
        return makePattern(
            id: "caffeine.context",
            dimension: .caffeineRecency,
            statement: "Sessions started soon after caffeine have recently felt manageable.",
            supporting: smooth,
            contradicting: hard,
            known: recent.filter { $0.difficulty != nil }
        )
    }

    // MARK: Open questions

    private static func openQuestions(sessions: [SessionRecord], surfaced: [FuelPattern]) -> [FuelOpenQuestion] {
        let surfacedDimensions = Set(surfaced.filter(\.claimsDimensionForQuestions).map(\.dimension))
        var questions: [FuelOpenQuestion] = []
        for field in FuelContextField.allCases where !surfacedDimensions.contains(field) {
            let known = sessions.filter { $0.fuelContext?.value(for: field) != nil }.count
            let question: String
            switch field {
            case .mealTiming: question = "No stable meal-timing pattern yet."
            case .sleepQuality: question = "How sleep relates to your sessions is still unclear."
            case .energy: question = "How energy relates to your sessions is still unclear."
            case .caffeineRecency: question = "Caffeine timing remains unclear."
            case .movement: question = "Whether movement before focus changes anything is still unclear."
            case .breakState, .breakType: question = "Which breaks help you return is still unclear."
            case .sleepDurationBand: question = "Sleep length is not tracked enough yet."
            case .satiety: question = "Fullness is not tracked enough yet."
            case .hydrationFeeling: question = "Hydration is not tracked enough yet."
            case .taskContext: question = "Which task types feel steadier is still unclear."
            }
            if known == 0 || known < minimumSupporting {
                questions.append(FuelOpenQuestion(dimension: field, question: question, knownSessions: known))
            }
        }
        return Array(questions.prefix(4))
    }

    // MARK: Helpers

    private static func makePattern(
        id: String,
        dimension: FuelContextField,
        statement: String,
        supporting: [SessionRecord],
        contradicting: [SessionRecord],
        known: [SessionRecord],
        suggestsTest: String? = nil,
        claimsDimension: Bool = true
    ) -> FuelPattern {
        let maturity: FuelPatternMaturity
        if contradicting.count >= 2 && supporting.count >= 2 {
            maturity = .mixed
        } else if supporting.count >= 3 {
            maturity = .repeatedSignal
        } else {
            maturity = .earlySignal
        }
        var pattern = FuelPattern(
            id: id,
            dimension: dimension,
            dimensionLabel: dimension.label,
            maturity: maturity,
            statement: statement,
            supportingSessions: supporting.count,
            contradictingSessions: contradicting.count,
            knownSessions: known.count,
            sessionIDs: (supporting + contradicting).map(\.id),
            suggestsTestTemplateID: maturity == .mixed ? nil : suggestsTest,
            claimsDimensionForQuestions: claimsDimension
        )
        if maturity == .mixed {
            pattern.statement = "The evidence here is mixed recently — no stable pattern yet."
        }
        return pattern
    }
}
