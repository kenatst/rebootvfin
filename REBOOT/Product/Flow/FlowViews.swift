import SwiftUI

// MARK: - Flow Lab home

struct FlowLabView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    @State private var showNewProject = false
    @State private var selectedProject: FlowProject?
    @State private var showArchivedProjects = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        MetaLabel(text: "Flow Lab", color: AppColors.coral)
                            .padding(.top, 22)
                        EditorialHeadline(text: "Find your conditions.")
                            .padding(.top, 14)
                        FlowText(
                            "Work on something real. REBOOT learns which conditions keep showing up in your deeper blocks.",
                            style: .todaySentence
                        )
                        .foregroundStyle(AppColors.inkSoft)
                        .padding(.top, 12)

                        if let reason = product.flowWaitReason {
                            waitSection(reason)
                                .padding(.top, 28)
                        } else {
                            activeProjectSection
                                .padding(.top, 30)
                        }

                        // Empty collections stay hidden — an empty-state screen
                        // shows one path forward, not three empty boxes.
                        if !product.flowState.evidence.isEmpty || !product.flowPatterns.isEmpty {
                            noticingSection
                                .padding(.top, 38)
                        }
                        if !product.activeFlowProjects.isEmpty {
                            projectsSection
                                .padding(.top, 38)
                        }
                        if !product.recentFlowEvidence.isEmpty {
                            recentSection
                                .padding(.top, 38)
                        }
                        stillLearningSection
                            .padding(.top, 34)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(18, geo.safeAreaInsets.top))
                    .padding(.bottom, max(42, geo.safeAreaInsets.bottom) + 18)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showNewProject) {
            NewFlowProjectView(product: product) { project in
                selectedProject = project
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedProject) { project in
            FlowProjectDetailView(
                product: product,
                environmentStore: environmentStore,
                projectID: project.id
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .scalableAppTypography()
    }

    private var header: some View {
        HStack {
            Button { product.closeFlowLab() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                    .frame(width: 44, height: 44)
                    .background(AppColors.paperRaised.opacity(0.88))
                    .clipShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Close Flow Lab")
            Spacer()
            Button { showNewProject = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                    .frame(width: 44, height: 44)
                    .background(AppColors.paperRaised.opacity(0.88))
                    .clipShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Create Flow project")
        }
    }

    private func waitSection(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(text: "PROJECT WAITING")
            FlowText(reason, style: .heroGoal)
                .foregroundStyle(AppColors.ink)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var activeProjectSection: some View {
        if let project = product.activeFlowProjects.first {
            VStack(alignment: .leading, spacing: 12) {
                MetaLabel(text: "Active project")
                Button { selectedProject = project } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            FlowText(project.title, style: .heroGoal)
                                .foregroundStyle(AppColors.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 12)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.coral)
                        }
                        FlowText(project.category.label, style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PressScaleStyle())
                PrimaryPillButton(title: "Start a block", symbol: "play.fill") {
                    _ = product.beginFlowSetup(
                        projectID: project.id,
                        origin: product.flowState.pendingEntryOrigin ?? .flow
                    )
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                MetaLabel(text: L("START WITH REAL WORK"))
                FlowText(L("Create one project to give each block a meaningful context."), style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                PrimaryPillButton(title: L("Create your first project"), symbol: "plus") {
                    showNewProject = true
                }
            }
        }
    }

    private var noticingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MetaLabel(text: "WHAT REBOOT IS NOTICING")
            FlowConditionSignature(
                patterns: Array(product.flowPatterns.prefix(4)),
                evidenceCount: product.flowState.evidence.count
            )
        }
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                MetaLabel(text: "Your projects")
                Spacer()
                Button { showNewProject = true } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.coral)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Add project")
            }
            if product.activeFlowProjects.isEmpty {
                FlowText("No active projects yet.", style: .heroReason)
                    .foregroundStyle(AppColors.inkFaint)
            } else {
                VStack(spacing: 0) {
                    ForEach(product.activeFlowProjects) { project in
                        Button { selectedProject = project } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    FlowText(project.title, style: .heroGoal)
                                        .foregroundStyle(AppColors.ink)
                                        .multilineTextAlignment(.leading)
                                    FlowText(project.category.label, style: .footnote)
                                        .foregroundStyle(AppColors.inkFaint)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppColors.inkFaint)
                            }
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(PressScaleStyle())
                        if project.id != product.activeFlowProjects.last?.id {
                            Divider().overlay(AppColors.hairline)
                        }
                    }
                }
            }

            if !product.archivedFlowProjects.isEmpty {
                Divider()
                    .overlay(AppColors.hairline)
                    .padding(.top, 10)

                DisclosureGroup(isExpanded: $showArchivedProjects) {
                    VStack(spacing: 0) {
                        ForEach(product.archivedFlowProjects) { project in
                            Button { selectedProject = project } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        FlowText(project.title, style: .heroReason)
                                            .foregroundStyle(AppColors.inkSoft)
                                            .multilineTextAlignment(.leading)
                                        FlowText(project.category.label, style: .footnote)
                                            .foregroundStyle(AppColors.inkFaint)
                                    }
                                    Spacer(minLength: 12)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppColors.inkFaint)
                                }
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(PressScaleStyle())
                            .accessibilityHint("Opens archived project history")
                            if project.id != product.archivedFlowProjects.last?.id {
                                Divider().overlay(AppColors.hairline)
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack {
                        Label("Archived projects", systemImage: "archivebox")
                            .font(.custom("PlusJakartaSans-Medium", size: 13, relativeTo: .body))
                            .foregroundStyle(AppColors.inkSoft)
                        Spacer()
                        FlowText("\(product.archivedFlowProjects.count)", style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                    .padding(.vertical, 12)
                }
                .tint(AppColors.coral)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MetaLabel(text: "Recent blocks")
            if product.recentFlowEvidence.isEmpty {
                FlowText("Your first completed block will appear here.", style: .heroReason)
                    .foregroundStyle(AppColors.inkFaint)
            } else {
                ForEach(product.recentFlowEvidence.prefix(4)) { evidence in
                    FlowEvidenceRow(product: product, evidence: evidence)
                }
            }
        }
    }

    private var stillLearningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(text: "STILL LEARNING")
            FlowText(
                product.flowPatterns.isEmpty
                    ? "Several comparable real-project blocks are needed before a condition becomes meaningful."
                    : "Conditions can change. Contradictions stay visible and newer blocks can reshape the picture.",
                style: .heroReason
            )
            .foregroundStyle(AppColors.inkSoft)
        }
    }
}

