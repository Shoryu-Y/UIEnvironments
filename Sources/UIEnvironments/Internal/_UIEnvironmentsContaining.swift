import UIKit

/// Internal abstraction for responders that participate in environment resolution.
@MainActor
protocol _UIEnvironmentsContaining: UIResponder {
    /// Backing environment container attached to the responder.
    var _environments: UIEnvironments { get }

    /// Propagates override changes to descendants and registrations.
    func _propagate(_ overrides: UIEnvironmentOverrides)
}

extension _UIEnvironmentsContaining {
    @available(iOS 17.0, *)
    func _nativeTraitCollection() -> UITraitCollection? {
        if let view = self as? UIView {
            return view.traitCollection
        }

        if let viewController = self as? UIViewController {
            return viewController.traitCollection
        }

        if let windowScene = self as? UIWindowScene {
            return windowScene.traitCollection
        }

        return nil
    }

    @available(iOS 17.0, *)
    func _nativeTraitOverrides() -> UITraitOverrides? {
        if let view = self as? UIView {
            return view.traitOverrides
        }

        if let viewController = self as? UIViewController {
            return viewController.traitOverrides
        }

        if let windowScene = self as? UIWindowScene {
            return windowScene.traitOverrides
        }

        return nil
    }

    /// Internal storage accessor for overrides set on this responder.
    ///
    /// Setting a non-nil value bumps the global cache generation, then
    /// propagates change notifications through the current hierarchy.
    ///
    var _environmentOverrides: UIEnvironmentOverrides? {
        get { _environments.overrides }
        set {
            guard let newValue else { return }

            let previousValue = _environments.overrides ?? UIEnvironmentOverrides()
            _environments.overrides = newValue

            if #available(iOS 17.0, *), UIEnvironments.isNativeTraitBridgeEnabled {
                _syncNativeTraitOverrides(from: previousValue, to: newValue)
            }

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
        if let value = _environmentOverrides?.value(for: identifier) {
            return value
        }

        for responder in sequence(first: next, next: { $0?.next }) {
            guard
                let containable = responder as? _UIEnvironmentsContaining,
                let value = containable._environmentOverrides?.value(for: identifier)
            else {
                continue
            }

            return value
        }

        return nil
    }

    @available(iOS 17.0, *)
    private func _syncNativeTraitOverrides(
        from oldOverrides: UIEnvironmentOverrides,
        to newOverrides: UIEnvironmentOverrides
    ) {
        let removedIdentifiers = oldOverrides.identifiers.subtracting(newOverrides.identifiers)

        _updateTraitOverrides { traitOverrides in
            for identifier in removedIdentifiers {
                guard
                    let entry = oldOverrides.entries[identifier],
                    let traitDefinition = entry.definition as? any(UIEnvironmentDefinition & UITraitDefinition).Type
                else {
                    continue
                }

                traitDefinition._traitBridgeRemove(from: &traitOverrides)
            }

            for entry in newOverrides.entries.values {
                guard let traitDefinition = entry.definition as? any(UIEnvironmentDefinition & UITraitDefinition).Type else {
                    continue
                }

                _ = traitDefinition._traitBridgeWrite(entry.value, to: &traitOverrides)
            }
        }
    }

    @available(iOS 17.0, *)
    private func _updateTraitOverrides(_ update: (inout UITraitOverrides) -> Void) {
        if let view = self as? UIView {
            var overrides = view.traitOverrides
            update(&overrides)
            view.traitOverrides = overrides
            return
        }

        if let viewController = self as? UIViewController {
            var overrides = viewController.traitOverrides
            update(&overrides)
            viewController.traitOverrides = overrides
            return
        }

        if let windowScene = self as? UIWindowScene {
            var overrides = windowScene.traitOverrides
            update(&overrides)
            windowScene.traitOverrides = overrides
        }
    }
}
