import UIKit

public struct UIEnvironmentChangeRegistration: Sendable {
    /// Definitions this registration observes, retaining their type so a value
    /// snapshot can be resolved for them.
    var definitions: [any UIEnvironmentDefinition.Type]
    /// Identities of the observed definitions, used to intersect changed keys.
    var identifiers: Set<ObjectIdentifier>
    /// Callback invoked when an observed value changes.
    ///
    /// The previous resolved values (limited to the observed definitions) are
    /// passed so callers can compare against the current environment.
    ///
    var action: @Sendable @MainActor (_ previousValues: UIEnvironmentValues) -> Void

    init(
        definitions: [any UIEnvironmentDefinition.Type],
        action: @Sendable @escaping @MainActor (_ previousValues: UIEnvironmentValues) -> Void
    ) {
        self.definitions = definitions
        identifiers = Set(definitions.map { ObjectIdentifier($0) })
        self.action = action
    }

    var id: UUID {
        uuid
    }

    private var uuid = UUID()
}

extension UIEnvironmentChangeRegistration: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.uuid == rhs.uuid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}