// MARK: - Signature condition map

struct FlowConditionSignature: View {
    let patterns: [FlowConditionPattern]
    let evidenceCount: Int

    var body: some View {
        PaperCard(radius: 24, padding: 20, shadow: .soft) {
            VStack(alignment: .leading, spacing: 0) {
                FlowText("Conditions that keep showing up", style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                if patterns.isEmpty {
                    FlowText(
                        evidenceCount < 3
                            ? "REBOOT needs several comparable blocks before this becomes meaningful."
                            : "No stable condition is showing up yet. Mixed evidence is still useful.",
                        style: .heroReason
                    )
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 10)
                } else {
                    VStack(spacing: 0) {
                        ForEach(patterns) { pattern in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline) {
                                    MetaLabel(text: pattern.dimension.label)
                                    Spacer()
                                    FlowText(pattern.maturity.label, style: .footnote)
                                        .foregroundStyle(AppColors.coral)
                                }
                                FlowText(pattern.statement, style: .heroReason)
                                    .foregroundStyle(AppColors.inkSoft)
                            }
                            .padding(.vertical, 14)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(pattern.accessibilitySummary)
                            if pattern.id != patterns.last?.id {
                                Divider().overlay(AppColors.hairline)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .scalableAppTypography()
    }
}

// MARK: - Project detail

private struct FlowProjectDetailView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    let projectID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showArchive = false
    @State private var showAllOpenQuestions = false

    private var project: FlowProject? { product.flowProject(id: projectID) }
    private var evidence: [FlowBlockEvidence] {
        product.recentFlowEvidence.filter { $0.projectID == projectID }
    }
    private var patterns: [FlowConditionPattern] {
        product.flowPatterns(projectID: projectID)
    }
    private var openQuestionDimensions: [FlowConditionDimension] {
        let supportedDimensions = patterns
            .filter { $0.maturity == .earlySignal || $0.maturity == .repeatedSignal }
            .map(\.dimension)
        let priority: [FlowConditionDimension] = [
            .sound,
            .finishLine,
            .phoneSetup,
            .screenTimeProtection,
            .challengeSkill,
            .feedback,
            .duration,
            .daypart,
            .taskCategory,
            .movement,
            .breakState,
            .energy,
            .sleep,
            .mealContext,
        ]
        return priority.filter { dimension in
            !supportedDimensions.contains(where: { $0 == dimension })
        }
    }
    private var visibleOpenQuestions: [FlowConditionDimension] {
        showAllOpenQuestions
            ? openQuestionDimensions
            : Array(openQuestionDimensions.prefix(5))
    }
    private var screenTimeAvailable: Bool {
        environmentStore.isConnected && environmentStore.selection != nil
    }
    private var comparableOpenQuestionEvidence: [FlowBlockEvidence] {
        let cohort = FlowComparabilityEngine.strongestMutuallyComparableCohort(
            evidence,
            state: product.flowState
        )
        return cohort.count >= 3 ? cohort : []
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            MetaLabel(text: project?.category.label ?? "Flow project", color: AppColors.coral)
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: 40, height: 40)
                                    .background(AppColors.paperRaised)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Close project")
                        }
                        EditorialHeadline(text: project?.title ?? "Project")
                            .padding(.top, 14)
                        if let project, project.status == .archived {
                            HStack(spacing: 8) {
                                Image(systemName: "archivebox.fill")
                                    .accessibilityHidden(true)
                                FlowText("Archived project", style: .footnote)
                            }
                            .foregroundStyle(AppColors.inkFaint)
                            .padding(.top, 10)
                            .accessibilityElement(children: .combine)
                        }
                        if let note = project?.note, !note.isEmpty {
                            FlowText(note, style: .todaySentence)
                                .foregroundStyle(AppColors.inkSoft)
                                .padding(.top, 10)
                        }

                        if project?.status == .active {
                            if product.flowWaitReason == nil {
                                PrimaryPillButton(title: "Start block", symbol: "play.fill") {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        _ = product.beginFlowSetup(
                                            projectID: projectID,
                                            origin: product.flowState.pendingEntryOrigin ?? .flow
                                        )
                                    }
                                }
                                .padding(.top, 26)
                            } else if let reason = product.flowWaitReason {
                                FlowText(reason, style: .heroReason)
                                    .foregroundStyle(AppColors.inkSoft)
                                    .padding(.top, 24)
                            }
                        }

                        MetaLabel(text: "What seems to help")
                            .padding(.top, 36)
                        FlowConditionSignature(
                            patterns: Array(patterns.prefix(4)),
                            evidenceCount: evidence.count
                        )
                        .padding(.top, 12)

                        let testable = patterns.first {
                            product.canTestFlowPattern(
                                $0,
                                screenTimeAvailable: screenTimeAvailable
                            )
                        }
                        if let testable {
                            Button {
                                let outcome = product.testFlowPattern(
                                    testable,
                                    screenTimeAvailable: screenTimeAvailable
                                )
                                if case .started = outcome { dismiss() }
                            } label: {
                                GlassPill(text: "Test this in Personal Lab", symbol: "arrow.left.arrow.right", tint: AppColors.ink)
                            }
                            .buttonStyle(PressScaleStyle())
                            .padding(.top, 16)
                        }

                        MetaLabel(text: "Recent blocks")
                            .padding(.top, 36)
                        if evidence.isEmpty {
                            FlowText("No blocks yet.", style: .heroReason)
                                .foregroundStyle(AppColors.inkFaint)
                                .padding(.top, 10)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(evidence.prefix(8)) { item in
                                    FlowEvidenceRow(product: product, evidence: item)
                                }
                            }
                            .padding(.top, 10)
                        }

