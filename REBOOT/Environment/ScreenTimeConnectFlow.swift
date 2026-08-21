import SwiftUI
import FamilyControls

// MARK: - Editorial explainer (shown BEFORE Apple's permission UI)

struct ScreenTimeExplainerSheet: View {
    @ObservedObject var environmentStore: EnvironmentStore
    var onStateChanged: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                VStack(alignment: .leading, spacing: 0) {
                    MetaLabel(text: "Optional", color: AppColors.coral)

                    EditorialHeadline(text: "Protect your focus windows.")
                        .padding(.top, 16)

                    Text(
                        "Choose the apps that can wait while you work. " +
                        "REBOOT never blocks your phone — it learns the minimum friction that helps.",
                        style: .todaySentence
                    )
                    .foregroundStyle(AppColors.inkSoft)
                    .padding(.top, 14)

                    Text("REBOOT works fully without this.")
                        .type(.heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 20)

                    Spacer()

                    PrimaryPillButton(title: "Continue", symbol: "arrow.right") {
                        Task {
                            let result = await environmentStore.requestAuthorization()
                            if result.canProtect {
                                onStateChanged?()
                                showPicker = true
                            } else {
                                dismiss()
                            }
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Not now", style: .smallLink)
                            .foregroundStyle(AppColors.inkFaint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.top, max(20, geo.safeAreaInsets.top) + 12)
                .padding(.bottom, max(28, geo.safeAreaInsets.bottom) + 10)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPicker) {
            ActivitySelectionSheet(environmentStore: environmentStore, onConnected: { dismiss() }, onStateChanged: onStateChanged)
        }
    }
}

// MARK: - Activity selection (Apple FamilyActivityPicker)

struct ActivitySelectionSheet: View {
    @ObservedObject var environmentStore: EnvironmentStore
    var onConnected: (() -> Void)?
    var onStateChanged: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selection = FamilyActivitySelection()
    @State private var showWindows = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AmbientBackground()
                    VStack(spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                MetaLabel(text: "Protection", color: AppColors.coral)
                                EditorialHeadline(text: "What can wait while you work?")
                                    .padding(.top, 12)
                                Text(
                                    "Pick apps, categories or sites. REBOOT only ever protects what you choose.",
                                    style: .todaySentence
                                )
                                .foregroundStyle(AppColors.inkSoft)
                                .padding(.top, 10)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        }

                        FamilyActivityPicker(selection: $selection)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                        Button {
                            showWindows = true
                        } label: {
                            GlassPill(text: "Protected windows", symbol: "calendar", tint: AppColors.ink)
                        }
                        .padding(.top, 6)

                        PrimaryPillButton(title: "Save selection", symbol: "checkmark") {
                            environmentStore.saveSelection(selection)
                            onStateChanged?()
                            onConnected?()
                            dismiss()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, max(28, geo.safeAreaInsets.bottom) + 10)
                    }
                }
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showWindows) {
            ProtectedWindowsSheet(environmentStore: environmentStore, onStateChanged: onStateChanged)
        }
    }
}

// MARK: - Protected windows (one minimal create/edit flow)

struct ProtectedWindowsSheet: View {
    @ObservedObject var environmentStore: EnvironmentStore
    var onStateChanged: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var editing: ProtectedWindow?
    @State private var createNew = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AmbientBackground()
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            MetaLabel(text: "Windows", color: AppColors.coral)
                            EditorialHeadline(text: "Reusable protection.")
                                .padding(.top, 8)
                            Text(
                                "A protected window shields your selected distractions automatically — only when you approve it.",
                                style: .todaySentence
                            )
                            .foregroundStyle(AppColors.inkSoft)

