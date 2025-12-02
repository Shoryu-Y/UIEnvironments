import UIEnvironment
import UIKit

struct Theme {
    var backgroundColor: UIColor

    private init(backgroundColor: UIColor) {
        self.backgroundColor = backgroundColor
    }

    static var blue: Theme { .init(backgroundColor: .systemBlue) }
    static var mint: Theme { .init(backgroundColor: .systemMint) }
    static var orange: Theme { .init(backgroundColor: .systemOrange) }
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