                        MetaLabel(text: "Open questions", color: AppColors.coral)
                            .padding(.top, 36)
                        VStack(spacing: 0) {
                            ForEach(visibleOpenQuestions) { dimension in
                                FlowOpenQuestionRow(
                                    dimension: dimension,
                                    canTest: canTestOpenQuestion(dimension)
                                ) {
                                    let outcome = product.testFlowDimension(
                                        dimension,
                                        evidenceIDs: comparableOpenQuestionEvidence.map(\.id),
                                        screenTimeAvailable: screenTimeAvailable
                                    )
                                    if case .started = outcome { dismiss() }
                                }
                                if dimension.id != visibleOpenQuestions.last?.id {
                                    Divider().overlay(AppColors.hairline)
                                }
                            }
                        }
                        .padding(.top, 4)

                        if openQuestionDimensions.count > 5 {
                            Button(action: toggleOpenQuestions) {
                                Label(
                                    showAllOpenQuestions ? "Show fewer questions" : "Show all questions",
                                    systemImage: showAllOpenQuestions ? "chevron.up" : "chevron.down"
                                )
                                .font(.custom("PlusJakartaSans-Medium", size: 13, relativeTo: .body))
                                .foregroundStyle(AppColors.inkFaint)
                                .padding(.vertical, 12)
                            }
                            .accessibilityValue(showAllOpenQuestions ? "Expanded" : "Collapsed")
                        }

                        if project?.status == .active {
                            Button { showArchive = true } label: {
                                Label("Archive project", systemImage: "archivebox")
                                    .font(.custom("PlusJakartaSans-Medium", size: 13, relativeTo: .body))
                                    .foregroundStyle(AppColors.inkFaint)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                            .padding(.top, 28)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(20, geo.safeAreaInsets.top) + 8)
                    .padding(.bottom, max(38, geo.safeAreaInsets.bottom))
                }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Archive this project?", isPresented: $showArchive) {
            Button("Archive", role: .destructive) {
                product.archiveFlowProject(id: projectID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its blocks and evidence remain in your history.")
        }
        .scalableAppTypography()
    }

    private func toggleOpenQuestions() {
        if reduceMotion {
            showAllOpenQuestions.toggle()
        } else {
            withAnimation(.easeOut(duration: AppMotion.selectMorph)) {
                showAllOpenQuestions.toggle()
            }
        }
    }

