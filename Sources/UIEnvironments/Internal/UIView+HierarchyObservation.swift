import ObjectiveC
import UIKit

extension UIEnvironments {
    /// Installs hierarchy observation exactly once per process.
    ///
    /// `UITraitCollection` re-resolves traits whenever a view joins, leaves,
    /// or moves within a hierarchy. To back-port that behavior, `UIView`'s
    /// hierarchy callbacks are observed so cached environment resolutions are
    /// discarded and change registrations fire when the position changes.
    ///
    static let installHierarchyObservation: Void = UIView._uiEnvironmentsInstallHierarchyObservation()
}

extension UIView {
    nonisolated static func _uiEnvironmentsInstallHierarchyObservation() {
        let selectorPairs: [(original: Selector, swizzled: Selector)] = [
            (#selector(UIView.didMoveToWindow), #selector(UIView._uiEnvironmentsDidMoveToWindow)),
            (#selector(UIView.didMoveToSuperview), #selector(UIView._uiEnvironmentsDidMoveToSuperview)),
        ]

        for pair in selectorPairs {
            guard
                let originalMethod = class_getInstanceMethod(UIView.self, pair.original),
                let swizzledMethod = class_getInstanceMethod(UIView.self, pair.swizzled)
            else {
                assertionFailure("Failed to install UIEnvironments hierarchy observation")
                continue
            }

            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }

    @objc private dynamic func _uiEnvironmentsDidMoveToWindow() {
        _uiEnvironmentsDidMoveToWindow()

        _environmentsIfExists?.handleWindowAttachmentChange()
        _uiEnvironmentsManagingViewController?._environmentsIfExists?.handleWindowAttachmentChange()
    }

    @objc private dynamic func _uiEnvironmentsDidMoveToSuperview() {
        _uiEnvironmentsDidMoveToSuperview()

        _environmentsIfExists?.handleSuperviewChange()
        _uiEnvironmentsManagingViewController?._environmentsIfExists?.handleSuperviewChange()
    }

    /// The view controller this view is the root view of, if any.
    ///
    /// A view controller resolves environments through its view, so when the
    /// view's hierarchy position changes, the controller's cached resolution
    /// must be refreshed together with the view's own.
    ///
    private var _uiEnvironmentsManagingViewController: UIViewController? {
        guard
            let viewController = next as? UIViewController,
            viewController.viewIfLoaded === self
        else {
            return nil
        }

        return viewController
    }
}