                            Toggle(isOn: Binding(
                                get: { environmentStore.thresholdApproved },
                                set: {
                                    environmentStore.setThresholdApproved($0)
                                    onStateChanged?()
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Threshold rule", style: .heroGoal)
                                        .foregroundStyle(AppColors.ink)
                                    Text("Protect after 20 minutes of scrolling today")
                                        .type(.heroReason)
                                        .foregroundStyle(AppColors.inkSoft)
                                }
                            }
                            .tint(AppColors.coral)
                            .padding(.top, 6)

                            ForEach(environmentStore.windows) { window in
                                windowRow(window)
                            }

                            PrimaryPillButton(title: "New window", symbol: "plus") {
                                createNew = true
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, max(20, geo.safeAreaInsets.top) + 12)
                        .padding(.bottom, 60)
                    }
                }
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                }
            }
        }
        .sheet(isPresented: $createNew) {
            ProtectedWindowEditor(environmentStore: environmentStore)
        }
        .sheet(item: $editing) { window in
            ProtectedWindowEditor(environmentStore: environmentStore, window: window)
        }
        .onChange(of: environmentStore.windows, initial: false) { _, _ in
            onStateChanged?()
        }
    }

    private func windowRow(_ window: ProtectedWindow) -> some View {
        PaperCard(radius: 22, padding: 16) {
            Button {
                editing = window
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(window.name, style: .heroGoal)
                            .foregroundStyle(AppColors.ink)
                        Text(windowSummary(window), style: .heroReason)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                    Spacer()
                    if window.enabled {
                        Circle().fill(AppColors.coral).frame(width: 8, height: 8)
                    } else {
                        Circle().fill(AppColors.hairline).frame(width: 8, height: 8)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func windowSummary(_ window: ProtectedWindow) -> String {
        let days = window.weekdays.sorted().map { Self.dayNames[$0] ?? "" }.joined(separator: " ")
        let start = String(format: "%02d:%02d", window.startMinutes / 60, window.startMinutes % 60)
        let end = String(format: "%02d:%02d", window.endMinutes / 60, window.endMinutes % 60)
        return "\(days) · \(start)–\(end)"
    }

    private static let dayNames: [Int: String] = [
        1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat",
    ]
}

struct ProtectedWindowEditor: View {
    @ObservedObject var environmentStore: EnvironmentStore
    var window: ProtectedWindow?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(2 * 3600)

    private let allDays: [Int] = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                VStack(alignment: .leading, spacing: 0) {
                    MetaLabel(text: "Window", color: AppColors.coral)
                    EditorialHeadline(text: window == nil ? "New protected window." : "Edit window.")
                        .padding(.top, 12)

                    TextField("Name", text: $name)
                        .font(Font(AppTypography.plusJakarta(size: 17, weight: 500)))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .background(Capsule().fill(AppColors.paperRaised))
                        .padding(.top, 20)

                    Text("Days", style: .heroGoal)
                        .foregroundStyle(AppColors.ink)
                        .padding(.top, 24)
                    FlowLayout(spacing: 8) {
                        ForEach(allDays, id: \.self) { day in
                            TonalPillButton(
                                title: Self.dayShort[day] ?? "",
                                isSelected: weekdays.contains(day)
                            ) {
                                if weekdays.contains(day) {
                                    weekdays.remove(day)
                                } else {
                                    weekdays.insert(day)
                                }
                            }
                        }
                    }
                    .padding(.top, 12)

                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                        .padding(.top, 22)
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                        .padding(.top, 8)

                    Spacer()

                    PrimaryPillButton(title: "Save window", symbol: "checkmark") {
                        let cal = Calendar.current
                        let startComp = cal.dateComponents([.hour, .minute], from: start)
                        let endComp = cal.dateComponents([.hour, .minute], from: end)
                        var updated = window ?? ProtectedWindow(name: name.isEmpty ? "Focus window" : name)
                        updated.name = name.isEmpty ? "Focus window" : name
                        updated.weekdays = weekdays
                        updated.startMinutes = (startComp.hour ?? 9) * 60 + (startComp.minute ?? 0)
                        updated.endMinutes = (endComp.hour ?? 11) * 60 + (endComp.minute ?? 0)
                        updated.selectionID = environmentStore.selection?.id
                        environmentStore.upsertWindow(updated)
                        dismiss()
                    }
                    .padding(.bottom, max(28, geo.safeAreaInsets.bottom) + 10)
                }
                .padding(.horizontal, 24)
                .padding(.top, max(20, geo.safeAreaInsets.top) + 12)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard let window else { return }
            name = window.name
            weekdays = window.weekdays
            let cal = Calendar.current
            start = cal.date(from: DateComponents(hour: window.startMinutes / 60, minute: window.startMinutes % 60)) ?? start
            end = cal.date(from: DateComponents(hour: window.endMinutes / 60, minute: window.endMinutes % 60)) ?? end
        }
    }

    private static let dayShort: [Int: String] = [
        2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat", 1: "Sun",
    ]
}
