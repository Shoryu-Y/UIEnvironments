import ObjectiveC
import UIKit

private nonisolated(unsafe) let _environmentsKey = malloc(1)!

private extension UIResponder {
    func leafViews() -> [UIView] {
        var results: [UIView] = []

        if let view = self as? UIView {
            if view.subviews.isEmpty {
                return [view]
            }

            for subview in view.subviews {
                results.append(contentsOf: subview.leafViews())
            }
        }

        if let viewController = self as? UIViewController, let view = viewController.viewIfLoaded {
            results.append(contentsOf: view.leafViews())
        }

        if let window = self as? UIWindow, let rootViewController = window.rootViewController {
            results.append(contentsOf: rootViewController.leafViews())
        }

        return results
    }

    func descendants() -> Set<UIResponder> {
        var results: Set<UIResponder> = []

        for leaf in leafViews() {
            var current: UIResponder? = leaf
            while let responder = current, responder !== self {
                results.insert(responder)
                current = responder.next
            }
        }

        return results
    }
}

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
        let containings = descendants()
            .compactMap({ $0 as? _UIEnvironmentsContaining })

        containings.forEach { $0._environments.notifyRegistrationsNeedUpdate(overrides) }

        _environments.notifyRegistrationsNeedUpdate(overrides)
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
        let containings = descendants()
            .compactMap({ $0 as? _UIEnvironmentsContaining })

        containings.forEach { $0._environments.notifyRegistrationsNeedUpdate(overrides) }

        _environments.notifyRegistrationsNeedUpdate(overrides)
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
        let descendantsContaining = windows
            .reduce([], { result, window in result + window.descendants() })
            .compactMap { $0 as? _UIEnvironmentsContaining }
        let containings = windows + descendantsContaining

        containings.forEach { $0._environments.notifyRegistrationsNeedUpdate(overrides) }

        _environments.notifyRegistrationsNeedUpdate(overrides)
    }

    var _inheritedEnvironmentOverrides: [ObjectIdentifier: Sendable] {
        environmentOverrides.storage
    }
}
