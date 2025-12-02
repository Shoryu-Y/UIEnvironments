import ObjectiveC
import UIKit

nonisolated(unsafe) private let _environmentsKey = malloc(1)!

extension UIView: _UIEnvironmentsContaining {
    var _environments: UIEnvironments {
        if let environments = objc_getAssociatedObject(self, _environmentsKey) as? UIEnvironments {
            return environments
        }

        let environments = UIEnvironments(self)
        objc_setAssociatedObject(self, _environmentsKey, environments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return environments
    }

    func _propagate(_ overrides: UIEnvironmentOverrides) {
        _environments.onChanged(overrides)

        if let window = self as? UIWindow {
            window.rootViewController?._propagate(overrides)
        } else {
            for subview in subviews {
                subview._propagate(overrides)
            }
        }
    }
}

extension UIViewController: _UIEnvironmentsContaining {
    var _environments: UIEnvironments {
        if let environments = objc_getAssociatedObject(self, _environmentsKey) as? UIEnvironments {
            return environments
        }

        let environments = UIEnvironments(self)
        objc_setAssociatedObject(self, _environmentsKey, environments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return environments
    }

    func _propagate(_ overrides: UIEnvironmentOverrides) {
        _environments.onChanged(overrides)

        view._propagate(overrides)
        for child in children {
            child._propagate(overrides)
        }
    }
}

extension UIWindowScene: _UIEnvironmentsContaining {
    var _environments: UIEnvironments {
        if let environments = objc_getAssociatedObject(self, _environmentsKey) as? UIEnvironments {
            return environments
        }

        let environments = UIEnvironments(self)
        objc_setAssociatedObject(self, _environmentsKey, environments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return environments
    }

    func _propagate(_ overrides: UIEnvironmentOverrides) {
        _environments.onChanged(overrides)

        for window in windows {
            window._propagate(overrides)
        }
    }

    var _inheritedEnvironmentOverrides: [ObjectIdentifier: Sendable] {
        environmentOverrides.storage
    }
}
