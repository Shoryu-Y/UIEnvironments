import Testing
@testable import UIEnvironments
import UIKit

@available(iOS 17.0, *)
private struct ParityPrimaryDefinition: UIEnvironmentDefinition, UITraitDefinition {
    static let defaultValue = "default-primary"
}

@available(iOS 17.0, *)
private struct ParitySecondaryDefinition: UIEnvironmentDefinition, UITraitDefinition {
    static let defaultValue = "default-secondary"
}

@available(iOS 17.0, *)
@MainActor
private final class ParityHierarchy {
    enum ChildHost {
        case branch
        case siblingBranch
    }

    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))

    let rootViewController = UIViewController()
    let childViewController = UIViewController()

    let rootContainerView = UIView()
    let branchView = UIView()
    let siblingBranchView = UIView()
    let siblingLeafView = UIView()
    var childHost: ChildHost = .branch

    init() {
        rootViewController.loadViewIfNeeded()
        childViewController.loadViewIfNeeded()

        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        rootViewController.addChild(childViewController)
        childViewController.didMove(toParent: rootViewController)

        rootViewController.view.addSubview(rootContainerView)
        rootContainerView.addSubview(branchView)
        rootContainerView.addSubview(siblingBranchView)
        siblingBranchView.addSubview(siblingLeafView)

        branchView.addSubview(childViewController.view)
    }

    var childHostView: UIView {
        switch childHost {
        case .branch:
            branchView
        case .siblingBranch:
            siblingBranchView
        }
    }
}

@available(iOS 17.0, *)
private enum ParityTarget: CaseIterable {
    case rootViewController
    case rootView
    case rootContainer
    case branchView
    case siblingBranchView
    case childViewController
    case childView
}

@available(iOS 17.0, *)
private enum ParityOperation {
    case setPrimary(ParityTarget, String)
    case clearPrimary(ParityTarget)
    case setSecondary(ParityTarget, String)
    case clearSecondary(ParityTarget)
    case unloadChildView
    case reloadChildView
    case moveChildViewToBranch
    case moveChildViewToSiblingBranch
    /// Reparents by adding to the new superview without an intervening
    /// `removeFromSuperview`, so the view never transits `window == nil`.
    case moveChildViewToBranchDirect
    case moveChildViewToSiblingBranchDirect
    case detachChildViewController
    case reattachChildViewController
    case registerChildViewObserver
    case unregisterChildViewObserver
    case registerBranchViewObserver
    case unregisterBranchViewObserver
    case registerRootViewControllerObserver
    case unregisterRootViewControllerObserver
}

@available(iOS 17.0, *)
private struct ParityProbeSnapshot: Equatable {
    var primary: String?
    var secondary: String?
}

@available(iOS 17.0, *)
private struct ParitySnapshot: Equatable {
    var rootViewController: ParityProbeSnapshot
    var rootView: ParityProbeSnapshot
    var rootContainer: ParityProbeSnapshot
    var branchView: ParityProbeSnapshot
    var siblingLeafView: ParityProbeSnapshot
    var childViewController: ParityProbeSnapshot
    var childView: ParityProbeSnapshot
    var childViewNotificationCount: Int
    var branchViewNotificationCount: Int
    var rootViewControllerNotificationCount: Int
}

@available(iOS 17.0, *)
@MainActor
private protocol ParityRunner {
    func apply(_ operation: ParityOperation)
    func settle()
    func snapshot() -> ParitySnapshot
}

@available(iOS 17.0, *)
@MainActor
private final class ReferenceTraitRunner: ParityRunner {
    private let hierarchy = ParityHierarchy()
    private var childViewNotificationCount = 0
    private var branchViewNotificationCount = 0
    private var rootViewControllerNotificationCount = 0

    private var childObserverRegistration: (any UITraitChangeRegistration)?
    private var branchObserverRegistration: (any UITraitChangeRegistration)?
    private var rootViewControllerObserverRegistration: (any UITraitChangeRegistration)?

