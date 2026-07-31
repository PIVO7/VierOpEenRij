import Foundation
import Observation
import StoreKit

/// Weet of het gezin de volledige versie heeft. Eén niet-verbruikbare,
/// gezinsdeelbare aankoop ontgrendelt alles; de laatste bekende stand staat
/// in UserDefaults zodat de app ook offline meteen goed opstart.
@MainActor
@Observable
final class EntitlementStore {
    static let familyProductID = "com.pivo7.vieropeenrij.gezin"
    private static let cacheKey = "gezin-ontgrendeld"

    private(set) var isFamilyUnlocked: Bool
    private(set) var familyProduct: Product?

    private var updatesTask: Task<Void, Never>?

    init() {
        isFamilyUnlocked = UserDefaults.standard.bool(forKey: Self.cacheKey)
        updatesTask = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshEntitlements()
            }
        }
        Task { await load() }
    }

    /// Voor previews en tests, zonder StoreKit.
    init(previewUnlocked: Bool) {
        isFamilyUnlocked = previewUnlocked
    }

    func load() async {
        familyProduct = try? await Product.products(for: [Self.familyProductID]).first
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.familyProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isFamilyUnlocked = unlocked
        UserDefaults.standard.set(unlocked, forKey: Self.cacheKey)
    }

    /// Meldt of de aankoop gelukt is.
    func purchaseFamily() async -> Bool {
        if familyProduct == nil {
            await load()
        }
        guard let product = familyProduct,
              let result = try? await product.purchase() else { return false }

        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            await refreshEntitlements()
            return true
        }
        return false
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
