import SwiftUI

@main
struct REBOOTApp: App {
    @StateObject private var state = AppState()
    @StateObject private var product: ProductStore
    @StateObject private var environmentStore = EnvironmentStore()
    @StateObject private var subscriptionStore = SubscriptionStore()
    @StateObject private var notificationService = NotificationService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let state = AppState()
        _state = StateObject(wrappedValue: state)
        let product = ProductStore(diagnosisAnswers: state.answers)
        _product = StateObject(wrappedValue: product)
        let environmentStore = EnvironmentStore()
        _environmentStore = StateObject(wrappedValue: environmentStore)
        let subscriptionStore = SubscriptionStore()
        _subscriptionStore = StateObject(wrappedValue: subscriptionStore)
        let notificationService = NotificationService()
        _notificationService = StateObject(wrappedValue: notificationService)

        product.onObservationSaved = { [weak environmentStore] observation in
            Task { @MainActor in
                environmentStore?.appendObservation(observation)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                state: state,
                product: product,
                environmentStore: environmentStore,
                subscriptionStore: subscriptionStore,
                notificationService: notificationService
            )
            .preferredColorScheme(.light)
            .tint(AppColors.ink)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    environmentStore.refreshCapability()
                    Task {
                        await subscriptionStore.updateSubscriptionStatus()
                        await notificationService.refreshAuthorizationStatus()
                    }
                }
            }
            .onChange(of: subscriptionStore.status) { _, newStatus in
                // Entitlement truth feeds ProductStore routing decisions
                // (e.g. whether the first-value paywall may appear).
                product.isEntitlementPremium = newStatus.isPremium
            }
            .onAppear {
                product.isEntitlementPremium = subscriptionStore.status.isPremium
            }
        }
    }
}
