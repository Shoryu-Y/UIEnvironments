import UIKit

/// A type that can store and mutate environment values for one or more
/// `UIEnvironmentDefinition`s.
///
/// Conforming types provide read–write access to environment values that can
/// later be observed through `UIEnvironments`.
///
/// - SeeAlso: ``UIEnvironmentDefinition``
///
public protocol UIMutableEnvironments {
    /// Accesses the value associated with the given environment definition.
    ///
    /// Use this subscript to set or update environment values.
    ///
    subscript<Key: UIEnvironmentDefinition>(type: Key.Type) -> Key.Value { get set }
}