    private func canTestOpenQuestion(_ dimension: FlowConditionDimension) -> Bool {
        guard !comparableOpenQuestionEvidence.isEmpty,
              product.canTestFlowDimension(
                  dimension,
                  screenTimeAvailable: screenTimeAvailable
              ) else { return false }
        return true
    }
}

private struct FlowOpenQuestionRow: View {
    let dimension: FlowConditionDimension
    let canTest: Bool
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                MetaLabel(text: dimension.label)
                Spacer(minLength: 12)
                FlowText("Still learning", style: .footnote)
                    .foregroundStyle(AppColors.coral)
            }
            FlowText(dimension.openQuestionCopy, style: .heroReason)
                .foregroundStyle(AppColors.inkSoft)
            if canTest {
                Button(action: onTest) {
                    GlassPill(
                        text: "Test this in Personal Lab",
                        symbol: "arrow.left.arrow.right",
                        tint: AppColors.ink
                    )
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, 5)
                .accessibilityHint("Opens the canonical Personal Lab comparison")
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
    }
}

private extension FlowConditionDimension {
    var openQuestionCopy: String {
        switch self {
        case .sound:
            return "We still don't know whether quiet or background sound is associated with stronger engagement."
        case .finishLine:
            return "We still don't know whether a clear finish line is associated with stronger engagement."
        case .challengeSkill:
            return "No stable challenge and confidence pattern has appeared yet."
        case .feedback:
            return "No feedback setup has appeared consistently in stronger comparable blocks."
        case .duration:
            return "Block length remains mixed; longer is not automatically better."
        case .taskCategory:
            return "No task type has appeared consistently in stronger comparable blocks."
        case .daypart:
            return "Time of day remains unresolved."
        case .phoneSetup:
            return "We still don't know whether phone placement is associated with stronger engagement."
        case .screenTimeProtection:
            return "Screen Time protection has not produced enough comparable evidence yet."
        case .energy:
            return "Reported energy context remains observational and unresolved."
        case .movement:
            return "We still don't know whether movement before a block is associated with stronger engagement."
        case .breakState:
            return "We still don't know whether a no-input break is associated with stronger engagement."
        case .sleep:
            return "Reported sleep context remains observational and unresolved."
        case .mealContext:
            return "Meal context remains observational and unresolved."
        }
    }
}

private struct FlowEvidenceRow: View {
    @ObservedObject var product: ProductStore
    let evidence: FlowBlockEvidence

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                FlowText(product.flowPlan(id: evidence.planID)?.task ?? "Project block", style: .heroReason)
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(2)
                Spacer(minLength: 10)
                FlowText(evidence.engagementSignal.label, style: .footnote)
                    .foregroundStyle(evidence.engagementSignal == .strongerSignal ? AppColors.coral : AppColors.inkFaint)
            }
            FlowText("\(evidence.actualDuration) min · \(evidence.reflection.definitionOfDoneOutcome?.label ?? "Reflection incomplete")", style: .footnote)
                .foregroundStyle(AppColors.inkFaint)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - New project

private struct NewFlowProjectView: View {
    @ObservedObject var product: ProductStore
    let onCreated: (FlowProject) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: FlowProjectCategory = .coding
    @State private var note = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case note
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            MetaLabel(text: "Real project", color: AppColors.coral)
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: 40, height: 40)
                                    .background(AppColors.paperRaised)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Close")
                        }
                        EditorialHeadline(text: "What are you building, studying or creating?")
                            .padding(.top, 14)
                        MetaLabel(text: "Project name")
                            .padding(.top, 24)
                        FlowTextField(prompt: "REBOOT iOS", text: $title)
                            .focused($focusedField, equals: .title)
                            .lineLimit(1)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .note }
                            .padding(.top, 8)
                        MetaLabel(text: "Type")
                            .padding(.top, 20)
                        Picker("Project type", selection: $category) {
                            ForEach(FlowProjectCategory.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.ink)
                        MetaLabel(text: "Note (optional)")
                            .padding(.top, 20)
                        FlowTextField(prompt: "A little context", text: $note, axis: .vertical)
                            .focused($focusedField, equals: .note)
                            .lineLimit(2...5)
                            .padding(.top, 8)
                        Spacer(minLength: 24)
                        PrimaryPillButton(
                            title: "Create project",
                            symbol: "plus",
                            isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            if let project = product.createFlowProject(
                                title: title,
                                category: category,
                                note: note
                            ) {
                                focusedField = nil
                                dismiss()
                                onCreated(project)
                            }
                        }
                    }
                    .frame(minHeight: max(0, geo.size.height - 44), alignment: .top)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .scalableAppTypography()
    }
}

// MARK: - Block setup

