import UIKit

/// Describes a single environment value that can be read from `UIEnvironments`.
///
/// Create a type that conforms to this protocol to define a new environment
/// key that can be overridden and observed throughout a responder hierarchy.
///
/// Example:
/// ```swift
/// struct Theme {
///     var backgroundColor: UIColor
///
///     private init(backgroundColor: UIColor) {
///         self.backgroundColor = backgroundColor
///     }
/// }
///
/// struct ThemeEnvironment: UIEnvironmentDefinition {
///     static let defaultValue = Theme(backgroundColor: .systemBlue)
/// }
///
/// extension UIEnvironments {
///     var theme: Theme {
///         self[ThemeEnvironment.self]
///     }
/// }
///
/// extension UIMutableEnvironments {
///     var theme: Theme {
///         get { self[ThemeEnvironment.self] }
///         set { self[ThemeEnvironment.self] = newValue }
///     }
/// }
/// ```
///
public protocol UIEnvironmentDefinition: Sendable {
    /// The type of value stored for this environment definition.
    associatedtype Value: Sendable

    /// The value that is used when no explicit override has been provided.
    static var defaultValue: Value { get }
}

extension UIEnvironmentDefinition {
    /// The definition's default value type-erased to `Sendable`.
    ///
    /// This lets code holding an `any UIEnvironmentDefinition.Type` recover the
    /// default without knowing the concrete `Value`, which is needed when
    /// comparing effective values across snapshots.
    ///
    static var _defaultValueAsSendable: Sendable {
        defaultValue
    }
}

@available(iOS 17.0, *)
extension UIEnvironmentDefinition where Self: UITraitDefinition {
    /// Reads this definition's value from a trait collection as `Sendable`.
    static func _traitBridgeRead(from traitCollection: UITraitCollection) -> Sendable {
        traitCollection[Self.self]
    }

    /// Reads this definition's value from trait overrides as `Sendable`.
    static func _traitBridgeRead(from traitOverrides: UITraitOverrides) -> Sendable {
        traitOverrides[Self.self]
    }

    /// Returns `true` when an explicit value is set in trait overrides.
    static func _traitBridgeContains(in traitOverrides: UITraitOverrides) -> Bool {
        traitOverrides.contains(Self.self)
    }

    /// Writes a type-erased value into mutable trait overrides.
    ///
    /// Returns `true` when the cast to the definition's `Value` succeeds.
    static func _traitBridgeWrite(_ value: Sendable, to traitOverrides: inout UITraitOverrides) -> Bool {
        guard let value = value as? Value else {
            return false
        }

        traitOverrides[Self.self] = value
        return true
    }

    /// Removes this trait from mutable trait overrides.
    static func _traitBridgeRemove(from traitOverrides: inout UITraitOverrides) {
        traitOverrides.remove(Self.self)
    }
}
