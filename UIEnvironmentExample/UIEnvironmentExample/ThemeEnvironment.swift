import UIEnvironments
import UIKit

// Environment values should be `Equatable` so change notifications fire only on
// a genuine value change, matching Apple's guidance for custom trait values.
struct Theme: Equatable {
    var name: String
    var backgroundColor: UIColor

    private init(name: String, backgroundColor: UIColor) {
        self.name = name
        self.backgroundColor = backgroundColor
    }

    static var blue: Theme { .init(name: "blue", backgroundColor: .systemBlue) }
    static var mint: Theme { .init(name: "mint", backgroundColor: .systemMint) }
    static var orange: Theme { .init(name: "orange", backgroundColor: .systemOrange) }
}

struct ThemeEnvironment: UIEnvironmentDefinition {
    static let defaultValue = Theme.blue
}

extension UIEnvironments {
    var theme: Theme {
        self[ThemeEnvironment.self]
    }
}

extension UIMutableEnvironments {
    var theme: Theme {
        get { self[ThemeEnvironment.self] }
        set { self[ThemeEnvironment.self] = newValue }
    }
}
