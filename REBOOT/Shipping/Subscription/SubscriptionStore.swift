import Foundation
import StoreKit

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var status: SubscriptionStatus = .free
    @Published private(set) var products: [Product] = []
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var isRestoring: Bool = false
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var isStoreKitAvailable: Bool = true

    private var transactionListenerTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private static let cacheKey = "reboot.cached.entitlement.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCachedEntitlement()
        startTransactionListener()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Transaction Updates Listener (StoreKit 2)

    private func startTransactionListener() {
        transactionListenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await self?.updateSubscriptionStatus()
                    await transaction?.finish()
                } catch {
                    print("StoreKit transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Product Fetching

    func loadProducts() async {
        do {
            let fetchedProducts = try await Product.products(for: AppConfig.allProductIDs)
            self.products = fetchedProducts.sorted { $0.price > $1.price }
            self.yearlyProduct = fetchedProducts.first { $0.id == AppConfig.yearlyProductID }
            self.monthlyProduct = fetchedProducts.first { $0.id == AppConfig.monthlyProductID }
            self.isStoreKitAvailable = true
        } catch {
            print("Failed to fetch StoreKit products: \(error)")
            self.isStoreKitAvailable = false
            // Keep existing products if any or fallback to offline cached entitlement
        }
    }

    // MARK: - Purchase Flow

    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateSubscriptionStatus()
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                self.errorMessage = "Purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async -> Bool {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            return status.isPremium
        } catch {
            self.errorMessage = "Unable to restore purchases. Please check your network connection."
            return false
        }
    }

    // MARK: - Entitlement Verification & Status Calculation

    func updateSubscriptionStatus() async {
        var highestEntitlement: SubscriptionStatus = .free
        var latestExpiry: Date? = nil
        var activeProductID: String? = nil

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard AppConfig.allProductIDs.contains(transaction.productID) else { continue }

            if let revocationDate = transaction.revocationDate {
                highestEntitlement = .revoked(productId: transaction.productID, revokedAt: revocationDate)
                break
            }

            if let expirationDate = transaction.expirationDate {
                latestExpiry = expirationDate
                activeProductID = transaction.productID

                if expirationDate > Date() {
                    var isTrial = false
                    if #available(iOS 17.2, *) {
                        isTrial = transaction.offer?.type == .introductory
                    } else {
                        isTrial = transaction.offerType == .introductory
                    }
                    highestEntitlement = .subscribed(
                        productId: transaction.productID,
                        expiresAt: expirationDate,
                        isTrial: isTrial
                    )
                } else if highestEntitlement == .free {
                    highestEntitlement = .expired(productId: transaction.productID, expiredAt: expirationDate)
                }
            } else {
                // Non-expiring lifetime entitlement or active auto-renewing subscription without expiration date
                highestEntitlement = .subscribed(productId: transaction.productID, expiresAt: nil, isTrial: false)
                activeProductID = transaction.productID
            }
        }

        self.status = highestEntitlement
        cacheEntitlement(status: highestEntitlement, productId: activeProductID, expirationDate: latestExpiry)
    }

    // MARK: - Offline Caching

    private func cacheEntitlement(status: SubscriptionStatus, productId: String?, expirationDate: Date?) {
        let cached = CachedEntitlement(
            status: status,
            cachedAt: Date(),
            productId: productId,
            expirationDate: expirationDate
        )
        if let data = try? JSONEncoder().encode(cached) {
            defaults.set(data, forKey: Self.cacheKey)
        }
    }

    private func loadCachedEntitlement() {
        guard let data = defaults.data(forKey: Self.cacheKey),
              let cached = try? JSONDecoder().decode(CachedEntitlement.self, from: data) else {
            return
        }
        if cached.isValidForOfflineUse {
            self.status = cached.status
        }
    }

    // MARK: - JWS Verification

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Mock for Tests & Previews

    func setMockStatus(_ newStatus: SubscriptionStatus) {
        self.status = newStatus
    }
}