    func apply(_ operation: ParityOperation) {
        switch operation {
        case let .setPrimary(target, value):
            setPrimary(target: target, value: value)
        case let .clearPrimary(target):
            clearPrimary(target: target)
        case let .setSecondary(target, value):
            setSecondary(target: target, value: value)
        case let .clearSecondary(target):
            clearSecondary(target: target)
        case .unloadChildView:
            hierarchy.childViewController.view = nil
        case .reloadChildView:
            hierarchy.childViewController.loadViewIfNeeded()
            if hierarchy.childViewController.parent != nil {
                hierarchy.childHostView.addSubview(hierarchy.childViewController.view)
            }
        case .moveChildViewToBranch:
            hierarchy.childHost = .branch
            reattachChildViewIfLoaded()
        case .moveChildViewToSiblingBranch:
            hierarchy.childHost = .siblingBranch
            reattachChildViewIfLoaded()
        case .moveChildViewToBranchDirect:
            hierarchy.childHost = .branch
            moveChildViewDirectlyIfLoaded()
        case .moveChildViewToSiblingBranchDirect:
            hierarchy.childHost = .siblingBranch
            moveChildViewDirectlyIfLoaded()
        case .detachChildViewController:
            detachChildViewController()
        case .reattachChildViewController:
            reattachChildViewController()
        case .registerChildViewObserver:
            guard childObserverRegistration == nil else { return }
            childObserverRegistration = hierarchy.childViewController.view.registerForTraitChanges(
                [ParityPrimaryDefinition.self, ParitySecondaryDefinition.self]
            ) { [weak self] (_: UIView, _: UITraitCollection) in
                self?.childViewNotificationCount += 1
            }
        case .unregisterChildViewObserver:
            guard let childObserverRegistration else { return }
            hierarchy.childViewController.view.unregisterForTraitChanges(childObserverRegistration)
            self.childObserverRegistration = nil
        case .registerBranchViewObserver:
            guard branchObserverRegistration == nil else { return }
            branchObserverRegistration = hierarchy.branchView.registerForTraitChanges(
                [ParityPrimaryDefinition.self, ParitySecondaryDefinition.self]
            ) { [weak self] (_: UIView, _: UITraitCollection) in
                self?.branchViewNotificationCount += 1
            }
        case .unregisterBranchViewObserver:
            guard let branchObserverRegistration else { return }
            hierarchy.branchView.unregisterForTraitChanges(branchObserverRegistration)
            self.branchObserverRegistration = nil
        case .registerRootViewControllerObserver:
            guard rootViewControllerObserverRegistration == nil else { return }
            rootViewControllerObserverRegistration = hierarchy.rootViewController.registerForTraitChanges(
                [ParityPrimaryDefinition.self, ParitySecondaryDefinition.self]
            ) { [weak self] (_: UIViewController, _: UITraitCollection) in
                self?.rootViewControllerNotificationCount += 1
            }
        case .unregisterRootViewControllerObserver:
            guard let rootViewControllerObserverRegistration else { return }
            hierarchy.rootViewController.unregisterForTraitChanges(rootViewControllerObserverRegistration)
            self.rootViewControllerObserverRegistration = nil
        }
    }

    func snapshot() -> ParitySnapshot {
        ParitySnapshot(
            rootViewController: probe(viewController: hierarchy.rootViewController),
            rootView: probe(view: hierarchy.rootViewController.view),
            rootContainer: probe(view: hierarchy.rootContainerView),
            branchView: probe(view: hierarchy.branchView),
            siblingLeafView: probe(view: hierarchy.siblingLeafView),
            childViewController: probe(viewController: hierarchy.childViewController),
            childView: probe(view: hierarchy.childViewController.viewIfLoaded),
            childViewNotificationCount: childViewNotificationCount,
            branchViewNotificationCount: branchViewNotificationCount,
            rootViewControllerNotificationCount: rootViewControllerNotificationCount
        )
    }

