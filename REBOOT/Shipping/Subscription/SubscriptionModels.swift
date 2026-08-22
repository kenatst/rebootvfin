import Foundation

// MARK: - Subscription Status

enum SubscriptionStatus: Codable, Equatable {
    case free
    case subscribed(productId: String, expiresAt: Date?, isTrial: Bool)
    case gracePeriod(productId: String, expiresAt: Date?)
    case expired(productId: String, expiredAt: Date)
    case revoked(productId: String, revokedAt: Date)

    var isPremium: Bool {
        switch self {
        case .subscribed, .gracePeriod:
            return true
        case .free, .expired, .revoked:
            return false
        }
    }

    var isTrial: Bool {
        if case .subscribed(_, _, let isTrial) = self {
            return isTrial
        }
        return false
    }

    var displayLabel: String {
        switch self {
        case .free:
            return "REBOOT Free"
        case .subscribed(_, _, let isTrial):
            return isTrial ? "7-Day Free Trial" : "REBOOT Premium"
        case .gracePeriod:
            return "Grace Period"
        case .expired:
            return "Expired"
        case .revoked:
            return "Subscription Revoked"
        }
    }

    var formattedExpiry: String? {
        switch self {
        case .subscribed(_, let expiresAt, _), .gracePeriod(_, let expiresAt):
            guard let expiresAt else { return nil }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: expiresAt)
        case .expired(_, let expiredAt):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Expired on \(formatter.string(from: expiredAt))"
        case .free, .revoked:
            return nil
        }
    }
}

// MARK: - Cached Entitlement for Offline Support

struct CachedEntitlement: Codable, Equatable {
    var status: SubscriptionStatus
    var cachedAt: Date
    var productId: String?
    var expirationDate: Date?

    var isValidForOfflineUse: Bool {
        // Cached entitlements remain active offline if expiration date is in the future
        // or within 48 hours grace period for offline network outages
        if let expirationDate {
            return expirationDate.addingTimeInterval(48 * 3600) > Date()
        }
        return status.isPremium
    }
}

// MARK: - Store Product Presentation Model

struct StoreProductPresentation: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
    let price: Decimal
    let isYearly: Bool
    let monthlyEquivalentPrice: String?
    let hasFreeTrial: Bool
    let trialPeriodText: String?
}
