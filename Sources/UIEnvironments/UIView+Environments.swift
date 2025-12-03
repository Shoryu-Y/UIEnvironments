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
        let registration = UIEnvironmentChangeRegistration(definitions: definitions, action: action)
        environments.registrations.append(registration)
        return registration
    }

    func unregisterFromEnvironmentChanges(_ registration: UIEnvironmentChangeRegistration) {
        environments.registrations.removeAll(where: { $0 == registration })
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
        let registration = UIEnvironmentChangeRegistration(definitions: definitions, action: action)
        environments.registrations.append(registration)
        return registration
    }

    func unregisterFromEnvironmentChanges(_ registration: UIEnvironmentChangeRegistration) {
        environments.registrations.removeAll(where: { $0 == registration })
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
        let registration = UIEnvironmentChangeRegistration(definitions: definitions, action: action)
        environments.registrations.append(registration)
        return registration
    }

    func unregisterFromEnvironmentChanges(_ registration: UIEnvironmentChangeRegistration) {
        environments.registrations.removeAll(where: { $0 == registration })
    }
}
