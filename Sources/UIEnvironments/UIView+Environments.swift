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
        registerForEnvironmentChanges(definitions) { (_: UIView, _: UIEnvironmentValues) in
            action()
        }
    }

    @discardableResult
    func registerForEnvironmentChanges(
        _ definitions: [any UIEnvironmentDefinition.Type],
        action: @escaping @Sendable @MainActor (_ environment: UIView, _ previousValues: UIEnvironmentValues) -> Void
    ) -> UIEnvironmentChangeRegistration {
        let boxedAction: @Sendable @MainActor (UIEnvironmentValues) -> Void = { [weak self] previousValues in
            guard let self else { return }
            action(self, previousValues)
        }

        if #available(iOS 17.0, *), UIEnvironments.isNativeTraitBridgeEnabled {
            var fallbackDefinitions = definitions
            var nativeTraits: [UITrait] = []
            var bridgedDefinitions: [any (UIEnvironmentDefinition & UITraitDefinition).Type] = []
            var nativeDefinitionIdentifiers: Set<ObjectIdentifier> = []

            for definition in definitions {
                guard let traitDefinition = definition as? any (UIEnvironmentDefinition & UITraitDefinition).Type else { continue }
                nativeTraits.append(traitDefinition)
                bridgedDefinitions.append(traitDefinition)
                nativeDefinitionIdentifiers.insert(ObjectIdentifier(definition))
            }

            if !nativeDefinitionIdentifiers.isEmpty {
                fallbackDefinitions.removeAll { definition in
                    nativeDefinitionIdentifiers.contains(ObjectIdentifier(definition))
                }
            }

            let registration = UIEnvironmentChangeRegistration(definitions: fallbackDefinitions, action: boxedAction)
            if !registration.identifiers.isEmpty {
                environments.addRegistration(registration)
            }

            if !nativeTraits.isEmpty {
                let nativeRegistration = registerForTraitChanges(nativeTraits) { (environment: UIView, previousTraitCollection: UITraitCollection) in
                    action(environment, UIEnvironmentValues(bridging: previousTraitCollection, definitions: bridgedDefinitions))
                }

                environments.setNativeTraitUnregisterAction({ [weak self] in
                    guard let self else { return }
                    unregisterForTraitChanges(nativeRegistration)
                }, for: registration)
            }

            return registration
        }

        let registration = UIEnvironmentChangeRegistration(definitions: definitions, action: boxedAction)
        if !registration.identifiers.isEmpty {
            environments.addRegistration(registration)
        }

        return registration
    }

    func unregisterFromEnvironmentChanges(_ registration: UIEnvironmentChangeRegistration) {
        environments.removeRegistration(registration)
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
        registerForEnvironmentChanges(definitions) { (_: UIViewController, _: UIEnvironmentValues) in
            action()
        }
    }

    @discardableResult
    func registerForEnvironmentChanges(
        _ definitions: [any UIEnvironmentDefinition.Type],
        action: @escaping @Sendable @MainActor (_ environment: UIViewController, _ previousValues: UIEnvironmentValues) -> Void
    ) -> UIEnvironmentChangeRegistration {
        let boxedAction: @Sendable @MainActor (UIEnvironmentValues) -> Void = { [weak self] previousValues in
            guard let self else { return }
            action(self, previousValues)
        }

        if #available(iOS 17.0, *), UIEnvironments.isNativeTraitBridgeEnabled {
            var fallbackDefinitions = definitions
            var nativeTraits: [UITrait] = []
            var bridgedDefinitions: [any (UIEnvironmentDefinition & UITraitDefinition).Type] = []
            var nativeDefinitionIdentifiers: Set<ObjectIdentifier> = []

            for definition in definitions {
                guard let traitDefinition = definition as? any (UIEnvironmentDefinition & UITraitDefinition).Type else { continue }
                nativeTraits.append(traitDefinition)
                bridgedDefinitions.append(traitDefinition)
                nativeDefinitionIdentifiers.insert(ObjectIdentifier(definition))
            }

            if !nativeDefinitionIdentifiers.isEmpty {
                fallbackDefinitions.removeAll { definition in
                    nativeDefinitionIdentifiers.contains(ObjectIdentifier(definition))
                }
            }

            let registration = UIEnvironmentChangeRegistration(definitions: fallbackDefinitions, action: boxedAction)
            if !registration.identifiers.isEmpty {
                environments.addRegistration(registration)
            }

            if !nativeTraits.isEmpty {
                let nativeRegistration = registerForTraitChanges(nativeTraits) { (environment: UIViewController, previousTraitCollection: UITraitCollection) in
                    action(environment, UIEnvironmentValues(bridging: previousTraitCollection, definitions: bridgedDefinitions))
                }

                environments.setNativeTraitUnregisterAction({ [weak self] in
                    guard let self else { return }
                    unregisterForTraitChanges(nativeRegistration)
                }, for: registration)
            }

            return registration
        }

        let registration = UIEnvironmentChangeRegistration(definitions: definitions, action: boxedAction)
        if !registration.identifiers.isEmpty {
            environments.addRegistration(registration)
        }

        return registration
    }

    func unregisterFromEnvironmentChanges(_ registration: UIEnvironmentChangeRegistration) {
        environments.removeRegistration(registration)
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
        registerForEnvironmentChanges(definitions) { (_: UIWindowScene, _: UIEnvironmentValues) in
            action()
        }
    }

    @discardableResult
    func registerForEnvironmentChanges(
        _ definitions: [any UIEnvironmentDefinition.Type],
        action: @escaping @Sendable @MainActor (_ environment: UIWindowScene, _ previousValues: UIEnvironmentValues) -> Void
    ) -> UIEnvironmentChangeRegistration {
        let boxedAction: @Sendable @MainActor (UIEnvironmentValues) -> Void = { [weak self] previousValues in
            guard let self else { return }
            action(self, previousValues)
        }

        if #available(iOS 17.0, *), UIEnvironments.isNativeTraitBridgeEnabled {
            var fallbackDefinitions = definitions
            var nativeTraits: [UITrait] = []
            var bridgedDefinitions: [any (UIEnvironmentDefinition & UITraitDefinition).Type] = []
            var nativeDefinitionIdentifiers: Set<ObjectIdentifier> = []

            for definition in definitions {
                guard let traitDefinition = definition as? any (UIEnvironmentDefinition & UITraitDefinition).Type else { continue }
                nativeTraits.append(traitDefinition)
                bridgedDefinitions.append(traitDefinition)
                nativeDefinitionIdentifiers.insert(ObjectIdentifier(definition))
            }

            if !nativeDefinitionIdentifiers.isEmpty {
                fallbackDefinitions.removeAll { definition in
                    nativeDefinitionIdentifiers.contains(ObjectIdentifier(definition))
                }
            }

            let registration = UIEnvironmentChangeRegistration(definitions: fallbackDefinitions, action: boxedAction)
            if !registration.identifiers.isEmpty {
                environments.addRegistration(registration)
            }

            if !nativeTraits.isEmpty {
                let nativeRegistration = registerForTraitChanges(nativeTraits) { (environment: UIWindowScene, previousTraitCollection: UITraitCollection) in
                    action(environment, UIEnvironmentValues(bridging: previousTraitCollection, definitions: bridgedDefinitions))
                }

                environments.setNativeTraitUnregisterAction({ [weak self] in
                    guard let self else { return }
                    unregisterForTraitChanges(nativeRegistration)
                }, for: registration)
            }

            return registration
        }

        let registration = UIEnvironmentChangeRegistration(definitions: definitions, action: boxedAction)
        if !registration.identifiers.isEmpty {
            environments.addRegistration(registration)
        }

        return registration
    }

    func unregisterFromEnvironmentChanges(_ registration: UIEnvironmentChangeRegistration) {
        environments.removeRegistration(registration)
        environments.unregisterNativeTraitObserver(for: registration)
    }
}
