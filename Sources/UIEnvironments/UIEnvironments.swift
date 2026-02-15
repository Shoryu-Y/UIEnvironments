import UIKit

/// A container that provides read-only access to environment values
/// resolved for a specific responder, such as a `UIView`,
/// `UIViewController`, `UIWindow`, or `UIWindowScene`.
///
@MainActor public class UIEnvironments {
    /// A cached entry for a resolved environment key.
    ///
    /// `.value` stores an override found in the responder chain,
    /// while `.missing` memoizes the absence of an override.
    ///
    private enum CachedOverride {
        case value(Sendable)
        case missing
    }

    /// Global generation used to invalidate all per-instance caches.
    ///
    /// Any override update bumps this counter so subsequent reads
    /// rebuild local caches lazily.
    ///
    private static var cacheGeneration: UInt64 = 1

    /// Disables native trait bridging even on iOS 17+.
    ///
    /// Set this to `true` to force the `UIEnvironments` fallback path.
    ///
    public static var disableNativeTraitBridge: Bool =
        ProcessInfo.processInfo.environment["UIENVIRONMENTS_DISABLE_NATIVE_TRAIT_BRIDGE"] == "1"

    static var isNativeTraitBridgeEnabled: Bool {
        if #available(iOS 17.0, *) {
            return !disableNativeTraitBridge
        }

        return false
    }

    /// Returns the current value associated with the given environment definition.
    ///
    /// Pass an environment definition type and read its value for the receiver,
    /// taking into account any `environmentOverrides` set in the surrounding
    /// view, view controller, or window scene hierarchy. If no value has been
    /// provided, the definition's `defaultValue` is used.
    ///
    /// Resolution is memoized per key and per generation to reduce repeated
    /// responder-chain traversal while still reflecting recent override changes.
    ///
    public subscript<Key: UIEnvironmentDefinition>(type: Key.Type) -> Key.Value {
        if #available(iOS 17.0, *),
           Self.isNativeTraitBridgeEnabled,
           let traitDefinition = type as? any(UIEnvironmentDefinition & UITraitDefinition).Type
        {
            if let traitOverrides = owner._nativeTraitOverrides(),
               traitDefinition._traitBridgeContains(in: traitOverrides)
            {
                let value = traitDefinition._traitBridgeRead(from: traitOverrides)
                return (value as? Key.Value) ?? Key.defaultValue
            }

            if let traitCollection = owner._nativeTraitCollection() {
                let value = traitDefinition._traitBridgeRead(from: traitCollection)
                return (value as? Key.Value) ?? Key.defaultValue
            }
        }

        let identifier = ObjectIdentifier(type)

        if localCacheGeneration != Self.cacheGeneration {
            cache.removeAll(keepingCapacity: true)
            localCacheGeneration = Self.cacheGeneration
        }

        if let cached = cache[identifier] {
            switch cached {
            case let .value(value):
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

    /// Owning responder-like object for this environment container.
    weak var owner: _UIEnvironmentsContaining!

    /// Creates a container bound to the specified owner.
    init(_ owner: _UIEnvironmentsContaining) {
        self.owner = owner
    }

    /// Overrides defined directly on the owner.
    var overrides: UIEnvironmentOverrides?
    /// Registered callbacks for environment updates.
    var registrations: [UIEnvironmentChangeRegistration] = []
    /// Native trait registration unregistration callbacks.
    private var nativeTraitUnregisterActions: [UUID: @MainActor () -> Void] = [:]

    /// Last seen global generation for the local cache.
    private var localCacheGeneration: UInt64 = 0
    /// Per-key cache for resolved values in the current generation.
    private var cache: [ObjectIdentifier: CachedOverride] = [:]

    /// Clears the local per-key cache immediately.
    ///
    /// This is mainly used by propagation paths that want eager invalidation.
    ///
    func clearCache() {
        localCacheGeneration = 0
        cache.removeAll(keepingCapacity: true)
    }

    /// Executes registrations that depend on keys included in `overrides`.
    func notifyRegistrationsNeedUpdate(_ overrides: UIEnvironmentOverrides) {
        let changedIdentifiers = overrides.identifiers

        registrations
            .filter { registration in
                !registration.identifiers.isDisjoint(with: changedIdentifiers)
            }
            .forEach { $0.action() }
    }

    /// Stores an unregistration callback for native trait observations.
    func setNativeTraitUnregisterAction(
        _ action: @escaping @MainActor () -> Void,
        for registration: UIEnvironmentChangeRegistration
    ) {
        nativeTraitUnregisterActions[registration.id] = action
    }

    /// Removes and executes any native trait unregistration callback.
    func unregisterNativeTraitObserver(for registration: UIEnvironmentChangeRegistration) {
        nativeTraitUnregisterActions.removeValue(forKey: registration.id)?()
    }

    /// Increments the global cache generation.
    ///
    /// Wraparound is handled by skipping `0` so new instances can still use
    /// `0` as an initial "not initialized" marker.
    ///
    static func bumpCacheGeneration() {
        cacheGeneration &+= 1
        if cacheGeneration == 0 {
            cacheGeneration = 1
        }
    }
}
