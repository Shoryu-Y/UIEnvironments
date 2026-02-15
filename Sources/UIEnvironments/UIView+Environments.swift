import UIKit

public extension UIView {
    var environments: UIEnvironments {
        _environments
    }

    var environmentOverrides: UIEnvironmentOverrides {
        get { _environmentOverrides ?? UIEnvironmentOverrides() }
        set { _environmentOverrides = newValue }
    }

    @discardableResult
    func registerForEnvironmentChanges(
        _ definitions: [any UIEnvironmentDefinition.Type],
        action: @escaping @Sendable @MainActor () -> Void
    ) -> UIEnvironmentChangeRegistration {
        if #available(iOS 17.0, *), UIEnvironments.isNativeTraitBridgeEnabled {
            var fallbackDefinitions = definitions
            var nativeTraits: [UITrait] = []
            var nativeDefinitionIdentifiers: Set<ObjectIdentifier> = []

            for definition in definitions {
                guard let traitDefinition = definition as? any UITraitDefinition.Type else { continue }
                nativeTraits.append(traitDefinition)
                nativeDefinitionIdentifiers.insert(ObjectIdentifier(definition))
            }

            if !nativeDefinitionIdentifiers.isEmpty {
                fallbackDefinitions.removeAll { definition in
                    nativeDefinitionIdentifiers.contains(ObjectIdentifier(definition))
                }
            }

            let registration = UIEnvironmentChangeRegistration(definitions: fallbackDefinitions, action: action)
            if !registration.identifiers.isEmpty {
                environments.registrations.append(registration)
            }

            if !nativeTraits.isEmpty {
                let nativeRegistration = registerForTraitChanges(nativeTraits) { (_: UIView, _: UITraitCollection) in
                    action()
                }

                environments.setNativeTraitUnregisterAction({ [weak self] in
                    guard let self else { return }
                    unregisterForTraitChanges(nativeRegistration)
                }, for: registration)
            }

            return registration
        }

        let registration = UIEnvironmentChangeRegistration(definitions: definitions, action: action)
        if !registration.identifiers.isEmpty {
            environments.registrations.append(registration)
        }

        return registration
    }

    func unregisterFromEnvironmentChanges(_ registration: UIEnvironmentChangeRegistration) {
        environments.registrations.removeAll(where: { $0 == registration })
        environments.unregisterNativeTraitObserver(for: registration)
    }
}

public extension UIViewController {
    var environments: UIEnvironments {
        _environments
    }

    var environmentOverrides: UIEnvironmentOverrides {
        get { _environmentOverrides ?? UIEnvironmentOverrides() }
        set { _environmentOverrides = newValue }
    }

    @discardableResult
    func registerForEnvironmentChanges(
        _ definitions: [any UIEnvironmentDefinition.Type],
        action: @escaping @Sendable @MainActor () -> Void
    ) -> UIEnvironmentChangeRegistration {
        if #available(iOS 17.0, *), UIEnvironments.isNativeTraitBridgeEnabled {
            var fallbackDefinitions = definitions
            var nativeTraits: [UITrait] = []
            var nativeDefinitionIdentifiers: Set<ObjectIdentifier> = []

            for definition in definitions {
                guard let traitDefinition = definition as? any UITraitDefinition.Type else { continue }
                nativeTraits.append(traitDefinition)
                nativeDefinitionIdentifiers.insert(ObjectIdentifier(definition))
            }

            if !nativeDefinitionIdentifiers.isEmpty {
                fallbackDefinitions.removeAll { definition in
                    nativeDefinitionIdentifiers.contains(ObjectIdentifier(definition))
                }
            }

            let registration = UIEnvironmentChangeRegistration(definitions: fallbackDefinitions, action: action)
            if !registration.identifiers.isEmpty {
                environments.registrations.append(registration)
            }

            if !nativeTraits.isEmpty {
                let nativeRegistration = registerForTraitChanges(nativeTraits) { (_: UIViewController, _: UITraitCollection) in
                    action()
                }

                environments.setNativeTraitUnregisterAction({ [weak self] in
                    guard let self else { return }
                    unregisterForTraitChanges(nativeRegistration)
                }, for: registration)
            }

            return registration
        }

        let registration = UIEnvironmentChangeRegistration(definitions: definitions, action: action)
        if !registration.identifiers.isEmpty {
            environments.registrations.append(registration)
        }

        return registration
    }

    func unregisterFromEnvironmentChanges(_ registration: UIEnvironmentChangeRegistration) {
        environments.registrations.removeAll(where: { $0 == registration })
        environments.unregisterNativeTraitObserver(for: registration)
    }
}

public extension UIWindowScene {
    var environments: UIEnvironments {
        _environments
    }

    var environmentOverrides: UIEnvironmentOverrides {
        get { _environmentOverrides ?? UIEnvironmentOverrides() }
        set { _environmentOverrides = newValue }
    }

    @discardableResult
    func registerForEnvironmentChanges(
        _ definitions: [any UIEnvironmentDefinition.Type],
        action: @escaping @Sendable @MainActor () -> Void
    ) -> UIEnvironmentChangeRegistration {
        if #available(iOS 17.0, *), UIEnvironments.isNativeTraitBridgeEnabled {
            var fallbackDefinitions = definitions
            var nativeTraits: [UITrait] = []
            var nativeDefinitionIdentifiers: Set<ObjectIdentifier> = []

            for definition in definitions {
                guard let traitDefinition = definition as? any UITraitDefinition.Type else { continue }
                nativeTraits.append(traitDefinition)
                nativeDefinitionIdentifiers.insert(ObjectIdentifier(definition))
            }

            if !nativeDefinitionIdentifiers.isEmpty {
                fallbackDefinitions.removeAll { definition in
                    nativeDefinitionIdentifiers.contains(ObjectIdentifier(definition))
                }
            }

            let registration = UIEnvironmentChangeRegistration(definitions: fallbackDefinitions, action: action)
            if !registration.identifiers.isEmpty {
                environments.registrations.append(registration)
            }

            if !nativeTraits.isEmpty {
                let nativeRegistration = registerForTraitChanges(nativeTraits) { (_: UIWindowScene, _: UITraitCollection) in
                    action()
                }

                environments.setNativeTraitUnregisterAction({ [weak self] in
                    guard let self else { return }
                    unregisterForTraitChanges(nativeRegistration)
                }, for: registration)
            }

            return registration
        }

        let registration = UIEnvironmentChangeRegistration(definitions: definitions, action: action)
        if !registration.identifiers.isEmpty {
            environments.registrations.append(registration)
        }

        return registration
    }

    func unregisterFromEnvironmentChanges(_ registration: UIEnvironmentChangeRegistration) {
        environments.registrations.removeAll(where: { $0 == registration })
        environments.unregisterNativeTraitObserver(for: registration)
    }
}
