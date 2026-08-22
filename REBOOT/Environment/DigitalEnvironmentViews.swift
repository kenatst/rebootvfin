import SwiftUI

// MARK: - Environment Lab Screen (Editorial Secondary Destination)

struct EnvironmentLabView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddWindowSheet = false
    @State private var showingScreenTimeFlow = false
    @State private var selectedMission: DigitalResetMission?
    @State private var showingAppLimitSheet = false
    @State private var editingWindow: FocusWindow?

    init(product: ProductStore, environmentStore: EnvironmentStore) {
        self.product = product
        self.environmentStore = environmentStore
    }

    private var profile: DigitalEnvironmentProfile {
        product.digitalEnvironmentState.profile
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        headerSection
                        patternSignalsSection
                        whatHelpsSection
                        focusWindowsSection
                        shieldControlsSection
                        rulesSection
                        openQuestionsSection
                        resetMissionsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Environment Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                }
            }
            .sheet(isPresented: $showingAddWindowSheet) {
                FocusWindowEditorSheet(product: product, windowToEdit: editingWindow)
            }
            .sheet(isPresented: $showingScreenTimeFlow) {
                ScreenTimeExplainerSheet(environmentStore: environmentStore)
            }
            .sheet(isPresented: $showingAppLimitSheet) {
                AppLimitGuidanceSheet(product: product, topPull: profile.primaryDigitalPull.value)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(text: "Digital Environment", color: AppColors.coral)
            Text("Your Attention Architecture")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(AppColors.ink)
            Text("REBOOT observes what pulls you away and discovers the lowest-friction boundaries that keep intentional work possible.")
                .type(.heroReason)
                .foregroundStyle(AppColors.inkSoft)
        }
    }

    private var patternSignalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR DIGITAL PATTERN", style: .heroGoal)
                .foregroundStyle(AppColors.ink)

            PaperCard(radius: 20, padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    signalRow(
                        title: "Primary Digital Pull",
                        value: profile.primaryDigitalPull.value.displayName,
                        confidence: profile.primaryDigitalPull.confidence,
                        isKnown: profile.primaryDigitalPull.isKnown && profile.primaryDigitalPull.value != .unknown
                    )
                    Divider().opacity(0.3)
                    signalRow(
                        title: "Interruption Trigger",
                        value: profile.triggerType.value.displayName,
                        confidence: profile.triggerType.confidence,
                        isKnown: profile.triggerType.isKnown && profile.triggerType.value != .unknown
                    )
                    Divider().opacity(0.3)
                    signalRow(
                        title: "Usual Phone Placement",
                        value: profile.phoneProximity.value.displayName,
                        confidence: profile.phoneProximity.confidence,
                        isKnown: profile.phoneProximity.isKnown && profile.phoneProximity.value != .unknown
                    )
                    Divider().opacity(0.3)
                    signalRow(
                        title: "Environment Control",
                        value: profile.environmentControl.value.displayLabel,
                        confidence: profile.environmentControl.confidence,
                        isKnown: profile.environmentControl.isKnown && profile.environmentControl.value != .unknown
                    )
                }
            }
        }
    }

    private func signalRow(title: String, value: String, confidence: Double, isKnown: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .type(.heroReason)
                    .foregroundStyle(AppColors.inkSoft)
                Text(isKnown ? value : "Measuring...")
                    .type(.heroGoal)
                    .foregroundStyle(isKnown ? AppColors.ink : AppColors.inkSoft.opacity(0.6))
            }
            Spacer()
            if isKnown {
                Text(confidence >= 0.6 ? "Consistent" : "Emerging")
                    .type(.smallLink)
                    .foregroundStyle(confidence >= 0.6 ? AppColors.ink : AppColors.coral)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((confidence >= 0.6 ? AppColors.ink : AppColors.coral).opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private var whatHelpsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHAT SEEMS TO HELP", style: .heroGoal)
                .foregroundStyle(AppColors.ink)

            if profile.matureSignals.isEmpty {
                PaperCard(radius: 20, padding: 18) {
                    Text("Complete 2–3 more sessions with check-ins to discover your lowest-friction boundaries.")
                        .type(.heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                }
            } else {
                PaperCard(radius: 20, padding: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(profile.matureSignals, id: \.self) { signal in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppColors.coral)
                                    .font(.system(size: 14))
                                Text(signal.capitalized)
                                    .type(.heroGoal)
                                    .foregroundStyle(AppColors.ink)
                            }
                        }
                    }
                }
            }
        }
    }

    private var focusWindowsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("FOCUS WINDOWS", style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Button(action: { 
                    editingWindow = nil
                    showingAddWindowSheet = true 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Window")
                    }
                    .type(.smallLink)
                    .foregroundStyle(AppColors.coral)
                }
            }

            if product.digitalEnvironmentState.focusWindows.isEmpty {
                PaperCard(radius: 20, padding: 18) {
                    Text("No recurring focus windows yet. Add one to protect a dedicated time block each week.")
                        .type(.heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(product.digitalEnvironmentState.focusWindows) { window in
                        PaperCard(radius: 18, padding: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(window.name)
                                        .type(.heroGoal)
                                        .foregroundStyle(AppColors.ink)
                                    Text("\(window.timeRangeString) · \(window.weekdaysString)")
                                        .type(.heroReason)
                                        .foregroundStyle(AppColors.inkSoft)
                                }
                                Spacer()
                                Button(action: {
                                    editingWindow = window
                                    showingAddWindowSheet = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(AppColors.inkSoft)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var shieldControlsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SHIELD & BOUNDARIES", style: .heroGoal)
                .foregroundStyle(AppColors.ink)

            PaperCard(radius: 20, padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Screen Time")
                                .type(.heroGoal)
                                .foregroundStyle(AppColors.ink)
                            Text(environmentStore.isConnected ? "Connected locally · Session shields active" : "Not connected · Using manual friction")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                        Spacer()
                        Button(action: { showingScreenTimeFlow = true }) {
                            Text(environmentStore.isConnected ? "Manage" : "Connect")
                                .type(.smallLink)
                                .foregroundStyle(AppColors.paper)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppColors.ink)
                                .clipShape(Capsule())
                        }
                    }

                    Divider().opacity(0.3)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App Limit Guidance")
                                .type(.heroGoal)
                                .foregroundStyle(AppColors.ink)
                            Text("Step-by-step setup for recurring digital boundaries")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                        Spacer()
                        Button(action: { showingAppLimitSheet = true }) {
                            Text("Set Limit")
                                .type(.smallLink)
                                .foregroundStyle(AppColors.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppColors.ink.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var rulesSection: some View {
        let envRules = product.personalRules.filter { $0.category == .environment || $0.category == .friction }
        return VStack(alignment: .leading, spacing: 14) {
            Text("PERSONAL DIGITAL RULES", style: .heroGoal)
                .foregroundStyle(AppColors.ink)

            if envRules.isEmpty {
                PaperCard(radius: 20, padding: 18) {
                    Text("No digital rules kept yet. Complete experiments in Personal Lab to establish evidence-backed rules.")
                        .type(.heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(envRules) { rule in
                        PaperCard(radius: 18, padding: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(rule.title)
                                    .type(.heroGoal)
                                    .foregroundStyle(AppColors.ink)
                                Text(rule.detail)
                                    .type(.heroReason)
                                    .foregroundStyle(AppColors.inkSoft)
                            }
                        }
                    }
                }
            }
        }
    }

    private var openQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("OPEN QUESTIONS", style: .heroGoal)
                .foregroundStyle(AppColors.ink)

            if profile.openQuestions.isEmpty {
                PaperCard(radius: 20, padding: 18) {
                    Text("All primary digital environment dimensions have active evidence.")
                        .type(.heroReason)
                        .foregroundStyle(AppColors.inkSoft)
                }
            } else {
                PaperCard(radius: 20, padding: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(profile.openQuestions, id: \.self) { q in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundStyle(AppColors.coral)
                                Text(q)
                                    .type(.heroReason)
                                    .foregroundStyle(AppColors.ink)
                            }
                        }
                    }
                }
            }
        }
    }

    private var resetMissionsSection: some View {
        let missions = DigitalResetMissionLibrary.allMissions
        return VStack(alignment: .leading, spacing: 14) {
            Text("CURRICULUM DIGITAL MISSIONS", style: .heroGoal)
                .foregroundStyle(AppColors.ink)

            VStack(spacing: 10) {
                ForEach(missions, id: \.id) { mission in
                    let isDone = product.digitalEnvironmentState.resetMissions.contains(where: { $0.id == mission.id && $0.completed })
                    PaperCard(radius: 18, padding: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Day \(mission.day): \(mission.title)")
                                    .type(.heroGoal)
                                    .foregroundStyle(AppColors.ink)
                                Spacer()
                                if isDone {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.coral)
                                }
                            }
                            Text(mission.instruction)
                                .type(.heroReason)
                                .foregroundStyle(AppColors.inkSoft)
                            if !isDone {
                                Button(action: {
                                    product.completeResetMission(id: mission.id)
                                }) {
                                    Text("Mark Completed")
                                        .type(.smallLink)
                                        .foregroundStyle(AppColors.ink)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.ink.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Start Ritual View (10-20s Intentional Transition)

struct StartRitualView: View {
    let minutes: Int
    let onComplete: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var timeRemaining = 10
    @State private var timerActive = true

    init(minutes: Int, onComplete: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.minutes = minutes
        self.onComplete = onComplete
        self.onSkip = onSkip
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                VStack(spacing: 12) {
                    Text("CLOSE THE LOOP.")
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .tracking(4)

                    Text("ONE TASK.")
                        .font(.system(size: 32, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.white)
                        .tracking(6)

                    Text("NOTHING ELSE FOR \(minutes) MINUTES.")
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .tracking(2)
                        .padding(.top, 6)
                }

                if !reduceMotion {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 2)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: CGFloat(timeRemaining) / 10.0)
                            .stroke(AppColors.coral, lineWidth: 2)
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: timeRemaining)

                        Text("\(timeRemaining)")
                            .font(.system(size: 22, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white)
                    }
                }

                Spacer()

                Button(action: onSkip) {
                    Text("Start Now")
                        .type(.buttonLabel)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if reduceMotion {
                // If reduce motion is enabled, skip automatically after 1s or direct tap
            } else {
                startTimer()
            }
        }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                onComplete()
            }
        }
    }
}

// MARK: - Pre-Session Setup Contract Card

struct PreSessionContractCard: View {
    @Binding var contract: PreSessionContract
    let onCommit: () -> Void

    init(contract: Binding<PreSessionContract>, onCommit: @escaping () -> Void) {
        self._contract = contract
        self.onCommit = onCommit
    }

    var body: some View {
        PaperCard(radius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(AppColors.coral)
                    Text("Pre-Session Setup Contract")
                        .type(.heroGoal)
                        .foregroundStyle(AppColors.ink)
                }

                VStack(alignment: .leading, spacing: 10) {
                    contractItem(
                        icon: "phone.fill",
                        title: "Phone Placement",
                        subtitle: contract.phonePosition?.displayName ?? "Outside arm's reach"
                    )
                    contractItem(
                        icon: "square.stack.3d.up.fill",
                        title: "Browser Scope",
                        subtitle: contract.browserScope ?? "One active tab only"
                    )
                    contractItem(
                        icon: "bell.slash.fill",
                        title: "Notifications",
                        subtitle: "Muted / Focus mode"
                    )
                }

                Button(action: onCommit) {
                    Text("Contract Ready")
                        .type(.smallLink)
                        .foregroundStyle(AppColors.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.ink)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
    }

    private func contractItem(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.inkSoft)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .type(.heroReason)
                    .foregroundStyle(AppColors.inkSoft)
                Text(subtitle)
                    .type(.heroGoal)
                    .foregroundStyle(AppColors.ink)
            }
        }
    }
}

// MARK: - Required Action Card (Today View)

struct RequiredActionCard: View {
    let action: EnvironmentAction
    let onDone: () -> Void
    let onCouldNot: () -> Void

    init(action: EnvironmentAction, onDone: @escaping () -> Void, onCouldNot: @escaping () -> Void) {
        self.action = action
        self.onDone = onDone
        self.onCouldNot = onCouldNot
    }

    var body: some View {
        PaperCard(radius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    MetaLabel(text: "Before You Start", color: AppColors.coral)
                    Spacer()
                    Text("Level \(action.level)")
                        .type(.smallLink)
                        .foregroundStyle(AppColors.inkSoft)
                }

                Text(action.title)
                    .type(.heroGoal)
                    .foregroundStyle(AppColors.ink)

                Text(action.detail)
                    .type(.heroReason)
                    .foregroundStyle(AppColors.inkSoft)

                HStack(spacing: 12) {
                    Button(action: onDone) {
                        Text("Done")
                            .type(.smallLink)
                            .foregroundStyle(AppColors.paper)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppColors.ink)
                            .clipShape(Capsule())
                    }

                    Button(action: onCouldNot) {
                        Text("I couldn't")
                            .type(.smallLink)
                            .foregroundStyle(AppColors.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppColors.ink.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Adaptive Refusal Reason Sheet

struct RefusalReasonSheet: View {
    let onReasonSelected: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let reasons = [
        "Work requires phone access",
        "Expecting family message",
        "Too inconvenient right now",
        "Don't feel like it today",
        "Other reason"
    ]

    init(onReasonSelected: @escaping (String) -> Void) {
        self.onReasonSelected = onReasonSelected
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                VStack(alignment: .leading, spacing: 20) {
                    Text("No problem. What got in the way?")
                        .type(.heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 16)

                    VStack(spacing: 10) {
                        ForEach(reasons, id: \.self) { r in
                            Button(action: {
                                onReasonSelected(r)
                                dismiss()
                            }) {
                                Text(r)
                                    .type(.heroGoal)
                                    .foregroundStyle(AppColors.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(AppColors.paperRaised)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Quick Adjustment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.ink)
                }
            }
        }
    }
}

// MARK: - Digital Check-In Sheet (Post-Session 1-2 Questions)

struct DigitalCheckInSheet: View {
    let onSave: (DigitalCheckInResponse) -> Void
    let onSkip: () -> Void

    @State private var selectedPull: DigitalPull?
    @State private var selectedTrigger: InterruptionTrigger?
    @State private var phonePos: PhoneProximity?
    @State private var step = 1

    init(onSave: @escaping (DigitalCheckInResponse) -> Void, onSkip: @escaping () -> Void) {
        self.onSave = onSave
        self.onSkip = onSkip
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                VStack(alignment: .leading, spacing: 20) {
                    if step == 1 {
                        Text("What pulled you away during the session?")
                            .type(.heroGoal)
                            .foregroundStyle(AppColors.ink)
                            .padding(.top, 16)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(DigitalPull.allCases.filter { $0 != .unknown }) { pull in
                                    TonalPillButton(
                                        title: pull.displayName,
                                        isSelected: selectedPull == pull,
                                        showsSelectionIndicator: true
                                    ) {
                                        selectedPull = pull
                                        step = 2
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    } else {
                        Text("What was the initial trigger?")
                            .type(.heroGoal)
                            .foregroundStyle(AppColors.ink)
                            .padding(.top, 16)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(InterruptionTrigger.allCases.filter { $0 != .unknown }) { trigger in
                                    TonalPillButton(
                                        title: trigger.displayName,
                                        isSelected: selectedTrigger == trigger,
                                        showsSelectionIndicator: true
                                    ) {
                                        selectedTrigger = trigger
                                        finish()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    Spacer()

                    HStack {
                        Button(action: onSkip) {
                            Text("Skip")
                                .type(.smallLink)
                                .foregroundStyle(AppColors.inkSoft)
                        }
                        Spacer()
                        if step == 2 {
                            Button(action: finish) {
                                Text("Done")
                                    .type(.smallLink)
                                    .foregroundStyle(AppColors.paper)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppColors.ink)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Digital Check-In")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func finish() {
        let resp = DigitalCheckInResponse(
            pull: selectedPull,
            trigger: selectedTrigger,
            phonePosition: phonePos
        )
        onSave(resp)
    }
}

// MARK: - App Limit Guidance Sheet

struct AppLimitGuidanceSheet: View {
    @ObservedObject var product: ProductStore
    let topPull: DigitalPull
    @Environment(\.dismiss) private var dismiss

    init(product: ProductStore, topPull: DigitalPull) {
        self.product = product
        self.topPull = topPull
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Add a Boundary for \(topPull.displayName)")
                        .type(.heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 16)

                    Text("Setting a manual or device limit creates a speedbump before automatic scrolling begins.")
                        .type(.heroReason)
                        .foregroundStyle(AppColors.inkSoft)

                    VStack(alignment: .leading, spacing: 14) {
                        instructionStep(num: "1", text: "Open Settings > Screen Time > App Limits.")
                        instructionStep(num: "2", text: "Add Limit > Choose \(topPull.displayName).")
                        instructionStep(num: "3", text: "Set daily threshold to 20 minutes.")
                    }
                    .padding(.vertical, 10)

                    Spacer()

                    PrimaryPillButton(title: "I've Set This Boundary") {
                        product.saveAppLimitGuidanceResult(pull: topPull, completed: true)
                        dismiss()
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("App Limit Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppColors.ink)
                }
            }
        }
    }

    private func instructionStep(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.paper)
                .frame(width: 24, height: 24)
                .background(AppColors.coral)
                .clipShape(Circle())
            Text(text)
                .type(.heroReason)
                .foregroundStyle(AppColors.ink)
        }
    }
}

// MARK: - Focus Window Editor Sheet

struct FocusWindowEditorSheet: View {
    @ObservedObject var product: ProductStore
    let windowToEdit: FocusWindow?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = "Morning Focus"
    @State private var startHour: Int = 9
    @State private var endHour: Int = 11

    init(product: ProductStore, windowToEdit: FocusWindow?) {
        self.product = product
        self.windowToEdit = windowToEdit
        if let w = windowToEdit {
            _name = State(initialValue: w.name)
            _startHour = State(initialValue: w.startMinutes / 60)
            _endHour = State(initialValue: w.endMinutes / 60)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                VStack(alignment: .leading, spacing: 24) {
                    Text("Schedule Focus Window")
                        .type(.heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 16)

                    TextField("Window Name", text: $name)
                        .padding()
                        .background(AppColors.paperRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Start Time")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.inkSoft)
                            Picker("Start", selection: $startHour) {
                                ForEach(6..<23) { h in
                                    Text("\(h):00").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                        }

                        VStack(alignment: .leading) {
                            Text("End Time")
                                .type(.heroReason)
                                .foregroundStyle(AppColors.inkSoft)
                            Picker("End", selection: $endHour) {
                                ForEach(7..<24) { h in
                                    Text("\(h):00").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                        }
                    }

                    Spacer()

                    PrimaryPillButton(title: "Save Focus Window") {
                        let newWindow = FocusWindow(
                            id: windowToEdit?.id ?? UUID(),
                            name: name.isEmpty ? "Focus Window" : name,
                            weekdays: [2, 3, 4, 5, 6],
                            startMinutes: startHour * 60,
                            endMinutes: max(startHour + 1, endHour) * 60
                        )
                        product.upsertFocusWindow(newWindow)
                        dismiss()
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Focus Window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.ink)
                }
            }
        }
    }
}
