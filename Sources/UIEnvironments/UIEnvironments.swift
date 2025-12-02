import UIKit

/// A container that provides read-only access to environment values
/// resolved for a specific responder, such as a `UIView`,
/// `UIViewController`, `UIWindow`, or `UIWindowScene`.
///
@MainActor public class UIEnvironments {
    /// Returns the current value associated with the given environment definition.
    ///
    /// Pass an environment definition type and read its value for the receiver,
    /// taking into account any `environmentOverrides` set in the surrounding
    /// view, view controller, or window scene hierarchy. If no value has been
    /// provided, the definition's `defaultValue` is used.
    ///
    public subscript<Key: UIEnvironmentDefinition>(type: Key.Type) -> Key.Value {
        let overriddenEnvironments: [ObjectIdentifier: Sendable]

        if let cache {
            overriddenEnvironments = cache
        } else {
            overriddenEnvironments = owner._inheritedEnvironmentOverrides
            cache = overriddenEnvironments
        }

        return (overriddenEnvironments[ObjectIdentifier(type)] as? Key.Value) ?? Key.defaultValue
    }

    // MARK: - Internal

    weak var owner: _UIEnvironmentsContaining!

    init(_ owner: _UIEnvironmentsContaining) {
        self.owner = owner
    }

    var overrides: UIEnvironmentOverrides?
    var registrations: [UIEnvironmentChangeRegistration] = []

    private var cache: [ObjectIdentifier: Sendable]?

    func onChanged(_ overrides: UIEnvironmentOverrides) {
        let registrationsNeedUpdate = registrations.filter { registration in
            registration.identifiers.contains(where: { id in
                overrides.storage.keys.contains(where: { $0 == id })
            })
        }

        if registrationsNeedUpdate.isEmpty {
            return
        }

        cache = nil
        for registration in registrationsNeedUpdate {
            registration.action()
        }
    }
}
