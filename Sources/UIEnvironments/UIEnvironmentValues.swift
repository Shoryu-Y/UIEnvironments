import UIKit

/// An immutable snapshot of environment values resolved for a responder.
///
/// `UIEnvironmentValues` is the environment analog of `UITraitCollection`: it
/// captures the effective value of one or more environment definitions at a
/// single point in time. Unlike ``UIEnvironmentOverrides``, it is read-only and
/// is handed to change callbacks so they can compare against the previous
/// resolution.
///
/// Environment values are not required to be `Equatable`, so this type does not
/// conform to `Equatable`. Use ``isEqual(to:)`` for a runtime-checked value
/// comparison that mirrors how `UITraitCollection` compares boxed trait values.
///
public struct UIEnvironmentValues: Sendable {
    /// Specified entries keyed by their definition's identity.
    ///
    /// An entry retains its definition type so a default value can be computed
    /// for keys that another snapshot specifies but this one does not.
    ///
    var entries: [ObjectIdentifier: UIEnvironmentOverrides.Entry]

    init(entries: [ObjectIdentifier: UIEnvironmentOverrides.Entry] = [:]) {
        self.entries = entries
    }

    /// Creates a snapshot by merging several snapshots together.
    ///
    /// This mirrors `UITraitCollection.traitCollectionWithTraitsFromCollections:`:
    /// when more than one collection specifies the same definition, the value
    /// from the later collection in `collections` wins.
    ///
    public init(merging collections: [UIEnvironmentValues]) {
        var merged: [ObjectIdentifier: UIEnvironmentOverrides.Entry] = [:]
        for collection in collections {
            merged.merge(collection.entries) { _, new in new }
        }
        self.init(entries: merged)
    }

    /// Returns the resolved value for the given environment definition.
    ///
    /// When the definition is specified in the snapshot its stored value is
    /// returned; otherwise the definition's `defaultValue` is used.
    ///
    public subscript<Key: UIEnvironmentDefinition>(type: Key.Type) -> Key.Value {
        (entries[ObjectIdentifier(type)]?.value as? Key.Value) ?? Key.defaultValue
    }

    /// The definitions explicitly specified in this snapshot.
    ///
    /// This is the environment analog of `UITraitCollection`'s set of specified
    /// traits.
    ///
    public var specifiedDefinitions: [any UIEnvironmentDefinition.Type] {
        entries.values.map(\.definition)
    }

    /// Returns whether another snapshot's specified values are all present here.
    ///
    /// This mirrors `UITraitCollection.containsTraitsInCollection:`: every
    /// definition specified by `other` must be specified here with an equal
    /// value, compared using runtime equality.
    ///
    public func contains(_ other: UIEnvironmentValues) -> Bool {
        for (identifier, otherEntry) in other.entries {
            guard
                let entry = entries[identifier],
                _isEnvironmentValueEqual(entry.value, otherEntry.value)
            else {
                return false
            }
        }

        return true
    }

    /// Returns whether this snapshot specifies exactly the same values as another.
    ///
    /// This mirrors `UITraitCollection.isEqual:`. Two snapshots are equal when
    /// they specify the same set of definitions and every value is equal under
    /// runtime equality. Values whose type is not `Equatable` are treated as
    /// unequal, matching how `UITraitCollection` falls back to identity for
    /// class-based trait values.
    ///
    public func isEqual(to other: UIEnvironmentValues) -> Bool {
        guard Set(entries.keys) == Set(other.entries.keys) else { return false }

        for (identifier, entry) in entries {
            guard
                let otherEntry = other.entries[identifier],
                _isEnvironmentValueEqual(entry.value, otherEntry.value)
            else {
                return false
            }
        }

        return true
    }

    /// Returns the definitions whose effective value differs from another snapshot.
    ///
    /// This mirrors `UITraitCollection.changedTraitsFromTraitCollection:`. The
    /// comparison uses each definition's effective value — its specified value,
    /// or its `defaultValue` when unspecified — so a definition dropped from one
    /// snapshot counts as changed only when its default differs from the value
    /// held by the other snapshot. Values whose type is not `Equatable` are
    /// always reported as changed.
    ///
    public func changedDefinitions(from other: UIEnvironmentValues) -> [any UIEnvironmentDefinition.Type] {
        var identifiers = Set(entries.keys)
        identifiers.formUnion(other.entries.keys)

        var changed: [any UIEnvironmentDefinition.Type] = []
        for identifier in identifiers {
            guard let definition = entries[identifier]?.definition ?? other.entries[identifier]?.definition else {
                continue
            }

            let value = entries[identifier]?.value ?? definition._defaultValueAsSendable
            let otherValue = other.entries[identifier]?.value ?? definition._defaultValueAsSendable

            if !_isEnvironmentValueEqual(value, otherValue) {
                changed.append(definition)
            }
        }

        return changed
    }
}

@available(iOS 17.0, *)
extension UIEnvironmentValues {
    /// Builds a snapshot of bridged definitions read from a trait collection.
    ///
    /// Used to translate the `previousTraitCollection` reported by native trait
    /// change observation into the environment's snapshot type, limited to the
    /// bridged definitions the caller observes.
    ///
    init(
        bridging traitCollection: UITraitCollection,
        definitions: [any (UIEnvironmentDefinition & UITraitDefinition).Type]
    ) {
        var entries: [ObjectIdentifier: UIEnvironmentOverrides.Entry] = [:]
        for definition in definitions {
            entries[ObjectIdentifier(definition)] = UIEnvironmentOverrides.Entry(
                definition: definition,
                value: definition._traitBridgeRead(from: traitCollection)
            )
        }

        self.init(entries: entries)
    }
}

/// Compares two boxed environment values the way `UITraitCollection` compares
/// boxed custom trait values with `isEqual:`.
///
/// When both values share a dynamic type that conforms to `Equatable`, they are
/// compared by value. Otherwise they are treated as unequal, mirroring the
/// pointer-identity fallback `UITraitCollection` uses for class-based values.
///
/// Because the environment system tests value equality frequently, prefer
/// simple `Equatable` value types for environment definitions and avoid class
/// values, matching Apple's guidance for custom `UITraitDefinition` values.
///
func _isEnvironmentValueEqual(_ lhs: Sendable, _ rhs: Sendable) -> Bool {
    guard let lhs = lhs as? any Equatable else { return false }
    return _isEnvironmentValueEqual(lhs, rhs)
}

private func _isEnvironmentValueEqual<T: Equatable>(_ lhs: T, _ rhs: Sendable) -> Bool {
    guard let rhs = rhs as? T else { return false }
    return lhs == rhs
}