struct FlowBlockSetupView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    @State private var draft: FlowSetupDraft
    @State private var startFailed = false
    @State private var startFailureMessage = "The current Program or project state changed. Review the setup and try again."
    @State private var isStarting = false

    init(product: ProductStore, environmentStore: EnvironmentStore) {
        self.product = product
        self.environmentStore = environmentStore
        _draft = State(initialValue: product.flowState.pendingSetup ?? FlowSetupDraft())
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        closeButton
                        MetaLabel(text: draft.sessionOrigin == .protocol ? "Today's project block" : "Flow block", color: AppColors.coral)
                            .padding(.top, 22)
                        EditorialHeadline(text: "Set up one clear block.")
                            .padding(.top, 14)
                        FlowText("A few specific choices now make the evidence useful later.", style: .todaySentence)
                            .foregroundStyle(AppColors.inkSoft)
                            .padding(.top, 12)

                        workSection
                            .padding(.top, 32)
                        Divider().overlay(AppColors.hairline).padding(.vertical, 30)
                        conditionSection
                        Divider().overlay(AppColors.hairline).padding(.vertical, 30)
                        environmentSection

                        if let fuel = product.todaysFuelCapture, !fuel.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                MetaLabel(text: "Context already available")
                                FlowText(fuel.summaryLines.prefix(2).joined(separator: " · "), style: .footnote)
                                    .foregroundStyle(AppColors.inkFaint)
                            }
                            .padding(.top, 24)
                        }

                        PrimaryPillButton(
                            title: isStarting ? "Starting block" : "Start block",
                            symbol: "play.fill",
                            isEnabled: draft.isComplete && !isStarting
                        ) {
                            start()
                        }
                        .padding(.top, 34)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(18, geo.safeAreaInsets.top))
                    .padding(.bottom, max(38, geo.safeAreaInsets.bottom) + 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
        .onChange(of: draft) { _, value in
            product.updateFlowSetup(value)
        }
        .alert("Block could not start", isPresented: $startFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(startFailureMessage)
        }
        .scalableAppTypography()
    }

    private var closeButton: some View {
        Button { product.cancelFlowSetup() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.ink)
                .frame(width: 44, height: 44)
                .background(AppColors.paperRaised.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("Close block setup")
    }

    private var workSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MetaLabel(text: "1 · What are you working on?", color: AppColors.coral)
            if product.activeFlowProjects.count > 1 || draft.projectID == nil {
                Picker("Project", selection: $draft.projectID) {
                    Text("Choose a project").tag(UUID?.none)
                    ForEach(product.activeFlowProjects) { project in
                        Text(project.title).tag(Optional(project.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.ink)
            } else if let projectID = draft.projectID,
                      let project = product.flowProject(id: projectID) {
                FlowText(project.title, style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
            }
            setupField("Specific task", prompt: "Build the Flow persistence migration", text: $draft.task)
            setupField("What would make this block complete?", prompt: "v8 migration implemented and tests green", text: $draft.definitionOfDone)
        }
    }

    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            MetaLabel(text: "2 · Set the conditions", color: AppColors.coral)
            choiceSection("How challenging does this feel?", values: FlowChallenge.allCases, selection: $draft.challenge) { $0.label }
            choiceSection("How equipped do you feel for it?", values: FlowSkillConfidence.allCases, selection: $draft.skillConfidence) { $0.label }
            VStack(alignment: .leading, spacing: 10) {
                FlowText("How will you know you're making progress?", style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                Picker("Feedback", selection: $draft.feedbackMechanism) {
                    ForEach(FlowFeedbackMechanism.allCases) { feedback in
                        Text(feedback.label).tag(feedback)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.ink)
                if draft.feedbackMechanism == .other {
                    FlowTextField(prompt: "A short feedback cue", text: $draft.customFeedback)
                }
            }
            if draft.sessionOrigin != .protocol {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        FlowText("Duration", style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Spacer()
                        FlowText("Suggested · \(product.suggestedFlowDuration) min", style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                    FlowLayout(spacing: 8) {
                        ForEach(product.flowDurationOptions, id: \.self) { minutes in
                            TonalPillButton(
                                title: "\(minutes) min",
                                isSelected: draft.selectedDuration == minutes,
                                showsSelectionIndicator: true
                            ) {
                                draft.selectedDuration = minutes
                            }
                        }
                    }
                }
            }
        }
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            MetaLabel(text: "3 · Environment", color: AppColors.coral)
            VStack(alignment: .leading, spacing: 10) {
                FlowText("Phone", style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                FlowLayout(spacing: 8) {
                    ForEach(availablePhoneSetups) { setup in
                        TonalPillButton(
                            title: setup.label,
                            isSelected: draft.phoneSetup == setup,
                            showsSelectionIndicator: true
                        ) {
                            draft.phoneSetup = setup
                        }
                    }
                }
                if draft.phoneSetup == .screenTimeProtected {
                    FlowText("Protection starts only when you tap Start block.", style: .footnote)
                        .foregroundStyle(AppColors.inkFaint)
                } else if draft.phoneSetup == .outsideReach {
                    FlowText("Saved as self-reported setup.", style: .footnote)
                        .foregroundStyle(AppColors.inkFaint)
                }
            }
            choiceSection("Sound", values: FlowSoundContext.allCases, selection: $draft.soundContext) { $0.label }
            setupField(
                "Browser / task scope (optional)",
                prompt: "One editor and one documentation tab",
                text: $draft.browserScope
            )
            if !eligiblePersonalRules.isEmpty {
                personalRulesSection
            }
        }
    }

    private var personalRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                FlowText("Personal Rules", style: .heroGoal)
                    .foregroundStyle(AppColors.ink)
                Spacer(minLength: 12)
                FlowText("Optional", style: .footnote)
                    .foregroundStyle(AppColors.inkFaint)
            }
            ForEach(eligiblePersonalRules) { rule in
                Toggle(isOn: ruleSelection(for: rule.id)) {
                    VStack(alignment: .leading, spacing: 3) {
                        FlowText(rule.title, style: .heroReason)
                            .foregroundStyle(AppColors.ink)
                        FlowText(rule.detail, style: .footnote)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                }
                .toggleStyle(.switch)
                .tint(AppColors.coral)
                .accessibilityHint("Applies this kept rule to the current block")
            }
        }
    }

    private var eligiblePersonalRules: [PersonalRule] {
        let eligibleContexts: [RuleContext] = [.stay, .deepWork, .general]
        return product.personalRules
            .filter { rule in
                rule.isActivelyInfluencing
                    && rule.matchingContexts.contains(where: eligibleContexts.contains)
            }
            .sorted { lhs, rhs in
                if lhs.category != rhs.category { return lhs.category.rawValue < rhs.category.rawValue }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var confirmedEligibleRuleIDs: [UUID] {
        let eligibleIDs = Set(eligiblePersonalRules.map(\.id))
        return draft.confirmedRuleIDs.filter(eligibleIDs.contains)
    }

    private func ruleSelection(for ruleID: UUID) -> Binding<Bool> {
        Binding(
            get: { draft.confirmedRuleIDs.contains(ruleID) },
            set: { isSelected in
                if isSelected {
                    if !draft.confirmedRuleIDs.contains(ruleID) {
                        draft.confirmedRuleIDs.append(ruleID)
                    }
                } else {
                    draft.confirmedRuleIDs.removeAll { $0 == ruleID }
                }
            }
        )
    }

    private var availablePhoneSetups: [FlowPhoneSetup] {
        if environmentStore.isConnected, environmentStore.selection != nil {
            return FlowPhoneSetup.allCases
        }
        return [.usual, .outsideReach]
    }

    private func start() {
        guard !isStarting else { return }
        isStarting = true
        product.updateFlowSetup(draft)
        var protectionActivated = false
        if draft.phoneSetup == .screenTimeProtected {
            protectionActivated = environmentStore.applySessionProtection()
            guard protectionActivated else {
                isStarting = false
                startFailureMessage = "Screen Time protection could not be confirmed. Choose another phone setup or try again."
                startFailed = true
                return
            }
        }
        let verification: EnvironmentVerificationState
        switch draft.phoneSetup {
        case .usual, .outsideReach: verification = .userReported
        case .screenTimeProtected:
            verification = protectionActivated ? .screenTimeIntervention : .unknown
        }
        let plan = FlowEnvironmentPlan(
            phoneSetup: draft.phoneSetup,
            soundContext: draft.soundContext,
            browserScope: draft.browserScope.flowNilIfBlank,
            appliedRuleIDs: confirmedEligibleRuleIDs,
            verification: verification,
            protectionActivated: protectionActivated
        )
        let arm = environmentArm(protectionActivated: protectionActivated)
        if !product.startFlowBlock(environmentPlan: plan, environmentArm: arm) {
            if protectionActivated { environmentStore.removeSessionProtection() }
            isStarting = false
            startFailureMessage = "The current Program or project state changed. Review the setup and try again."
            startFailed = true
        }
    }

    private func environmentArm(protectionActivated: Bool) -> SessionEnvironmentArm {
        switch draft.phoneSetup {
        case .usual:
            return SessionEnvironmentArm(
                condition: .unrestricted,
                manualIntervention: "Usual phone setup",
                protectedSelectionID: nil,
                protectionOffered: false,
                protectionAccepted: false,
                protectionActivated: false,
                phoneLocationSelfReport: "Usual setup"
            )
        case .outsideReach:
            return SessionEnvironmentArm(
                condition: .phoneAway,
                manualIntervention: "Phone outside reach",
                protectedSelectionID: nil,
                protectionOffered: false,
                protectionAccepted: false,
                protectionActivated: false,
                phoneLocationSelfReport: "Outside reach"
            )
        case .screenTimeProtected:
            return SessionEnvironmentArm(
                condition: protectionActivated ? .protected : .unrestricted,
                manualIntervention: nil,
                protectedSelectionID: environmentStore.selection?.id,
                protectionOffered: true,
                protectionAccepted: true,
                protectionActivated: protectionActivated,
                phoneLocationSelfReport: nil
            )
        }
    }

    private func setupField(
        _ label: String,
        prompt: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowText(label, style: .heroGoal)
                .foregroundStyle(AppColors.ink)
            FlowTextField(prompt: prompt, text: text, axis: .vertical)
        }
    }

    private func choiceSection<Value: Identifiable & Equatable>(
        _ title: String,
        values: [Value],
        selection: Binding<Value>,
        label: @escaping (Value) -> String
    ) -> some View where Value.ID: Hashable {
        VStack(alignment: .leading, spacing: 10) {
            FlowText(title, style: .heroGoal)
                .foregroundStyle(AppColors.ink)
            FlowLayout(spacing: 8) {
                ForEach(values) { value in
                    TonalPillButton(
                        title: label(value),
                        isSelected: selection.wrappedValue == value,
                        showsSelectionIndicator: true
                    ) {
                        selection.wrappedValue = value
                    }
                }
            }
        }
    }
}

private struct FlowTextField: View {
    let prompt: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        TextField(prompt, text: $text, axis: axis)
            .font(.custom("PlusJakartaSans-Medium", size: 16, relativeTo: .body))
            .foregroundStyle(AppColors.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(minHeight: 56)
            .background(AppColors.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Quiet running block

struct FlowFocusedSessionView: View {
    @ObservedObject var product: ProductStore
    let record: SessionRecord
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize: CGFloat = 56

    private var plan: FlowBlockPlan? {
        record.flowParticipation.flatMap { product.flowPlan(id: $0.flowPlanID) }
    }

    private var project: FlowProject? {
        record.flowParticipation.flatMap { product.flowProject(id: $0.flowProjectID) }
    }

    private var phoneStatusLabel: String? {
        guard let setup = plan?.environmentPlan.phoneSetup else { return nil }
        if setup == .screenTimeProtected,
           record.environment?.protectionActivated != true {
            return "Screen Time not active"
        }
        return setup.label
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = max(0, Int(context.date.timeIntervalSince(record.date)))
                let safeTargetMinutes = min(max(record.targetMinutes, 10), 120)
                let reached = elapsed >= safeTargetMinutes * 60
                ZStack {
                    AmbientBackground()
                    VStack(spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                Spacer(minLength: 24)
                                MetaLabel(text: project?.title ?? "Project block", color: AppColors.coral)
                                    .multilineTextAlignment(.center)
                                FlowText(plan?.task ?? record.evidence?.stay?.task ?? "One task", style: .heroGoal)
                                    .foregroundStyle(AppColors.ink)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 18)
                                if let done = plan?.definitionOfDone {
                                    VStack(spacing: 5) {
                                        MetaLabel(text: "Complete when")
                                        FlowText(done, style: .heroReason)
                                            .foregroundStyle(AppColors.inkSoft)
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.top, 18)
                                }
                                Text(flowElapsedText(elapsed))
                                    .font(Font(AppTypography.plusJakarta(size: timerFontSize, weight: 300)))
                                    .foregroundStyle(AppColors.ink)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                                    .contentTransition(reduceMotion ? .identity : .numericText())
                                    .padding(.top, 28)
                                    .accessibilityLabel("Elapsed time")
                                    .accessibilityValue(flowAccessibleElapsedText(elapsed))
                                FlowText("Target: \(safeTargetMinutes) min", style: .footnote)
                                    .foregroundStyle(AppColors.inkFaint)
                                    .padding(.top, 7)
                                if let phone = phoneStatusLabel {
                                    Label(phone, systemImage: "iphone")
                                        .font(.custom("PlusJakartaSans-Medium", size: 12, relativeTo: .body))
                                        .foregroundStyle(AppColors.inkFaint)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 20)
                                }
                                Button { product.markSwitch() } label: {
                                    Label("I switched", systemImage: "arrow.turn.down.right")
                                        .font(.custom("PlusJakartaSans-SemiBold", size: 13, relativeTo: .body))
                                        .foregroundStyle(AppColors.inkFaint)
                                        .padding(.horizontal, 14)
                                        .frame(minHeight: 44)
                                        .background(AppColors.paperRaised.opacity(0.8))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(PressScaleStyle())
                                .padding(.top, 18)
                                Spacer(minLength: 24)
                            }
                            .frame(
                                minHeight: max(
                                    0,
                                    geo.size.height
                                        - max(18, geo.safeAreaInsets.top)
                                        - max(22, geo.safeAreaInsets.bottom)
                                        - 150
                                )
                            )
                            .frame(maxWidth: .infinity)
                        }

                        VStack(spacing: 6) {
                            PrimaryPillButton(
                                title: reached ? "Finish block" : "Keep going",
                                symbol: reached ? "checkmark" : nil,
                                isEnabled: reached
                            ) {
                                product.finishRunning(endedEarly: false)
                            }
                            Button { product.finishRunning(endedEarly: true) } label: {
                                FlowText("End early", style: .smallLink)
                                    .foregroundStyle(AppColors.inkFaint)
                                    .frame(minHeight: 44)
                            }
                        }
                        .padding(.top, 14)
                        .overlay(alignment: .top) {
                            Divider().overlay(AppColors.hairline)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(18, geo.safeAreaInsets.top))
                    .padding(.bottom, max(22, geo.safeAreaInsets.bottom) + 6)
                }
            }
            .ignoresSafeArea()
        }
        .scalableAppTypography()
    }

    private func flowElapsedText(_ elapsed: Int) -> String {
        String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private func flowAccessibleElapsedText(_ elapsed: Int) -> String {
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return "\(minutes) minutes, \(seconds) seconds"
    }
}

// MARK: - Four-signal reflection

struct FlowBlockReflectionView: View {
    @ObservedObject var product: ProductStore
    let record: SessionRecord
    @State private var absorption: FlowAbsorption?
    @State private var time: FlowTimePerception?
    @State private var desire: FlowDesireToContinue?
    @State private var done: FlowDoneOutcome?
    @State private var note = ""

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        MetaLabel(
                            text: record.completed ? "Block complete" : "Block ended",
                            color: AppColors.coral
                        )
                        EditorialHeadline(text: "What did this block feel like?")
                            .padding(.top, 14)
                        FlowText(
                            record.endedEarly
                                ? "This block still taught REBOOT something."
                                : "Four short signals, without labeling the state.",
                            style: .todaySentence
                        )
                        .foregroundStyle(AppColors.inkSoft)
                        .padding(.top, 12)

                        reflectionChoice("Absorption", values: FlowAbsorption.allCases, selection: $absorption) { $0.label }
                            .padding(.top, 30)
                        reflectionChoice("Time felt", values: FlowTimePerception.allCases, selection: $time) { $0.label }
                            .padding(.top, 24)
                        reflectionChoice("Want to continue", values: FlowDesireToContinue.allCases, selection: $desire) { $0.label }
                            .padding(.top, 24)
                        reflectionChoice("Definition of Done", values: FlowDoneOutcome.allCases, selection: $done) { $0.label }
                            .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 8) {
                            FlowText("One note (optional)", style: .heroGoal)
                                .foregroundStyle(AppColors.ink)
                            FlowTextField(prompt: "A concise observation", text: $note, axis: .vertical)
                        }
                        .padding(.top, 24)

                        PrimaryPillButton(
                            title: "Save block evidence",
                            symbol: "checkmark",
                            isEnabled: canSave
                        ) {
                            save()
                        }
                        .padding(.top, 32)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(22, geo.safeAreaInsets.top) + 10)
                    .padding(.bottom, max(38, geo.safeAreaInsets.bottom) + 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
        .scalableAppTypography()
    }

    private var canSave: Bool {
        absorption != nil && time != nil && desire != nil && done != nil
    }

    private func save() {
        product.saveDoneSession(SessionReflection(
            flowReflection: FlowBlockReflection(
                absorption: absorption,
                timePerception: time,
                desireToContinue: desire,
                definitionOfDoneOutcome: done,
                note: note.flowNilIfBlank
            )
        ))
    }

    private func reflectionChoice<Value: Identifiable & Equatable>(
        _ title: String,
        values: [Value],
        selection: Binding<Value?>,
        label: @escaping (Value) -> String
    ) -> some View where Value.ID: Hashable {
        VStack(alignment: .leading, spacing: 10) {
            FlowText(title, style: .heroGoal)
                .foregroundStyle(AppColors.ink)
            FlowLayout(spacing: 8) {
                ForEach(values) { value in
                    TonalPillButton(
                        title: label(value),
                        isSelected: selection.wrappedValue == value,
                        showsSelectionIndicator: true
                    ) {
                        selection.wrappedValue = value
                    }
                }
            }
        }
    }
}

// MARK: - Today integration

struct TodayFlowBlockCard: View {
    @ObservedObject var product: ProductStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MetaLabel(text: "Today's block", color: AppColors.coral)
            FlowText("Use a real project.", style: .heroGoal)
                .foregroundStyle(AppColors.ink)
            FlowText("This session can teach REBOOT about your deep-work conditions.", style: .heroReason)
                .foregroundStyle(AppColors.inkSoft)
            Button(action: open) {
                GlassPill(
                    text: product.activeFlowProjects.isEmpty ? "Create a Flow project" : "Use a project",
                    symbol: "arrow.up.right",
                    tint: AppColors.ink
                )
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.vertical, 8)
        .scalableAppTypography()
    }

    private func open() {
        if let project = product.activeFlowProjects.first {
            _ = product.beginFlowSetup(projectID: project.id, origin: .protocol)
        } else {
            product.openFlowLab(origin: .protocol)
        }
    }
}

private struct FlowText: View {
    let text: String
    let style: AppTypography.Style

    init(_ text: String, style: AppTypography.Style) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .type(style)
    }
}

private extension String {
    var flowNilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
