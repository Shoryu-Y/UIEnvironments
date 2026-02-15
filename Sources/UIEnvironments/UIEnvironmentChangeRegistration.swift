import UIKit

public struct UIEnvironmentChangeRegistration: Sendable {
    var identifiers: Set<ObjectIdentifier>
    var action: @Sendable @MainActor () -> Void

    init(
        definitions: [any UIEnvironmentDefinition.Type],
        action: @Sendable @escaping @MainActor () -> Void
    ) {
        identifiers = Set(definitions.map { ObjectIdentifier($0) })
        self.action = action
    }

    init(
        identifiers: Set<ObjectIdentifier>,
        action: @Sendable @escaping @MainActor () -> Void
    ) {
        self.identifiers = identifiers
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
