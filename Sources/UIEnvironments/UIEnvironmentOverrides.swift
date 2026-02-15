import UIKit

/// A mutable collection of environment overrides for a responder hierarchy.
///
/// You typically create an instance, set one or more environment values, and
/// assign it to `environmentOverrides` on a `UIView`, `UIViewController`,
/// or `UIWindowScene` to affect all of their descendants.
///
public struct UIEnvironmentOverrides: Sendable, UIMutableEnvironments {
    struct Entry: Sendable {
        var definition: any UIEnvironmentDefinition.Type
        var value: Sendable
    }

    /// Accesses the override for the given environment definition.
    ///
    /// When reading, this returns the explicitly stored value if present,
    /// or falls back to the definition's `defaultValue`. When writing, the
    /// value is stored and will be visible to any descendant that reads the environment.
    ///
    public subscript<Key: UIEnvironmentDefinition>(type: Key.Type) -> Key.Value {
        get { (entries[ObjectIdentifier(type)]?.value as? Key.Value) ?? Key.defaultValue }
        set {
            entries[ObjectIdentifier(type)] = Entry(
                definition: type,
                value: newValue
            )
        }
    }

    var entries: [ObjectIdentifier: Entry] = [:]

    var storage: [ObjectIdentifier: Sendable] {
        entries.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value.value
        }
    }

    var identifiers: Set<ObjectIdentifier> {
        Set(entries.keys)
    }

    func value(for identifier: ObjectIdentifier) -> Sendable? {
        entries[identifier]?.value
    }
}
