import XCTest
@testable import REBOOT

/// Presentation-layer regression coverage for the visual redesign pass.
/// Guards against raw internal identifiers leaking into user-facing copy and
/// keeps diagnosis/report labels localized in every product language.
@MainActor
final class PresentationRegressionTests: XCTestCase {

    // MARK: - Raw value leak guards

    /// Known internal option values that must never surface as UI text.
    private static let forbiddenRawValues: Set<String> = [
        "focus_better", "deep_work", "scroll_less", "finish_tasks",
        "calmer_phone", "study_better", "read_more", "remember_more",
        "lt5", "5_15", "15_30", "30_60", "usually_60_plus",
        "effortful_return", "quick_return", "drift_elsewhere",
        "check_phone", "open_other", "keep_going_shallow",
        "starting", "staying", "resisting_checking", "returning",
        "notifications", "phone", "social", "tabs", "thoughts", "fatigue",
    ]

    /// Every question, option, hint and unknown label must be a display
    /// string — never a raw internal identifier.
    func testDiagnosisLabelsNeverContainRawIdentifiers() {
        let answers: Answers = [
            "goals": ["deep_work", "remember_more"],
            "primary": ["focus_better"],
            "hardest": ["staying"],
            "breaker": ["phone"],
            "focus_window": ["5_15"],
            "switch_response": ["check_phone"],
            "return_ability": ["effortful_return"],
            "use_case": ["building"],
            "best_time": ["early"],
        ]
        for question in DiagnosisModels.visibleQuestions(answers) {
            XCTAssertFalse(Self.forbiddenRawValues.contains(question.title),
                           "question title leaked raw id: \(question.title)")
            if let hint = question.hint {
                XCTAssertFalse(Self.forbiddenRawValues.contains(hint),
                               "hint leaked raw id: \(hint)")
            }
            for option in DiagnosisModels.optionsFor(question, answers) {
                XCTAssertFalse(
                    Self.forbiddenRawValues.contains(option.label),
                    "option label for '\(question.id)' leaked raw id: \(option.label)")
            }
        }
    }

    /// The starting-point report renders priors through answerLabels — the
    /// exact path that used to print `focus_better`.
    @MainActor
    func testStartingPointPriorsResolveToDisplayLabels() {
        let state = AppState()
        state.patch(
            phase: .report,
            answers: [
                "goals": ["deep_work", "focus_better"],
                "primary": ["focus_better"],
            ]
        )
        // Simulate what StartingPointView computes for its headline:
        let labels = DiagnosisModels.answerLabels("primary", state.answers)
        XCTAssertEqual(labels.first, L("Stay with one thing"),
                       "primary prior must render through the localized goal label")
        XCTAssertFalse(labels.first == "focus_better")
    }

    /// The conditional primary question only exists after multi-goal selection,
    /// so counters derived from visibleQuestions are stable and complete.
    func testVisibleQuestionCountMatchesFlow() {
        XCTAssertEqual(DiagnosisModels.visibleQuestions([:]).count, 8)
        var answers: Answers = [:]
        // After goals (multi) is answered with 2+ picks, primary appears → 9.
        answers["goals"] = ["deep_work", "scroll_less"]
        let withPrimary = DiagnosisModels.visibleQuestions(answers)
        XCTAssertEqual(withPrimary.count, 9)
        XCTAssertTrue(withPrimary.contains { $0.id == "primary" })
        // A single goal never shows the conditional question.
        answers["goals"] = ["deep_work"]
        XCTAssertEqual(DiagnosisModels.visibleQuestions(answers).count, 8)
    }

    /// Localized catalogs carry every language for keys added by the redesign.
    func testRedesignStringsLocalizedInAllLanguages() throws {
        let languages = ["fr", "es", "de", "it"]
        let requiredKeys = [
            "%d of %d",
            "Select to continue",
            "WHAT YOU WANT",
            "STARTING HYPOTHESES",
            "WHAT REBOOT WILL MEASURE",
            "TODAY'S SUGGESTION",
            "RECENT PATTERN",
            "See what REBOOT noticed",
            "Create your first project",
        ]
        // The compiled .loctable/.strings live in the app bundle's lproj
        // folders; the xcstrings source is compiled at build time, so assert
        // against the RUNTIME representation instead: NSLocalizedString must
        // resolve each key in the current (en) locale and differ per language
        // via explicit lookups of the compiled tables.
        // BundleToken lives in the test bundle; the app resources ship in the
        // host application bundle loaded by the test runner.
        let bundle = Bundle(identifier: "com.kenatst.reboot") ?? .main
        for language in languages {
            guard let lprojPath = bundle.path(forResource: language, ofType: "lproj"),
                  let lproj = Bundle(path: lprojPath) else {
                return XCTFail("missing compiled \(language).lproj in app bundle")
            }
            // Strings tables may be compiled to binary plists; load through
            // PropertyListSerialization which handles every representation.
            guard let stringsPath = lproj.path(forResource: "Localizable", ofType: "strings"),
                  let data = FileManager.default.contents(atPath: stringsPath),
                  let table = try? PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil) as? [String: String] else {
                return XCTFail("unreadable Localizable.strings for \(language)")
            }
            for key in requiredKeys {
                XCTAssertNotNil(table[key], "\(language) table missing key: \(key)")
            }
        }
    }
}

/// Access to the app bundle from the test target.
private final class BundleToken {}
