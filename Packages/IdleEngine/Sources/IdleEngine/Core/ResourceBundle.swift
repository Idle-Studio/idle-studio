import Foundation

/// A named collection of resource amounts (e.g. ["gold": 500, "population": 30]).
/// All arithmetic uses `Decimal` — never `Double`.
public struct ResourceBundle: Sendable, Equatable, Codable {

    public private(set) var amounts: [String: Decimal]

    public static let zero = ResourceBundle()

    public init(_ amounts: [String: Decimal] = [:]) {
        self.amounts = amounts.filter { $0.value != 0 }
    }

    // MARK: - Subscript

    public subscript(resourceID: String) -> Decimal {
        get { amounts[resourceID] ?? .zero }
        set {
            if newValue == 0 {
                amounts.removeValue(forKey: resourceID)
            } else {
                amounts[resourceID] = newValue
            }
        }
    }

    // MARK: - Affordability

    /// Returns true if this bundle has ≥ each amount in `cost`.
    /// NaN in a cost (Decimal overflow) is treated as unaffordable.
    public func canAfford(_ cost: ResourceBundle) -> Bool {
        cost.amounts.allSatisfy { id, required in
            guard !required.isNaN else { return false }
            return (amounts[id] ?? 0) >= required
        }
    }

    // MARK: - Operators

    public static func + (lhs: ResourceBundle, rhs: ResourceBundle) -> ResourceBundle {
        var result = lhs
        for (id, amount) in rhs.amounts {
            result.amounts[id] = (result.amounts[id] ?? 0) + amount
        }
        return result
    }

    public static func - (lhs: ResourceBundle, rhs: ResourceBundle) -> ResourceBundle {
        var result = lhs
        for (id, amount) in rhs.amounts {
            let newVal = (result.amounts[id] ?? 0) - amount
            result.amounts[id] = newVal == 0 ? nil : newVal
        }
        return result
    }

    public static func * (lhs: ResourceBundle, rhs: Decimal) -> ResourceBundle {
        ResourceBundle(lhs.amounts.mapValues { $0 * rhs })
    }

    public static func += (lhs: inout ResourceBundle, rhs: ResourceBundle) {
        lhs = lhs + rhs
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: Decimal].self)
        self.amounts = raw.filter { $0.value != 0 }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(amounts)
    }
}
