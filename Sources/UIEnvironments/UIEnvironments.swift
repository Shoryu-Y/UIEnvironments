import UIKit

/// A container that provides read-only access to environment values
/// resolved for a specific responder, such as a `UIView`,
/// `UIViewController`, `UIWindow`, or `UIWindowScene`.
///
@MainActor public class UIEnvironments {
    private enum CachedOverride {
        case value(Sendable)
        case missing
    }

    private static var cacheGeneration: UInt64 = 1

    /// Returns the current value associated with the given environment definition.
    ///
    /// Pass an environment definition type and read its value for the receiver,
    /// taking into account any `environmentOverrides` set in the surrounding
    /// view, view controller, or window scene hierarchy. If no value has been
    /// provided, the definition's `defaultValue` is used.
    ///
    public subscript<Key: UIEnvironmentDefinition>(type: Key.Type) -> Key.Value {
        let identifier = ObjectIdentifier(type)

        if localCacheGeneration != Self.cacheGeneration {
            cache.removeAll(keepingCapacity: true)
            localCacheGeneration = Self.cacheGeneration
        }

        if let cached = cache[identifier] {
            switch cached {
            case .value(let value):
                return (value as? Key.Value) ?? Key.defaultValue
            case .missing:
                return Key.defaultValue
            }
        }

        let resolvedValue = owner._inheritedEnvironmentOverrideValue(for: identifier)
        if let resolvedValue {
            cache[identifier] = .value(resolvedValue)
            return (resolvedValue as? Key.Value) ?? Key.defaultValue
        } else {
            cache[identifier] = .missing
            return Key.defaultValue
        }
    }

    // MARK: - Internal

    weak var owner: _UIEnvironmentsContaining!

    init(_ owner: _UIEnvironmentsContaining) {
        self.owner = owner
    }

    var overrides: UIEnvironmentOverrides?
    var registrations: [UIEnvironmentChangeRegistration] = []

    private var localCacheGeneration: UInt64 = 0
    private var cache: [ObjectIdentifier: CachedOverride] = [:]

    func clearCache() {
        localCacheGeneration = 0
        cache.removeAll(keepingCapacity: true)
    }

    func notifyRegistrationsNeedUpdate(_ overrides: UIEnvironmentOverrides) {
        registrations
            .filter { registration in
                registration.identifiers.contains(where: { id in
                    overrides.storage.keys.contains(where: { $0 == id })
                })
            }
            .forEach { $0.action() }
    }

    static func bumpCacheGeneration() {
        cacheGeneration &+= 1
        if cacheGeneration == 0 {
            cacheGeneration = 1
        }
    }
}
