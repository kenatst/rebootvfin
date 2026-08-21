import Foundation
import FamilyControls
import ManagedSettings

// MARK: - Capability

enum EnvironmentCapability: Equatable {
    case unavailable
    case notRequested
    case authorized
    case authorizedWithDataAccess
    case denied
    case revoked
    case error(String)

    var canProtect: Bool {
        switch self {
        case .authorized, .authorizedWithDataAccess: return true
        default: return false
        }
    }
}

// MARK: - Provider protocol

/// The adaptive engine consumes capabilities, never Apple-specific details.
protocol DigitalEnvironmentProvider: AnyObject {
    var capability: EnvironmentCapability { get }
    /// Whether richer app/domain usage data is actually available and authorized.
    var supportsRichData: Bool { get }
    func refreshCapability()
    func requestAuthorization() async -> EnvironmentCapability
    /// Applies session-bound shields for the persisted selection.
    func apply(selection: ProtectedSelection) -> Bool
    func removeProtection()
}

// MARK: - Apple Screen Time provider

final class AppleScreenTimeProvider: DigitalEnvironmentProvider {
    private let center = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()

    private(set) var supportsRichData = false

    var capability: EnvironmentCapability {
        switch center.authorizationStatus {
        case .notDetermined:
            return .notRequested
        case .denied:
            return .denied
        case .approved:
            // Rich data access is region/device dependent and only detectable at
            // runtime on a device with the production entitlement. Simulator and
            // unsigned builds keep the privacy-preserving token path.
            return .authorized
        @unknown default:
            return .unavailable
        }
    }

    func refreshCapability() {}

    func requestAuthorization() async -> EnvironmentCapability {
        do {
            try await center.requestAuthorization(for: .individual)
            return capability
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func apply(selection: ProtectedSelection) -> Bool {
        guard capability.canProtect,
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selection.data) else {
            return false
        }
        store.shield.applications = decoded.applicationTokens
        if !decoded.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(decoded.categoryTokens)
        }
        store.shield.webDomains = decoded.webDomainTokens
        return true
    }

    func removeProtection() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}

// MARK: - Manual provider (REBOOT never depends on Screen Time)

final class ManualEnvironmentProvider: DigitalEnvironmentProvider {
    var capability: EnvironmentCapability { .authorized }
    var supportsRichData = false
    func refreshCapability() {}
    func requestAuthorization() async -> EnvironmentCapability { .authorized }
    func apply(selection: ProtectedSelection) -> Bool { true }
    func removeProtection() {}
}
