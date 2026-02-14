import UIKit

@MainActor
/// Internal abstraction for responders that participate in environment resolution.
protocol _UIEnvironmentsContaining: UIResponder {
    /// Backing environment container attached to the responder.
    var _environments: UIEnvironments { get }

    /// Propagates override changes to descendants and registrations.
    func _propagate(_ overrides: UIEnvironmentOverrides)
}

extension _UIEnvironmentsContaining {
    /// Internal storage accessor for overrides set on this responder.
    ///
    /// Setting a non-nil value bumps the global cache generation, then
    /// propagates change notifications through the current hierarchy.
    ///
    var _environmentOverrides: UIEnvironmentOverrides? {
        get { _environments.overrides }
        set {
            guard let newValue else { return }

            _environments.overrides = newValue
            UIEnvironments.bumpCacheGeneration()
            _propagate(newValue)
        }
    }

    /// Resolves all inherited overrides into a merged dictionary.
    ///
    /// This is retained for compatibility where callers need a full snapshot.
    /// The nearest responder override wins for duplicate keys.
    ///
    var _inheritedEnvironmentOverrides: [ObjectIdentifier: Sendable] {
        let overrides = _environmentOverrides?.storage ?? [:]

        return sequence(first: next, next: { $0?.next })
            .compactMap { next in
                let containable = next as? _UIEnvironmentsContaining
                return containable?._environmentOverrides
            }
            .reduce(overrides) { result, overrides in
                result.merging(
                    overrides.storage,
                    uniquingKeysWith: { current, _ in current }
                )
            }
    }

    /// Resolves the nearest override value for a specific environment key.
    ///
    /// Traversal starts at `self`, then walks the `next` responder chain until
    /// a matching override is found or the chain ends.
    ///
    func _inheritedEnvironmentOverrideValue(for identifier: ObjectIdentifier) -> Sendable? {
        if let value = _environmentOverrides?.storage[identifier] {
            return value
        }

        for responder in sequence(first: next, next: { $0?.next }) {
            guard
                let containable = responder as? _UIEnvironmentsContaining,
                let value = containable._environmentOverrides?.storage[identifier]
            else {
                continue
            }

            return value
        }

        return nil
    }
}
