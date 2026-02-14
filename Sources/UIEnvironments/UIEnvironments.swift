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
        let overriddenEnvironments = owner._inheritedEnvironmentOverrides
        return (overriddenEnvironments[ObjectIdentifier(type)] as? Key.Value) ?? Key.defaultValue
    }

    // MARK: - Internal

    weak var owner: _UIEnvironmentsContaining!

    init(_ owner: _UIEnvironmentsContaining) {
        self.owner = owner
    }

    var overrides: UIEnvironmentOverrides?
    var registrations: [UIEnvironmentChangeRegistration] = []

    func clearCache() {
        // Kept for compatibility with propagation flow.
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
}
