import ObjectiveC
import UIKit

/// Associated-object key used to attach `UIEnvironments` to UIKit responders.
private nonisolated(unsafe) let _environmentsKey = malloc(1)!

extension _UIEnvironmentsContaining {
    /// Returns the attached environments container without creating one.
    ///
    /// Hierarchy observation uses this so that plain views that never touched
    /// the environment system don't get containers allocated for them.
    ///
    var _environmentsIfExists: UIEnvironments? {
        objc_getAssociatedObject(self, _environmentsKey) as? UIEnvironments
    }
}

@MainActor
private func notifyUniqueRegistrations(
    _ containings: [any _UIEnvironmentsContaining],
    overrides: UIEnvironmentOverrides
) {
    var visited: Set<ObjectIdentifier> = []

    for containing in containings {
        let identifier = ObjectIdentifier(containing)
        guard visited.insert(identifier).inserted else { continue }
        containing._environments.notifyRegistrationsNeedUpdate(overrides)
    }
}

private extension UIResponder {
    /// Collects leaf views reachable from the receiver without forcing view loading.
    ///
    /// - For `UIView`, this returns terminal descendants.
    /// - For `UIViewController`, it traverses `viewIfLoaded`.
    /// - For `UIWindow`, it traverses `rootViewController` if present.
    ///
    func leafViews() -> [UIView] {
        if let window = self as? UIWindow, let rootViewController = window.rootViewController {
            let rootLeaves = rootViewController.leafViews()
            if !rootLeaves.isEmpty {
                return rootLeaves
            }
        }

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

    /// Builds a responder set from each leaf back toward `self` via `next`.
    ///
    /// The receiver itself is excluded.
    ///
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

private extension UIViewController {
    /// Collects this controller and all descendants in the containment tree.
    func selfAndDescendantViewControllers() -> [UIViewController] {
        [self] + children.flatMap { $0.selfAndDescendantViewControllers() }
    }
}

extension UIView: _UIEnvironmentsContaining {
    /// Lazily creates and stores environments for this view.
    var _environments: UIEnvironments {
        if let environments = objc_getAssociatedObject(self, _environmentsKey) as? UIEnvironments {
            return environments
        }

        let environments = UIEnvironments(self)
        objc_setAssociatedObject(self, _environmentsKey, environments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return environments
    }

    /// Notifies interested descendants that relevant environment overrides changed.
    func _propagate(_ overrides: UIEnvironmentOverrides) {
        var containings = descendants()
            .compactMap { $0 as? any _UIEnvironmentsContaining }

        if let window = self as? UIWindow, let rootViewController = window.rootViewController {
            containings.append(contentsOf: rootViewController.selfAndDescendantViewControllers())
        }

        notifyUniqueRegistrations(containings, overrides: overrides)

        _environments.notifyRegistrationsNeedUpdate(overrides)
    }
}

extension UIViewController: _UIEnvironmentsContaining {
    /// Lazily creates and stores environments for this view controller.
    var _environments: UIEnvironments {
        if let environments = objc_getAssociatedObject(self, _environmentsKey) as? UIEnvironments {
            return environments
        }

        let environments = UIEnvironments(self)
        objc_setAssociatedObject(self, _environmentsKey, environments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return environments
    }

    /// Notifies interested descendants that relevant environment overrides changed.
    func _propagate(_ overrides: UIEnvironmentOverrides) {
        let descendantsContaining = descendants()
            .compactMap { $0 as? any _UIEnvironmentsContaining }
        let childViewControllers = children
            .flatMap { $0.selfAndDescendantViewControllers() }
            .compactMap { $0 as any _UIEnvironmentsContaining }

        notifyUniqueRegistrations(descendantsContaining + childViewControllers, overrides: overrides)

        _environments.notifyRegistrationsNeedUpdate(overrides)
    }
}

extension UIWindowScene: _UIEnvironmentsContaining {
    /// Lazily creates and stores environments for this window scene.
    var _environments: UIEnvironments {
        if let environments = objc_getAssociatedObject(self, _environmentsKey) as? UIEnvironments {
            return environments
        }

        let environments = UIEnvironments(self)
        objc_setAssociatedObject(self, _environmentsKey, environments, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return environments
    }

    /// Notifies windows and descendants when scene-level overrides change.
    func _propagate(_ overrides: UIEnvironmentOverrides) {
        let descendantsContaining = windows
            .reduce([]) { result, window in result + window.descendants() }
            .compactMap { $0 as? any _UIEnvironmentsContaining }
        let rootViewControllers = windows
            .compactMap(\.rootViewController)
            .flatMap { $0.selfAndDescendantViewControllers() }
            .compactMap { $0 as any _UIEnvironmentsContaining }
        let windowsContaining = windows.map { $0 as any _UIEnvironmentsContaining }
        let containings = windowsContaining + descendantsContaining + rootViewControllers

        notifyUniqueRegistrations(containings, overrides: overrides)

        _environments.notifyRegistrationsNeedUpdate(overrides)
    }

    /// Scene overrides are treated as terminal for scene-origin resolution.
    var _inheritedEnvironmentOverrides: [ObjectIdentifier: Sendable] {
        environmentOverrides.storage
    }
}
