import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState
    @ObservedObject var product: ProductStore
    @ObservedObject var environmentStore: EnvironmentStore
    @ObservedObject var subscriptionStore: SubscriptionStore
    @ObservedObject var notificationService: NotificationService
    @State private var showDebug = false

    var body: some View {
        ZStack {
            switch state.phase {
            case .cinematic:
                CinematicOnboardingView(state: state) {
                    #if DEBUG
                    showDebug = true
                    #endif
                }
                .transition(.opacity)
            case .dissolve:
                DissolveView { state.patch(phase: .diagnosis) }
                    .transition(.opacity)
            case .diagnosis:
                DiagnosisFlowView(state: state) {
                    #if DEBUG
                    showDebug = true
                    #endif
                }
                .transition(.opacity)
            case .report:
                StartingPointView(state: state)
                    .transition(.opacity)
            case .today:
                ProductRootView(
                    product: product,
                    state: state,
                    environmentStore: environmentStore,
                    subscriptionStore: subscriptionStore,
                    notificationService: notificationService
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: state.phase)
        .background(StatusBarStyleBridge(light: state.phase == .cinematic || state.phase == .dissolve))
        #if DEBUG
        .sheet(isPresented: $showDebug) {
            DebugNavView(state: state, product: product)
        }
        #endif
    }
}

/// Lets each phase choose the status-bar style (light on black cinema screens,
/// dark on paper screens) without leaving SwiftUI.
struct StatusBarStyleBridge: UIViewControllerRepresentable {
    let light: Bool

    func makeUIViewController(context: Context) -> StatusBarHost {
        StatusBarHost(light: light)
    }

    func updateUIViewController(_ controller: StatusBarHost, context: Context) {
        controller.light = light
    }
}

final class StatusBarHost: UIViewController {
    var light: Bool {
        didSet {
            guard light != oldValue else { return }
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    init(light: Bool) {
        self.light = light
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        light ? .lightContent : .darkContent
    }
}