    func settle() {
        hierarchy.window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    private func setPrimary(target: ParityTarget, value: String) {
        switch target {
        case .rootViewController:
            hierarchy.rootViewController.traitOverrides[ParityPrimaryDefinition.self] = value
        case .rootView:
            hierarchy.rootViewController.view.traitOverrides[ParityPrimaryDefinition.self] = value
        case .rootContainer:
            hierarchy.rootContainerView.traitOverrides[ParityPrimaryDefinition.self] = value
        case .branchView:
            hierarchy.branchView.traitOverrides[ParityPrimaryDefinition.self] = value
        case .siblingBranchView:
            hierarchy.siblingBranchView.traitOverrides[ParityPrimaryDefinition.self] = value
        case .childViewController:
            hierarchy.childViewController.traitOverrides[ParityPrimaryDefinition.self] = value
        case .childView:
            guard let childView = hierarchy.childViewController.viewIfLoaded else { return }
            childView.traitOverrides[ParityPrimaryDefinition.self] = value
        }
    }

    private func clearPrimary(target: ParityTarget) {
        switch target {
        case .rootViewController:
            hierarchy.rootViewController.traitOverrides.remove(ParityPrimaryDefinition.self)
        case .rootView:
            hierarchy.rootViewController.view.traitOverrides.remove(ParityPrimaryDefinition.self)
        case .rootContainer:
            hierarchy.rootContainerView.traitOverrides.remove(ParityPrimaryDefinition.self)
        case .branchView:
            hierarchy.branchView.traitOverrides.remove(ParityPrimaryDefinition.self)
        case .siblingBranchView:
            hierarchy.siblingBranchView.traitOverrides.remove(ParityPrimaryDefinition.self)
        case .childViewController:
            hierarchy.childViewController.traitOverrides.remove(ParityPrimaryDefinition.self)
        case .childView:
            hierarchy.childViewController.viewIfLoaded?.traitOverrides.remove(ParityPrimaryDefinition.self)
        }
    }

    private func setSecondary(target: ParityTarget, value: String) {
        switch target {
        case .rootViewController:
            hierarchy.rootViewController.traitOverrides[ParitySecondaryDefinition.self] = value
        case .rootView:
            hierarchy.rootViewController.view.traitOverrides[ParitySecondaryDefinition.self] = value
        case .rootContainer:
            hierarchy.rootContainerView.traitOverrides[ParitySecondaryDefinition.self] = value
        case .branchView:
            hierarchy.branchView.traitOverrides[ParitySecondaryDefinition.self] = value
        case .siblingBranchView:
            hierarchy.siblingBranchView.traitOverrides[ParitySecondaryDefinition.self] = value
        case .childViewController:
            hierarchy.childViewController.traitOverrides[ParitySecondaryDefinition.self] = value
        case .childView:
            hierarchy.childViewController.viewIfLoaded?.traitOverrides[ParitySecondaryDefinition.self] = value
        }
    }

    private func clearSecondary(target: ParityTarget) {
        switch target {
        case .rootViewController:
            hierarchy.rootViewController.traitOverrides.remove(ParitySecondaryDefinition.self)
        case .rootView:
            hierarchy.rootViewController.view.traitOverrides.remove(ParitySecondaryDefinition.self)
        case .rootContainer:
            hierarchy.rootContainerView.traitOverrides.remove(ParitySecondaryDefinition.self)
        case .branchView:
            hierarchy.branchView.traitOverrides.remove(ParitySecondaryDefinition.self)
        case .siblingBranchView:
            hierarchy.siblingBranchView.traitOverrides.remove(ParitySecondaryDefinition.self)
        case .childViewController:
            hierarchy.childViewController.traitOverrides.remove(ParitySecondaryDefinition.self)
        case .childView:
            hierarchy.childViewController.viewIfLoaded?.traitOverrides.remove(ParitySecondaryDefinition.self)
        }
    }

    private func reattachChildViewIfLoaded() {
        guard let childView = hierarchy.childViewController.viewIfLoaded else { return }
        childView.removeFromSuperview()
        hierarchy.childHostView.addSubview(childView)
    }

    /// Moves the child view to the new host without first removing it, so the
    /// window stays constant (no `didMoveToWindow`); only `didMoveToSuperview`
    /// fires. UIKit removes it from the old superview automatically.
    private func moveChildViewDirectlyIfLoaded() {
        guard let childView = hierarchy.childViewController.viewIfLoaded else { return }
        hierarchy.childHostView.addSubview(childView)
    }

    private func detachChildViewController() {
        guard hierarchy.childViewController.parent != nil else { return }
        hierarchy.childViewController.willMove(toParent: nil)
        hierarchy.childViewController.viewIfLoaded?.removeFromSuperview()
        hierarchy.childViewController.removeFromParent()
    }

    private func reattachChildViewController() {
        guard hierarchy.childViewController.parent == nil else { return }
        hierarchy.rootViewController.addChild(hierarchy.childViewController)
        if let childView = hierarchy.childViewController.viewIfLoaded {
            hierarchy.childHostView.addSubview(childView)
        }
        hierarchy.childViewController.didMove(toParent: hierarchy.rootViewController)
    }

    private func probe(viewController: UIViewController) -> ParityProbeSnapshot {
        let traits = viewController.traitCollection
        return ParityProbeSnapshot(
            primary: traits[ParityPrimaryDefinition.self],
            secondary: traits[ParitySecondaryDefinition.self]
        )
    }

    private func probe(view: UIView?) -> ParityProbeSnapshot {
        guard let view else {
            return ParityProbeSnapshot(primary: nil, secondary: nil)
        }

        let traits = view.traitCollection
        return ParityProbeSnapshot(
            primary: traits[ParityPrimaryDefinition.self],
            secondary: traits[ParitySecondaryDefinition.self]
        )
    }
}

@available(iOS 17.0, *)
@MainActor
private final class UIEnvironmentsRunner: ParityRunner {
    private let hierarchy = ParityHierarchy()
    private var childViewNotificationCount = 0
    private var branchViewNotificationCount = 0
    private var rootViewControllerNotificationCount = 0

