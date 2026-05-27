import Foundation
import StoreKit
import AppCore

/// Thin wrapper around StoreKit 2 for the Mac App Store SKU path.
/// The direct-distribution path uses `LicenseService` instead.
@MainActor
public final class StoreKitSubscriptionService {

    public enum ProductID: String, CaseIterable, Sendable {
        case oneYear = "my.docked.oneyear"
        case lifetime = "my.docked.lifetime"
        case syncAnnual = "my.docked.sync.annual"
    }

    public private(set) var entitlements: Set<Entitlement> = License.entitlements(for: .free)
    public private(set) var products: [Product] = []
    private var observerTask: Task<Void, Never>?

    public init() {}

    public func start() {
        observerTask = Task { await listenForTransactions() }
        Task { await refreshProducts(); await refreshEntitlements() }
    }

    public func stop() {
        observerTask?.cancel()
    }

    public func refreshProducts() async {
        do {
            products = try await Product.products(for: ProductID.allCases.map(\.rawValue))
        } catch {
            products = []
        }
    }

    public func purchase(_ productID: ProductID) async throws -> Product.PurchaseResult {
        guard let product = products.first(where: { $0.id == productID.rawValue }) else {
            throw LicenseError.invalidKey
        }
        let result = try await product.purchase()
        if case .success(let verification) = result, case .verified(let txn) = verification {
            await txn.finish()
            await refreshEntitlements()
        }
        return result
    }

    public func refreshEntitlements() async {
        var newEnt: Set<Entitlement> = License.entitlements(for: .free)
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            switch txn.productID {
            case ProductID.oneYear.rawValue: newEnt.formUnion(License.entitlements(for: .oneYear))
            case ProductID.lifetime.rawValue: newEnt.formUnion(License.entitlements(for: .lifetime))
            case ProductID.syncAnnual.rawValue: newEnt.insert(.cloudSync)
            default: break
            }
        }
        entitlements = newEnt
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let txn) = result {
                await txn.finish()
                await refreshEntitlements()
            }
        }
    }
}
