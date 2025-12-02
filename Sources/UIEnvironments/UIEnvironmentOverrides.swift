import UIKit

public struct UIEnvironmentOverrides: Sendable, UIMutableEnvironments {
    public subscript<Key: UIEnvironmentDefinition>(type: Key.Type) -> Key.Value {
        get { (storage[ObjectIdentifier(type)] as? Key.Value) ?? Key.defaultValue }
        set { storage[ObjectIdentifier(type)] = newValue }
    }

    var storage: [ObjectIdentifier: Sendable] = [:]
}