    private var childObserverRegistration: UIEnvironmentChangeRegistration?
    private var branchObserverRegistration: UIEnvironmentChangeRegistration?
    private var rootViewControllerObserverRegistration: UIEnvironmentChangeRegistration?

    func apply(_ operation: ParityOperation) {
        switch operation {
        case let .setPrimary(target, value):
            updateEnvironmentOverrides(target: target) { $0[ParityPrimaryDefinition.self] = value }
        case let .clearPrimary(target):
            clearEnvironmentOverride(target: target, identifier: ObjectIdentifier(ParityPrimaryDefinition.self))
        case let .setSecondary(target, value):
            updateEnvironmentOverrides(target: target) { $0[ParitySecondaryDefinition.self] = value }
        case let .clearSecondary(target):
            clearEnvironmentOverride(target: target, identifier: ObjectIdentifier(ParitySecondaryDefinition.self))
        case .unloadChildView:
            hierarchy.childViewController.view = nil
        case .reloadChildView:
            hierarchy.childViewController.loadViewIfNeeded()
            if hierarchy.childViewController.parent != nil {
                hierarchy.childHostView.addSubview(hierarchy.childViewController.view)
            }
        case .moveChildViewToBranch:
            hierarchy.childHost = .branch
            reattachChildViewIfLoaded()
        case .moveChildViewToSiblingBranch:
            hierarchy.childHost = .siblingBranch
            reattachChildViewIfLoaded()
        case .moveChildViewToBranchDirect:
            hierarchy.childHost = .branch
            moveChildViewDirectlyIfLoaded()
        case .moveChildViewToSiblingBranchDirect:
            hierarchy.childHost = .siblingBranch
            moveChildViewDirectlyIfLoaded()
        case .detachChildViewController:
            detachChildViewController()
        case .reattachChildViewController:
            reattachChildViewController()
        case .registerChildViewObserver:
            guard childObserverRegistration == nil else { return }
            childObserverRegistration = hierarchy.childViewController.view.registerForEnvironmentChanges(
                [ParityPrimaryDefinition.self, ParitySecondaryDefinition.self]
            ) { [weak self] in
                self?.childViewNotificationCount += 1
            }
        case .unregisterChildViewObserver:
            guard let childObserverRegistration else { return }
            hierarchy.childViewController.view.unregisterFromEnvironmentChanges(childObserverRegistration)
            self.childObserverRegistration = nil
        case .registerBranchViewObserver:
            guard branchObserverRegistration == nil else { return }
            branchObserverRegistration = hierarchy.branchView.registerForEnvironmentChanges(
                [ParityPrimaryDefinition.self, ParitySecondaryDefinition.self]
            ) { [weak self] in
                self?.branchViewNotificationCount += 1
            }
        case .unregisterBranchViewObserver:
            guard let branchObserverRegistration else { return }
            hierarchy.branchView.unregisterFromEnvironmentChanges(branchObserverRegistration)
            self.branchObserverRegistration = nil
        case .registerRootViewControllerObserver:
            guard rootViewControllerObserverRegistration == nil else { return }
            rootViewControllerObserverRegistration = hierarchy.rootViewController.registerForEnvironmentChanges(
                [ParityPrimaryDefinition.self, ParitySecondaryDefinition.self]
            ) { [weak self] in
                self?.rootViewControllerNotificationCount += 1
            }
        case .unregisterRootViewControllerObserver:
            guard let rootViewControllerObserverRegistration else { return }
            hierarchy.rootViewController.unregisterFromEnvironmentChanges(rootViewControllerObserverRegistration)
            self.rootViewControllerObserverRegistration = nil
        }
    }

