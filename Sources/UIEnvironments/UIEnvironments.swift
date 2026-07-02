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
    /// Unlike override writes, hierarchy moves do not bump the global
    /// generation. Reads instead validate the owner's current window identity
    /// so that a value resolved while detached (or in another window) is never
    /// served after the owner moves. This mirrors how `UITraitCollection`
    /// re-resolves traits when a view joins a hierarchy.
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

        let currentAttachment = owner?._attachmentIdentifier ?? nil
        if currentAttachment != lastKnownAttachment {
            lastKnownAttachment = currentAttachment
            cache.removeAll(keepingCapacity: true)
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
        lastKnownAttachment = owner._attachmentIdentifier

        _ = Self.installHierarchyObservation
    }

    /// Overrides defined directly on the owner.
    var overrides: UIEnvironmentOverrides?
    /// Registered callbacks for environment updates.
    var registrations: [UIEnvironmentChangeRegistration] = []
    /// Last observed value snapshot per registration.
    ///
    /// Every trigger re-resolves the observed definitions and compares them
    /// against this baseline, so a registration fires only when a value it
    /// observes actually changes. Storing effective values (a specified value
    /// or the definition's default) means an unspecified key is represented by
    /// its default rather than a missing entry.
    ///
    private var registrationBaselines: [UUID: UIEnvironmentValues] = [:]
    /// Native trait registration unregistration callbacks.
    private var nativeTraitUnregisterActions: [UUID: @MainActor () -> Void] = [:]

    /// Last seen global generation for the local cache.
    private var localCacheGeneration: UInt64 = 0
    /// Per-key cache for resolved values in the current generation.
    private var cache: [ObjectIdentifier: CachedOverride] = [:]
    /// Identity of the window the owner belonged to when the cache was
    /// last (re)built, or `nil` while detached from any window.
    private var lastKnownAttachment: ObjectIdentifier?

    /// Clears the local per-key cache immediately.
    ///
    /// This is mainly used by propagation paths that want eager invalidation.
    ///
    func clearCache() {
        localCacheGeneration = 0
        cache.removeAll(keepingCapacity: true)
    }

    /// A read-only snapshot of the values resolved for the owner.
    ///
    /// This is the environment analog of reading `traitCollection`: it walks the
    /// responder chain and merges every specified override, with the nearest
    /// responder winning. It reflects the same fallback resolution used by the
    /// subscript, so it does not consult natively bridged trait values.
    ///
    public func resolvedValues() -> UIEnvironmentValues {
        UIEnvironmentValues(entries: owner?._inheritedEnvironmentEntries ?? [:])
    }

    /// Adds a registration and records its current observed values as a baseline.
    func addRegistration(_ registration: UIEnvironmentChangeRegistration) {
        registrations.append(registration)
        registrationBaselines[registration.id] = resolvedSnapshot(for: registration.definitions)
    }

    /// Removes a registration and discards its baseline.
    func removeRegistration(_ registration: UIEnvironmentChangeRegistration) {
        registrations.removeAll { $0 == registration }
        registrationBaselines.removeValue(forKey: registration.id)
    }

    /// Handles the owner joining or leaving a window.
    ///
    /// Mirrors `UITraitCollection`: values are re-resolved against the new
    /// position and change registrations are re-evaluated, firing only when an
    /// observed value actually changed.
    ///
    func handleWindowAttachmentChange() {
        let currentAttachment = owner?._attachmentIdentifier ?? nil

        guard currentAttachment != lastKnownAttachment else { return }

        lastKnownAttachment = currentAttachment
        cache.removeAll(keepingCapacity: true)

        reevaluateRegistrations(changedKeys: nil)
    }

    /// Handles the owner being reparented.
    ///
    /// Moving within the same window changes the responder chain without a
    /// window change, so the cache is cleared eagerly and registrations are
    /// re-evaluated. Because firing is driven by value differences and the
    /// baseline is updated as soon as a change is observed, this stays correct
    /// even when the window-change hook also runs for the same move: whichever
    /// hook runs first updates the baseline, so the other sees no difference.
    ///
    func handleSuperviewChange() {
        cache.removeAll(keepingCapacity: true)

        reevaluateRegistrations(changedKeys: nil)
    }

    /// Re-evaluates registrations against their baselines, firing on change.
    ///
    /// Each registration's observed definitions are re-resolved and compared to
    /// the value snapshot recorded when it last fired (or when it was
    /// registered). A registration fires only when an observed value changed,
    /// after which its baseline is updated and the previous snapshot is handed
    /// to the callback.
    ///
    /// When `changedKeys` is non-`nil` (the override-write path) only
    /// registrations observing one of those keys are considered, which avoids
    /// re-resolving registrations that a write cannot affect. Passing `nil`
    /// (the hierarchy-move paths) considers every registration.
    ///
    func reevaluateRegistrations(changedKeys: Set<ObjectIdentifier>?) {
        let candidates: [UIEnvironmentChangeRegistration]
        if let changedKeys {
            candidates = registrations.filter { !$0.identifiers.isDisjoint(with: changedKeys) }
        } else {
            // A hierarchy move that leaves the owner outside every window does
            // not deliver notifications and must leave the baseline untouched,
            // mirroring `UITraitCollection`: a view removed from its window
            // receives no trait-change callback, and the value it is compared
            // against on the next attach is the one last delivered while in a
            // window, not the detached default. This keeps a reparent
            // (remove-then-add) from firing twice — once for the transient
            // detached default and once for the new value. Override writes use
            // the `changedKeys` path above and still notify window-less
            // hierarchies.
            guard owner?._attachmentIdentifier != nil else { return }

            candidates = registrations
        }

        for registration in candidates {
            let previousValues = registrationBaselines[registration.id] ?? UIEnvironmentValues()
            let currentValues = resolvedSnapshot(for: registration.definitions)

            guard !currentValues.isEqual(to: previousValues) else { continue }

            registrationBaselines[registration.id] = currentValues
            registration.action(previousValues)
        }
    }

    /// Builds a snapshot of the effective resolved values for `definitions`.
    ///
    /// Each definition resolves to its nearest override in the responder chain,
    /// or its default when unspecified, so the snapshot always contains an entry
    /// per observed definition.
    ///
    private func resolvedSnapshot(for definitions: [any UIEnvironmentDefinition.Type]) -> UIEnvironmentValues {
        guard let owner else { return UIEnvironmentValues() }

        var entries: [ObjectIdentifier: UIEnvironmentOverrides.Entry] = [:]
        for definition in definitions {
            let identifier = ObjectIdentifier(definition)
            let value = owner._inheritedEnvironmentOverrideValue(for: identifier) ?? definition._defaultValueAsSendable
            entries[identifier] = UIEnvironmentOverrides.Entry(definition: definition, value: value)
        }

        return UIEnvironmentValues(entries: entries)
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
