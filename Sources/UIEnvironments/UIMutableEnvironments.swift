import UIKit

public protocol UIMutableEnvironments {
    subscript<Key: UIEnvironmentDefinition>(type: Key.Type) -> Key.Value { get set }
}
