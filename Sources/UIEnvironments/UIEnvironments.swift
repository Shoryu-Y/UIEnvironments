import UIKit

@MainActor
public class UIEnvironments {
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

    weak var owner: _UIEnvironmentsContaining!

    init(_ owner: _UIEnvironmentsContaining) {
        self.owner = owner
    }

    var overrides: UIEnvironmentOverrides?
    var registrations: [UIEnvironmentChangeRegistration] = []

    private var cache: [ObjectIdentifier: Sendable]?

    func onChanged(_ overrides: UIEnvironmentOverrides) {
        let registrationsNeedUpdate = registrations.filter({ registration in
            registration.identifiers.contains(where: { id in
                overrides.storage.keys.contains(where: { $0 == id })
            })
        })

        if registrationsNeedUpdate.isEmpty {
            return
        }

        cache = nil
        for registration in registrationsNeedUpdate {
            registration.action()
        }
    }
}
