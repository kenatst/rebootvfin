import SwiftUI

// MARK: - Shared preparation

struct SessionPreparationView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    let request: TrainingSessionRequest

    @State private var task: String
    @State private var completionDefinition: String
    @State private var source: String
    @State private var topic: String
    @State private var duration: Int
    @State private var mission: String
    @State private var useProtection = false
    @State private var conditionConfirmed = false

    init(product: ProductStore, environmentStore: EnvironmentStore, request: TrainingSessionRequest) {
        self.product = product
        self.environmentStore = environmentStore
        self.request = request
        _task = State(initialValue: request.task ?? "")
        _completionDefinition = State(initialValue: request.completionDefinition ?? "")
        _source = State(initialValue: request.source ?? "")
        _topic = State(initialValue: request.topic ?? "")
        _duration = State(initialValue: request.targetMinutes)
        _mission = State(initialValue: request.observationMission ?? ObservationMission.all[0])
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        closeButton
                        MetaLabel(text: request.mode.rawValue, color: AppColors.coral)
                            .padding(.top, 22)
                        EditorialHeadline(text: title)
                            .padding(.top, 14)
                        Text(request.mode.trains, style: .todaySentence)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 12)

                        if request.experimentParticipation != nil {
                            experimentPreparation
                                .padding(.top, 24)
                        }

                        modePreparation
                            .padding(.top, 30)

                        if request.origin == .freeTraining {
                            durationPicker
                                .padding(.top, 26)
                            optionalProtection
                                .padding(.top, 22)
                        }

                        PrimaryPillButton(
                            title: startTitle,
                            symbol: "play.fill",
                            isEnabled: canStart
                        ) {
                            start()
                        }
                        .padding(.top, 30)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(18, geo.safeAreaInsets.top))
                    .padding(.bottom, max(36, geo.safeAreaInsets.bottom) + 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
    }

    private var closeButton: some View {
        Button { product.cancelPreparation() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.ink)
                .frame(width: 44, height: 44)
                .background(AppColors.paperRaised.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("Close session preparation")
    }

    private var title: String {
        switch request.mode {
        case .stay: return "What are you staying with?"
        case .recall: return "What do you want to remember?"
        case .explain: return "What are you learning?"
        case .nothing: return "For a few minutes, add nothing."
        case .observe:
            if request.origin == .protocol, request.programDay == 1 { return "Work normally." }
            return request.origin == .protocol ? "Notice one real condition." : "Choose what to notice."
        }
    }

    @ViewBuilder
    private var modePreparation: some View {
        switch request.mode {
        case .stay:
            VStack(alignment: .leading, spacing: 14) {
                editorialField("One short task", text: $task, prompt: "Finish chapter 3")
                editorialField("What does done look like? (optional)", text: $completionDefinition, prompt: "A clear stopping point")
            }
        case .recall:
            editorialEditor(
                "Paste or type your material",
                text: $source,
                prompt: "Your notes or a short passage",
                minHeight: 220
            )
        case .explain:
            VStack(alignment: .leading, spacing: 14) {
                editorialField("Topic", text: $topic, prompt: "The idea you are learning")
                editorialEditor(
                    "Notes or source (optional)",
                    text: $source,
                    prompt: "Material you want to review first",
                    minHeight: 180
                )
            }
        case .nothing:
            PaperCard(radius: 26, padding: 20) {
                Text("Sit, stand or walk slowly. No new input.", style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
            }
        case .observe:
            if request.origin == .protocol {
                PaperCard(radius: 26, padding: 20) {
                    Text(
                        request.observationMission
                            ?? (request.programDay == 1
                                ? "Do one normal focus block. Nothing about your environment needs to change."
                                : "Notice what happens just before attention changes direction."),
                        style: .heroGoal
                    )
                        .foregroundStyle(AppColors.ink)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(ObservationMission.all, id: \.self) { item in
                        Button { mission = item } label: {
                            HStack(spacing: 12) {
                                Text(item, style: .heroReason)
                                    .foregroundStyle(AppColors.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: mission == item ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(mission == item ? AppColors.coral : AppColors.inkFaint)
                            }
                            .padding(18)
                            .background(AppColors.paperRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel(text: "Duration")
            FlowLayout(spacing: 8) {
                ForEach(request.mode.freeDurations, id: \.self) { minutes in
                    TonalPillButton(title: "\(minutes) min", isSelected: duration == minutes) {
                        duration = minutes
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var optionalProtection: some View {
        if request.experimentParticipation == nil,
           request.mode != .nothing,
           environmentStore.isConnected,
           environmentStore.selection != nil {
            PaperCard(radius: 24, padding: 18) {
                Toggle(isOn: $useProtection) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Protect this practice", style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Text("Optional. Your selected activities can wait.", style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                }
                .tint(AppColors.coral)
            }
        }
    }

    private var canStart: Bool {
        if let participation = request.experimentParticipation {
            guard conditionConfirmed else { return false }
            if participation.conditionSnapshot.requestedConditionID == "finish_line.clear",
               completionDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }
        switch request.mode {
        case .stay: return !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .recall: return !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .explain: return !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .nothing, .observe: return true
        }
    }

    private var startTitle: String {
        if request.experimentParticipation != nil { return "I'm ready" }
        return request.origin == .protocol ? "Start today's session" : "Start practice"
    }

    @ViewBuilder
    private var experimentPreparation: some View {
        if let participation = request.experimentParticipation {
            PaperCard(radius: 26, padding: 20, shadow: .soft) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        MetaLabel(text: "Today's test condition", color: AppColors.coral)
                        Spacer()
                        GlassPill(text: participation.armKind.displayLabel, tint: AppColors.ink)
                    }
                    Text(participation.conditionSnapshot.requestedTitle, style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                    Text(participation.conditionSnapshot.requestedDetail, style: .heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                    Text("Everything else stays as normal as possible.", style: .footnote)
                        .foregroundStyle(AppColors.inkFaint)

                    Button {
                        conditionConfirmed.toggle()
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: conditionConfirmed ? "checkmark.circle.fill" : "circle")
                            Text(conditionConfirmed ? "Condition ready" : "Confirm setup")
                                .type(.buttonLabel)
                            Spacer()
                        }
                        .foregroundStyle(conditionConfirmed ? AppColors.coral : AppColors.ink)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("\(participation.armKind.displayLabel) condition. \(participation.conditionSnapshot.requestedTitle)")
                    .accessibilityValue(conditionConfirmed ? "Ready" : "Not confirmed")
                }
            }
        }
    }

    private func start() {
        var updated = request
        updated.targetMinutes = duration
        updated.task = task.nilIfBlank
        updated.completionDefinition = completionDefinition.nilIfBlank
        updated.source = source.nilIfBlank
        updated.topic = topic.nilIfBlank
        updated.observationMission = request.origin == .protocol ? request.observationMission : mission

        var arm: SessionEnvironmentArm?
        if var participation = updated.experimentParticipation {
            let conditionID = participation.conditionSnapshot.requestedConditionID
            if conditionID == "screen_time.protected" {
                let applied = environmentStore.applySessionProtection()
                participation.conditionSnapshot.actualDescription = applied
                    ? "Selected distractions were protected."
                    : "Protection could not be applied."
                participation.conditionSnapshot.truthSource = applied ? .systemConfirmed : .notConfirmed
                participation.conditionSnapshot.conditionFollowed = applied
                arm = SessionEnvironmentArm(
                    condition: .protected,
                    manualIntervention: nil,
                    protectedSelectionID: environmentStore.selection?.id,
                    protectionOffered: true,
                    protectionAccepted: true,
                    protectionActivated: applied,
                    phoneLocationSelfReport: nil
                )
            } else if conditionID == "screen_time.unprotected" {
                let protectionActive = environmentStore.hasActiveProtectionNow
                participation.conditionSnapshot.actualDescription = protectionActive
                    ? "A protected window was already active."
                    : "No session protection was active."
                participation.conditionSnapshot.truthSource = .systemConfirmed
                participation.conditionSnapshot.conditionFollowed = !protectionActive
                if protectionActive {
                    arm = SessionEnvironmentArm(
                        condition: .protectedWindow,
                        manualIntervention: nil,
                        protectedSelectionID: environmentStore.selection?.id,
                        protectionOffered: false,
                        protectionAccepted: false,
                        protectionActivated: true,
                        phoneLocationSelfReport: nil
                    )
                }
            } else {
                participation.conditionSnapshot.actualDescription = participation.conditionSnapshot.requestedDetail
                participation.conditionSnapshot.truthSource = .userReported
                participation.conditionSnapshot.conditionFollowed = conditionConfirmed
                if conditionID == "phone.outside_reach" || conditionID == "phone.usual" {
                    arm = SessionEnvironmentArm(
                        condition: conditionID == "phone.outside_reach" ? .phoneAway : .unrestricted,
                        manualIntervention: participation.conditionSnapshot.requestedDetail,
                        protectedSelectionID: nil,
                        protectionOffered: false,
                        protectionAccepted: false,
                        protectionActivated: false,
                        phoneLocationSelfReport: participation.conditionSnapshot.requestedTitle
                    )
                } else if conditionID == "browser.single_task" || conditionID == "browser.usual" {
                    arm = SessionEnvironmentArm(
                        condition: conditionID == "browser.single_task" ? .singleTaskBrowser : .unrestricted,
                        manualIntervention: participation.conditionSnapshot.requestedDetail,
                        protectedSelectionID: nil,
                        protectionOffered: false,
                        protectionAccepted: false,
                        protectionActivated: false,
                        phoneLocationSelfReport: nil
                    )
                }
            }
            participation.conditionSnapshot.capturedAt = Date()
            updated.experimentParticipation = participation
        } else if useProtection {
            let applied = environmentStore.applySessionProtection()
            arm = SessionEnvironmentArm(
                condition: .protected,
                manualIntervention: nil,
                protectedSelectionID: environmentStore.selection?.id,
                protectionOffered: true,
                protectionAccepted: true,
                protectionActivated: applied,
                phoneLocationSelfReport: nil
            )
        }
        product.begin(request: updated, environment: arm)
    }

    private func editorialField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(text: label)
            TextField(prompt, text: text)
                .font(Font(AppTypography.plusJakarta(size: 17, weight: 500)))
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(AppColors.paperRaised)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func editorialEditor(
        _ label: String,
        text: Binding<String>,
        prompt: String,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(text: label)
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(prompt)
                        .font(Font(AppTypography.plusJakarta(size: 16, weight: 400)))
                        .foregroundStyle(AppColors.inkFaint)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .font(Font(AppTypography.plusJakarta(size: 16, weight: 400)))
                    .foregroundStyle(AppColors.ink)
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .frame(minHeight: minHeight)
            }
            .background(AppColors.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

// MARK: - Execution router

struct SessionView: View {
    @ObservedObject var product: ProductStore

    private var record: SessionRecord? {
        if case .running(let record) = product.phase { return record }
        return nil
    }

    @ViewBuilder
    var body: some View {
        if let record {
            if record.flowParticipation != nil {
                FlowFocusedSessionView(product: product, record: record)
            } else {
                switch record.mode {
                case .stay: StaySessionView(product: product, record: record)
                case .recall: RecallSessionView(product: product, record: record)
                case .explain: ExplainSessionView(product: product, record: record)
                case .nothing: NothingSessionView(product: product, record: record)
                case .observe: ObserveSessionView(product: product, record: record)
                }
            }
        }
    }
}

struct SessionRecoveryView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    let record: SessionRecord

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                MetaLabel(text: record.mode.rawValue, color: AppColors.coral)
                EditorialHeadline(text: "Session still in progress")
                    .padding(.top, 14)
                Text("Resume from the real start time, or end it honestly. Nothing has been marked complete.", style: .todaySentence)
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 14)
                PrimaryPillButton(title: "Resume", symbol: "play.fill") {
                    let protectionRestored = record.environment?.protectionActivated == true
                        ? environmentStore.applySessionProtection()
                        : nil
                    product.resumeRecoveredSession(protectionRestored: protectionRestored)
                }
                .padding(.top, 30)
                Button {
                    environmentStore.removeSessionProtection()
                    product.endRecoveredSession()
                } label: {
                    Text("End session", style: .smallLink)
                        .foregroundStyle(AppColors.inkFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
    }
}

// MARK: - STAY

private struct StaySessionView: View {
    @ObservedObject var product: ProductStore
    let record: SessionRecord

    var body: some View {
        TimedSessionScaffold(
            record: record,
            instruction: "One task. Return when you notice the switch.",
            detail: record.evidence?.stay?.task,
            quiet: false,
            onFinish: { product.finishRunning(endedEarly: false) },
            onEndEarly: { product.finishRunning(endedEarly: true) }
        ) {
            Button { product.markSwitch() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.turn.down.right")
                    Text("I switched")
                }
                .font(Font(AppTypography.plusJakarta(size: 13, weight: 600)))
                .foregroundStyle(AppColors.inkFaint)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(AppColors.paperRaised.opacity(0.8))
                .clipShape(Capsule())
            }
            .buttonStyle(PressScaleStyle())
            .sensoryFeedback(.impact(weight: .light), trigger: record.switches ?? 0)
        }
    }
}

// MARK: - NOTHING

private struct NothingSessionView: View {
    @ObservedObject var product: ProductStore
    let record: SessionRecord

    var body: some View {
        TimedSessionScaffold(
            record: record,
            instruction: "No new input.",
            detail: nil,
            quiet: true,
            onFinish: { product.finishRunning(endedEarly: false) },
            onEndEarly: { product.finishRunning(endedEarly: true) }
        ) { EmptyView() }
    }
}

// MARK: - OBSERVE

private struct ObserveSessionView: View {
    @ObservedObject var product: ProductStore
    let record: SessionRecord

    var body: some View {
        TimedSessionScaffold(
            record: record,
            instruction: record.origin == .protocol && record.day == 1 ? "Work the way you usually do." : "Notice. Do not correct it yet.",
            detail: record.evidence?.observe?.mission,
            quiet: false,
            onFinish: { product.finishRunning(endedEarly: false) },
            onEndEarly: { product.finishRunning(endedEarly: true) }
        ) { EmptyView() }
    }
}

private struct TimedSessionScaffold<Accessory: View>: View {
    let record: SessionRecord
    let instruction: String
    let detail: String?
    let quiet: Bool
    let onFinish: () -> Void
    let onEndEarly: () -> Void
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = max(0, Int(context.date.timeIntervalSince(record.date)))
                let reached = elapsed >= record.targetMinutes * 60
                ZStack {
                    AmbientBackground()
                    VStack(spacing: 0) {
                        // Deliberate spatial rhythm: mode/task up top, timer as
                        // the visual center, one instruction, controls at rest.
                        Spacer()
                        MetaLabel(text: record.mode.rawValue, color: quiet ? AppColors.inkFaint : AppColors.coral)
                        if let detail {
                            Text(detail, style: .heroGoal)
                                .foregroundStyle(AppColors.ink)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 18)
                        }
                        Text(elapsedText(elapsed))
                            .font(Font(AppTypography.plusJakarta(size: quiet ? 42 : 64, weight: 200)))
                            .foregroundStyle(quiet ? AppColors.inkFaint : AppColors.inkSoft)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .padding(.top, detail == nil ? 20 : 12)
                        Text("of \(record.targetMinutes) minutes", style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                            .padding(.top, 8)

                        SessionProgressRhythm(progress: min(1, Double(elapsed) / Double(max(1, record.targetMinutes * 60))))
                            .padding(.top, 26)
                            .frame(maxWidth: 180)

                        Text(instruction, style: .heroReason)
                            .foregroundStyle(AppColors.inkFaint)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 22)
                        accessory()
                            .padding(.top, 16)
                        Spacer()

                        if reached {
                            PrimaryPillButton(
                                title: "Finish",
                                symbol: "checkmark",
                                action: onFinish
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        } else {
                            // No giant disabled CTA while running — a quiet
                            // end-early affordance is all a session needs.
                            Button(action: onEndEarly) {
                                Text("End early", style: .smallLink)
                                    .foregroundStyle(AppColors.inkFaint)
                                    .frame(minHeight: 44)
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.25), value: reached)
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top) + 8)
                    .padding(.bottom, max(24, geo.safeAreaInsets.bottom) + 8)
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// A faint vertical rhythm of dots that fills as the session progresses —
/// visible at a glance, ignorable at will. No animation that pulls attention.
struct SessionProgressRhythm: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let count = max(8, Int(geo.size.height / 14))
            VStack(spacing: (geo.size.height - CGFloat(count)) / CGFloat(max(1, count - 1))) {
                ForEach(0..<count, id: \.self) { i in
                    Circle()
                        .fill(Double(i) / Double(count) < progress ? AppColors.coral.opacity(0.55) : AppColors.hairline)
                        .frame(width: 3, height: 3)
                }
            }
            .frame(width: geo.size.width)
            .frame(height: geo.size.height, alignment: .top)
            .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .frame(height: 120)
    }
}

// MARK: - RECALL

private struct RecallSessionView: View {
    @ObservedObject var product: ProductStore
    let record: SessionRecord
    @State private var stage = 0
    @State private var reconstruction: String

    init(product: ProductStore, record: SessionRecord) {
        self.product = product
        self.record = record
        _reconstruction = State(initialValue: record.evidence?.recall?.reconstruction ?? "")
    }

    var body: some View {
        EditorialSessionPage(meta: "RECALL", close: endEarly) {
            switch stage {
            case 0: readStage
            case 1: reconstructStage
            default: compareStage
            }
        }
    }

    private var readStage: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialHeadline(text: "Read.")
            Text(record.evidence?.recall?.source ?? "", style: .todaySentence)
                .foregroundStyle(AppColors.ink)
                .textSelection(.enabled)
                .padding(.top, 24)
            PrimaryPillButton(title: "Close the source", symbol: "eye.slash") {
                withAnimation(.reboot(duration: 0.3)) { stage = 1 }
            }
            .padding(.top, 30)
        }
    }

    private var reconstructStage: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialHeadline(text: "Write what you remember without looking back.")
            sessionEditor(text: $reconstruction, prompt: "Reconstruct the idea in your own words")
                .padding(.top, 24)
            PrimaryPillButton(title: "Compare", isEnabled: !reconstruction.nilIfBlank.isNil) {
                saveReconstruction()
                withAnimation(.reboot(duration: 0.3)) { stage = 2 }
            }
            .padding(.top, 24)
        }
    }

    private var compareStage: some View {
        VStack(alignment: .leading, spacing: 22) {
            EditorialHeadline(text: "Compare, without scoring.")
            compareBlock("Your reconstruction", text: reconstruction)
            compareBlock("Original source", text: record.evidence?.recall?.source ?? "")
            PrimaryPillButton(title: "Finish session", symbol: "checkmark") {
                saveReconstruction()
                product.finishRunning(endedEarly: false, semanticCompletion: true)
            }
        }
    }

    private func saveReconstruction() {
        product.updateRunningEvidence { evidence in
            var recall = evidence.recall ?? RecallEvidence(source: record.evidence?.recall?.source ?? "", reconstruction: "")
            recall.reconstruction = reconstruction
            evidence.recall = recall
        }
    }

    private func endEarly() {
        saveReconstruction()
        product.finishRunning(endedEarly: true)
    }
}

// MARK: - EXPLAIN

private struct ExplainSessionView: View {
    @ObservedObject var product: ProductStore
    let record: SessionRecord
    @State private var stage = 0
    @State private var method: ExplanationMethod?
    @State private var response = ""

    var body: some View {
        EditorialSessionPage(meta: "EXPLAIN", close: endEarly) {
            switch stage {
            case 0: learnStage
            case 1: chooseStage
            case 2: explainStage
            default: reviewStage
            }
        }
    }

    private var learnStage: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialHeadline(text: record.evidence?.explain?.topic ?? "Learn the idea.")
            if let source = record.evidence?.explain?.source, !source.isEmpty {
                Text(source, style: .todaySentence)
                    .foregroundStyle(AppColors.ink)
                    .padding(.top, 22)
            } else {
                Text("Review the material you already have. REBOOT will hide this screen when you are ready.", style: .todaySentence)
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 18)
            }
            PrimaryPillButton(title: "Hide the material", symbol: "eye.slash") {
                withAnimation(.reboot(duration: 0.3)) { stage = 1 }
            }
            .padding(.top, 30)
        }
    }

    private var chooseStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            EditorialHeadline(text: "Teach it without looking.")
            methodButton("Explain out loud", symbol: "waveform", method: .spoken)
            methodButton("Write it", symbol: "square.and.pencil", method: .written)
        }
    }

    @ViewBuilder
    private var explainStage: some View {
        if method == .written {
            VStack(alignment: .leading, spacing: 0) {
                EditorialHeadline(text: "Teach it in your own words.")
                sessionEditor(text: $response, prompt: "Explain the main idea simply")
                    .padding(.top, 24)
                PrimaryPillButton(title: "Reveal my notes", isEnabled: !response.nilIfBlank.isNil) {
                    saveExplanation()
                    withAnimation(.reboot(duration: 0.3)) { stage = 3 }
                }
                .padding(.top, 24)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                EditorialHeadline(text: "Explain it out loud.")
                Text("Take 2–5 minutes. REBOOT is timing the practice, not evaluating what you say.", style: .todaySentence)
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 16)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsedText(max(0, Int(context.date.timeIntervalSince(record.date)))))
                        .font(Font(AppTypography.plusJakarta(size: 44, weight: 300)))
                        .foregroundStyle(AppColors.ink)
                        .monospacedDigit()
                        .padding(.top, 28)
                }
                PrimaryPillButton(title: "Reveal my notes") {
                    saveExplanation()
                    withAnimation(.reboot(duration: 0.3)) { stage = 3 }
                }
                .padding(.top, 28)
            }
        }
    }

    private var reviewStage: some View {
        VStack(alignment: .leading, spacing: 22) {
            EditorialHeadline(text: "Look back at the source.")
            if method == .written { compareBlock("Your explanation", text: response) }
            compareBlock("Original material", text: record.evidence?.explain?.source ?? "No source was added.")
            PrimaryPillButton(title: "Finish session", symbol: "checkmark") {
                saveExplanation()
                product.finishRunning(endedEarly: false, semanticCompletion: true)
            }
        }
    }

    private func methodButton(_ title: String, symbol: String, method: ExplanationMethod) -> some View {
        Button {
            self.method = method
            saveExplanation()
            withAnimation(.reboot(duration: 0.3)) { stage = 2 }
        } label: {
            HStack {
                Image(systemName: symbol)
                Text(title, style: .heroGoal)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(AppColors.ink)
            .padding(20)
            .background(AppColors.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func saveExplanation() {
        product.updateRunningEvidence { evidence in
            var explain = evidence.explain ?? ExplainEvidence(topic: record.evidence?.explain?.topic ?? "")
            explain.method = method
            explain.response = method == .written ? response : nil
            evidence.explain = explain
        }
    }

    private func endEarly() {
        saveExplanation()
        product.finishRunning(endedEarly: true)
    }
}

// MARK: - Editorial session helpers

private struct EditorialSessionPage<Content: View>: View {
    let meta: String
    let close: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            MetaLabel(text: meta, color: AppColors.coral)
                            Spacer()
                            Button(action: close) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: 42, height: 42)
                                    .background(AppColors.paperRaised)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("End session early")
                        }
                        content()
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top))
                    .padding(.bottom, max(36, geo.safeAreaInsets.bottom) + 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
    }
}

private func sessionEditor(text: Binding<String>, prompt: String) -> some View {
    ZStack(alignment: .topLeading) {
        if text.wrappedValue.isEmpty {
            Text(prompt)
                .font(Font(AppTypography.plusJakarta(size: 16, weight: 400)))
                .foregroundStyle(AppColors.inkFaint)
                .padding(20)
                .allowsHitTesting(false)
        }
        TextEditor(text: text)
            .font(Font(AppTypography.plusJakarta(size: 16, weight: 400)))
            .foregroundStyle(AppColors.ink)
            .scrollContentBackground(.hidden)
            .padding(14)
            .frame(minHeight: 260)
    }
    .background(AppColors.paperRaised)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
}

private func compareBlock(_ label: String, text: String) -> some View {
    PaperCard(radius: 24, padding: 20) {
        VStack(alignment: .leading, spacing: 10) {
            MetaLabel(text: label)
            Text(text, style: .heroReason)
                .foregroundStyle(AppColors.ink)
                .textSelection(.enabled)
        }
    }
}

private func elapsedText(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional {
    var isNil: Bool { self == nil }
}
