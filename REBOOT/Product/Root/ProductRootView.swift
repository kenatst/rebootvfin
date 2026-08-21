import SwiftUI

/// Root of the product world: Today (signature), session flow, and the empty
/// Train / Program / Profile shells behind the floating glass tab bar.
struct ProductRootView: View {
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore

    var body: some View {
        ZStack {
            switch product.phase {
            case .today:
                tabContent
                    .transition(.opacity)
            case .running:
                SessionView(product: product)
                    .transition(.opacity)
            case .done:
                SessionDoneView(product: product)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: product.phase)
        .animation(.easeInOut(duration: 0.25), value: product.tab)
        .onChange(of: product.phase, initial: false) { old, new in
            if case .running = old, case .running = new {} else if case .running = old {
                // Session ended or was abandoned: protection must end too.
                environmentStore.removeSessionProtection()
            }
        }
#if DEBUG
        .onAppear {
            print("QA-PRESC day=\(product.day) mode=\(product.prescription.mode.rawValue) headline=\(product.prescription.headline) minutes=\(product.prescription.minutes) action=\(product.prescription.action)")
            if ProcessInfo.processInfo.arguments.contains("-qaAuto") {
                runQAAuto()
            }
        }
#endif
    }

#if DEBUG
    /// QA harness: drives one full loop — session → questions → save → next prescription.
    private func runQAAuto() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            product.beginSession()
            try? await Task.sleep(for: .seconds(2))
            product.finishRunning(actualMinutes: 10, endedEarly: false)
            try? await Task.sleep(for: .seconds(2))
            product.saveDoneSession(
                difficulty: 2,
                firstDistraction: "none",
                switches: 1,
                firstSwitchMinute: nil,
                energy: 4,
                environmentActionDone: true
            )
            print("QA-AUTO day=\(product.day) sessions=\(product.sessions.count) mode=\(product.prescription.mode.rawValue) headline=\(product.prescription.headline) stability=\(product.profile.attentionStability.value?.rawValue ?? "unknown") return=\(product.profile.returnAfterDistraction.value?.rawValue ?? "unknown")")
        }
    }
#endif

    @ViewBuilder
    private var tabContent: some View {
        ZStack(alignment: .bottom) {
            switch product.tab {
            case .today:
                TodayView(product: product, environmentStore: environmentStore)
            case .train:
                TrainTab()
            case .program:
                ProgramTab(product: product)
            case .profile:
                ProfileTab(product: product)
            }
            FloatingGlassTabBar(selection: $product.tab)
        }
    }
}
