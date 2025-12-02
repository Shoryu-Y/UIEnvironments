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
