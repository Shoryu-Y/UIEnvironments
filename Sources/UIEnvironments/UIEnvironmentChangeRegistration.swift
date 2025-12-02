import UIKit

public struct UIEnvironmentChangeRegistration: Sendable {
    var identifiers: [ObjectIdentifier]
    var action: @Sendable () -> Void

    init(
        definitions: [any UIEnvironmentDefinition.Type],
        action: @Sendable @escaping () -> Void,
    ) {
        identifiers = definitions.map { ObjectIdentifier($0) }
        self.action = action
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
