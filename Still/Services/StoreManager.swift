import StoreKit
import SwiftUI

@MainActor
final class StoreManager: ObservableObject {
    static let proProductID = "com.allinoneapp.still.pro"

    @Published private(set) var isProUnlocked = false
    @Published private(set) var proProduct: Product?
    @Published private(set) var purchaseInProgress = false
    @Published var purchaseError: String?

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task { await refreshStatus() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public API

    func refreshStatus() async {
        await loadProduct()
        await updateEntitlement()
    }

    func purchase() async {
        guard let product = proProduct else {
            purchaseError = "Product not available. Check your connection."
            return
        }
        purchaseInProgress = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isProUnlocked = true
                UserDefaults.standard.set(true, forKey: "stillProUnlocked")
                StillHaptics.success()
                CloudPreferencesSync.schedulePushDebounced()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Try again."
        }

        purchaseInProgress = false
    }

    func redeemProAccess() {
        isProUnlocked = true
        UserDefaults.standard.set(true, forKey: "stillProUnlocked")
        StillHaptics.success()
        CloudPreferencesSync.schedulePushDebounced()
    }

    func restorePurchases() async {
        purchaseInProgress = true
        purchaseError = nil
        try? await AppStore.sync()
        await updateEntitlement()
        purchaseInProgress = false
        if !isProUnlocked {
            purchaseError = "No previous purchase found."
        } else {
            CloudPreferencesSync.schedulePushDebounced()
        }
    }

    // MARK: - Private

    private func loadProduct() async {
        guard proProduct == nil else { return }
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            proProduct = nil
        }
    }

    private func updateEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.proProductID {
                isProUnlocked = true
                return
            }
        }
        // Fall through — check UserDefaults cache for offline grace
        if UserDefaults.standard.bool(forKey: "stillProUnlocked") {
            isProUnlocked = true
            return
        }
        isProUnlocked = false
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await MainActor.run {
                        if transaction.productID == StoreManager.proProductID {
                            self.isProUnlocked = true
                            UserDefaults.standard.set(true, forKey: "stillProUnlocked")
                            CloudPreferencesSync.schedulePushDebounced()
                        }
                    }
                }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }
}