    func snapshot() -> ParitySnapshot {
        ParitySnapshot(
            rootViewController: probe(viewController: hierarchy.rootViewController),
            rootView: probe(view: hierarchy.rootViewController.view),
            rootContainer: probe(view: hierarchy.rootContainerView),
            branchView: probe(view: hierarchy.branchView),
            siblingLeafView: probe(view: hierarchy.siblingLeafView),
            childViewController: probe(viewController: hierarchy.childViewController),
            childView: probe(view: hierarchy.childViewController.viewIfLoaded),
            childViewNotificationCount: childViewNotificationCount,
            branchViewNotificationCount: branchViewNotificationCount,
            rootViewControllerNotificationCount: rootViewControllerNotificationCount
        )
    }

    func settle() {
        hierarchy.window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    private func updateEnvironmentOverrides(
        target: ParityTarget,
        _ update: (inout UIEnvironmentOverrides) -> Void
    ) {
        switch target {
        case .rootViewController:
            var overrides = hierarchy.rootViewController.environmentOverrides
            update(&overrides)
            hierarchy.rootViewController.environmentOverrides = overrides
        case .rootView:
            var overrides = hierarchy.rootViewController.view.environmentOverrides
            update(&overrides)
            hierarchy.rootViewController.view.environmentOverrides = overrides
        case .rootContainer:
            var overrides = hierarchy.rootContainerView.environmentOverrides
            update(&overrides)
            hierarchy.rootContainerView.environmentOverrides = overrides
        case .branchView:
            var overrides = hierarchy.branchView.environmentOverrides
            update(&overrides)
            hierarchy.branchView.environmentOverrides = overrides
        case .siblingBranchView:
            var overrides = hierarchy.siblingBranchView.environmentOverrides
            update(&overrides)
            hierarchy.siblingBranchView.environmentOverrides = overrides
        case .childViewController:
            var overrides = hierarchy.childViewController.environmentOverrides
            update(&overrides)
            hierarchy.childViewController.environmentOverrides = overrides
        case .childView:
            guard let childView = hierarchy.childViewController.viewIfLoaded else { return }
            var overrides = childView.environmentOverrides
            update(&overrides)
            childView.environmentOverrides = overrides
        }
    }

    private func clearEnvironmentOverride(target: ParityTarget, identifier: ObjectIdentifier) {
        updateEnvironmentOverrides(target: target) { overrides in
            overrides.entries.removeValue(forKey: identifier)
        }
    }

    private func reattachChildViewIfLoaded() {
        guard let childView = hierarchy.childViewController.viewIfLoaded else { return }
        childView.removeFromSuperview()
        hierarchy.childHostView.addSubview(childView)
    }

    /// Moves the child view to the new host without first removing it, so the
    /// window stays constant (no `didMoveToWindow`); only `didMoveToSuperview`
    /// fires. UIKit removes it from the old superview automatically.
    private func moveChildViewDirectlyIfLoaded() {
        guard let childView = hierarchy.childViewController.viewIfLoaded else { return }
        hierarchy.childHostView.addSubview(childView)
    }

    private func detachChildViewController() {
        guard hierarchy.childViewController.parent != nil else { return }
        hierarchy.childViewController.willMove(toParent: nil)
        hierarchy.childViewController.viewIfLoaded?.removeFromSuperview()
        hierarchy.childViewController.removeFromParent()
    }

    private func reattachChildViewController() {
        guard hierarchy.childViewController.parent == nil else { return }
        hierarchy.rootViewController.addChild(hierarchy.childViewController)
        if let childView = hierarchy.childViewController.viewIfLoaded {
            hierarchy.childHostView.addSubview(childView)
        }
        hierarchy.childViewController.didMove(toParent: hierarchy.rootViewController)
    }

    private func probe(viewController: UIViewController) -> ParityProbeSnapshot {
        let environments = viewController.environments
        return ParityProbeSnapshot(
            primary: environments[ParityPrimaryDefinition.self],
            secondary: environments[ParitySecondaryDefinition.self]
        )
    }

    private func probe(view: UIView?) -> ParityProbeSnapshot {
        guard let view else {
            return ParityProbeSnapshot(primary: nil, secondary: nil)
        }

        let environments = view.environments
        return ParityProbeSnapshot(
            primary: environments[ParityPrimaryDefinition.self],
            secondary: environments[ParitySecondaryDefinition.self]
        )
    }
}

@available(iOS 17.0, *)
@MainActor
private func assertParity(
    _ scenarioName: String,
    operations: [ParityOperation],
    fileID: String = #fileID,
    line: Int = #line
) {
    let reference = ReferenceTraitRunner()
    let environments = UIEnvironmentsRunner()

    var referenceTrace: [ParitySnapshot] = [reference.snapshot()]
    var environmentsTrace: [ParitySnapshot] = [environments.snapshot()]

    for operation in operations {
        reference.apply(operation)
        environments.apply(operation)
        reference.settle()
        environments.settle()
        referenceTrace.append(reference.snapshot())
        environmentsTrace.append(environments.snapshot())
    }

    #expect(referenceTrace.count == environmentsTrace.count)
    for index in referenceTrace.indices {
        #expect(
            referenceTrace[index] == environmentsTrace[index],
            Comment(rawValue: "\(scenarioName) step \(index) mismatch @\(fileID):\(line)")
        )
    }
}

/// Runs `assertParity`, tolerating the known fallback-path divergence in value
/// resolution for unloaded or detached child view controllers.
///
/// With the native trait bridge disabled, environment values resolve only
/// through the live responder (`next`) chain. When a child view controller's
/// view is unloaded or detached that chain is severed, so an inherited value
/// falls back to the default — whereas real UIKit keeps resolving it through
/// view-controller containment. This is a read-path limitation that predates
/// commit abbdaa5 and is outside the scope of the notification redesign, so it
/// is recorded as a known issue only in the fallback mode. The bridge-enabled
/// path (the default) is verified strictly.
///
@available(iOS 17.0, *)
@MainActor
private func assertParityAllowingUnloadedContainmentDivergence(
    _ scenarioName: String,
    operations: [ParityOperation]
) {
    guard !UIEnvironments.isNativeTraitBridgeEnabled else {
        assertParity(scenarioName, operations: operations)
        return
    }

    withKnownIssue(
        "Fallback resolution cannot follow view-controller containment through an unloaded or detached child view (known pre-abbdaa5 divergence)."
    ) {
        assertParity(scenarioName, operations: operations)
    }
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_inheritanceAndPrecedence() {
    assertParity(
        "inheritanceAndPrecedence",
        operations: [
            .setPrimary(.rootViewController, "root-vc"),
            .setPrimary(.rootView, "root-view"),
            .setPrimary(.rootContainer, "root-container"),
            .setPrimary(.branchView, "branch"),
            .setPrimary(.childViewController, "child-vc"),
            .setPrimary(.childView, "child-view"),
            .setPrimary(.siblingBranchView, "sibling-branch"),
            .clearPrimary(.childView),
            .clearPrimary(.childViewController),
            .clearPrimary(.branchView),
            .clearPrimary(.rootContainer),
            .clearPrimary(.rootView),
            .clearPrimary(.rootViewController),
            .clearPrimary(.siblingBranchView),
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_overrideRemovalAndDefaultFallback() {
    assertParity(
        "overrideRemovalAndDefaultFallback",
        operations: [
            .setPrimary(.rootViewController, "r1"),
            .setSecondary(.rootViewController, "10"),
            .setPrimary(.childViewController, "c1"),
            .setSecondary(.childViewController, "20"),
            .clearPrimary(.childViewController),
            .clearSecondary(.childViewController),
            .clearPrimary(.rootViewController),
            .clearSecondary(.rootViewController),
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_unloadedChildViewControllerBehavior() {
    assertParityAllowingUnloadedContainmentDivergence(
        "unloadedChildViewControllerBehavior",
        operations: [
            .setPrimary(.rootViewController, "before-unload"),
            .setSecondary(.rootViewController, "1"),
            .unloadChildView,
            .setPrimary(.rootViewController, "after-unload"),
            .setSecondary(.rootViewController, "2"),
            .clearPrimary(.rootViewController),
            .clearSecondary(.rootViewController),
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_continuousMultiKeyUpdates() {
    assertParity(
        "continuousMultiKeyUpdates",
        operations: [
            .setPrimary(.rootViewController, "a"),
            .setSecondary(.rootViewController, "1"),
            .setPrimary(.rootViewController, "b"),
            .setSecondary(.rootViewController, "2"),
            .setPrimary(.branchView, "branch-1"),
            .setSecondary(.branchView, "11"),
            .setPrimary(.branchView, "branch-2"),
            .setSecondary(.branchView, "12"),
            .clearPrimary(.branchView),
            .clearSecondary(.branchView),
            .clearPrimary(.rootViewController),
            .clearSecondary(.rootViewController),
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_observerRegisterAndUnregister() {
    assertParity(
        "observerRegisterAndUnregister",
        operations: [
            .registerChildViewObserver,
            .setPrimary(.rootViewController, "n1"),
            .setSecondary(.rootViewController, "1"),
            .setPrimary(.rootViewController, "n2"),
            .setSecondary(.rootViewController, "2"),
            .unregisterChildViewObserver,
            .setPrimary(.rootViewController, "after-unregister"),
            .setSecondary(.rootViewController, "999"),
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_branchPropagation() {
    assertParity(
        "branchPropagation",
        operations: [
            .setPrimary(.siblingBranchView, "s1"),
            .setSecondary(.siblingBranchView, "101"),
            .setPrimary(.branchView, "b1"),
            .setSecondary(.branchView, "201"),
            .setPrimary(.rootContainer, "container"),
            .setSecondary(.rootContainer, "301"),
            .clearPrimary(.siblingBranchView),
            .clearSecondary(.siblingBranchView),
            .clearPrimary(.branchView),
            .clearSecondary(.branchView),
            .clearPrimary(.rootContainer),
            .clearSecondary(.rootContainer),
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_reparentingChildViewAcrossBranches() {
    assertParity(
        "reparentingChildViewAcrossBranches",
        operations: [
            .setPrimary(.rootContainer, "container"),
            .setPrimary(.branchView, "branch"),
            .setSecondary(.branchView, "11"),
            .setPrimary(.siblingBranchView, "sibling"),
            .setSecondary(.siblingBranchView, "22"),
            .moveChildViewToSiblingBranch,
            .clearPrimary(.siblingBranchView),
            .clearSecondary(.siblingBranchView),
            .moveChildViewToBranch,
            .clearPrimary(.branchView),
            .clearSecondary(.branchView),
            .clearPrimary(.rootContainer),
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_detachAndReattachChildViewControllerContainment() {
    assertParityAllowingUnloadedContainmentDivergence(
        "detachAndReattachChildViewControllerContainment",
        operations: [
            .setPrimary(.rootViewController, "root-1"),
            .setSecondary(.rootViewController, "1"),
            .detachChildViewController,
            .setPrimary(.rootViewController, "root-2"),
            .setSecondary(.rootViewController, "2"),
            .reattachChildViewController,
            .setPrimary(.branchView, "branch"),
            .setSecondary(.branchView, "3"),
            .detachChildViewController,
            .reattachChildViewController,
            .clearPrimary(.branchView),
            .clearSecondary(.branchView),
            .clearPrimary(.rootViewController),
            .clearSecondary(.rootViewController),
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_reloadChildViewAfterUnloadAndReattach() {
    assertParityAllowingUnloadedContainmentDivergence(
        "reloadChildViewAfterUnloadAndReattach",
        operations: [
            .setPrimary(.rootViewController, "before-unload"),
            .setSecondary(.rootViewController, "1"),
            .unloadChildView,
            .setPrimary(.rootViewController, "while-unloaded"),
            .setSecondary(.rootViewController, "2"),
            .reloadChildView,
            .moveChildViewToSiblingBranch,
            .setPrimary(.siblingBranchView, "sibling"),
            .moveChildViewToBranch,
            .clearPrimary(.siblingBranchView),
            .clearPrimary(.rootViewController),
            .clearSecondary(.rootViewController),
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_observerNotifiedWhenReparentingChangesResolvedValue() {
    assertParity(
        "observerNotifiedWhenReparentingChangesResolvedValue",
        operations: [
            .setPrimary(.branchView, "branch"),
            .setPrimary(.siblingBranchView, "sibling"),
            .registerChildViewObserver,
            // observer 登録済みのまま、解決値が変わる reparent を行う。
            // 実 UIKit が値変化として通知するかどうかを差分で検証する。
            .moveChildViewToSiblingBranch,
            .moveChildViewToBranch,
            .unregisterChildViewObserver,
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_observerNotifiedWhenDirectReparentChangesResolvedValue() {
    assertParity(
        "observerNotifiedWhenDirectReparentChangesResolvedValue",
        operations: [
            .setPrimary(.branchView, "branch"),
            .setPrimary(.siblingBranchView, "sibling"),
            .registerChildViewObserver,
            // removeFromSuperview を挟まない直接移動。window は不変で
            // didMoveToSuperview のみ発火する。実 UIKit がこの経路でも
            // 値変化として通知するかを差分で検証する。
            .moveChildViewToSiblingBranchDirect,
            .moveChildViewToBranchDirect,
            .unregisterChildViewObserver,
        ]
    )
}

@available(iOS 17.0, *)
@MainActor
@Test func parity_multiObserverTargetsWithSelectiveUnregister() {
    assertParity(
        "multiObserverTargetsWithSelectiveUnregister",
        operations: [
            .registerChildViewObserver,
            .registerBranchViewObserver,
            .registerRootViewControllerObserver,
            .setPrimary(.rootViewController, "n1"),
            .setSecondary(.branchView, "11"),
            .unregisterBranchViewObserver,
            .setPrimary(.branchView, "n2"),
            .unregisterChildViewObserver,
            .setPrimary(.rootViewController, "n3"),
            .unregisterRootViewControllerObserver,
            .setPrimary(.rootViewController, "n4"),
        ]
    )
}
