import SwiftUI

@main
struct REBOOTApp: App {
    @StateObject private var state = AppState()
    @StateObject private var product: ProductStore
    @StateObject private var environmentStore = EnvironmentStore()

    init() {
        let state = AppState()
        _state = StateObject(wrappedValue: state)
        let product = ProductStore(diagnosisAnswers: state.answers)
        _product = StateObject(wrappedValue: product)
        let environmentStore = EnvironmentStore()
        _environmentStore = StateObject(wrappedValue: environmentStore)
        product.onObservationSaved = { [weak environmentStore] observation in
            Task { @MainActor in
                environmentStore?.appendObservation(observation)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(state: state, product: product, environmentStore: environmentStore)
                .preferredColorScheme(.light)
                .tint(AppColors.ink)
        }
    }
}
