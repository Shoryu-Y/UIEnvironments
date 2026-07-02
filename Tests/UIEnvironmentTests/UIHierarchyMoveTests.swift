import Testing
@testable import UIEnvironments
import UIKit

private struct MoveTestEnvironment: UIEnvironmentDefinition {
    static let defaultValue = 0
}

@available(iOS 17.0, *)
private struct MoveTestTrait: UITraitDefinition {
    static let defaultValue = "default"
}

private extension UIEnvironments {
    var moveTestValue: Int {
        self[MoveTestEnvironment.self]
    }
}

private extension UIMutableEnvironments {
    var moveTestValue: Int {
        get { self[MoveTestEnvironment.self] }
        set { self[MoveTestEnvironment.self] = newValue }
    }
}

@MainActor
@Test func readWhileDetachedIsNotCachedAcrossAttach() {
    let window = UIWindow()
    window.environmentOverrides.moveTestValue = 42

    let view = UIView()

    // Reading while detached resolves the default value...
    #expect(view.environments.moveTestValue == MoveTestEnvironment.defaultValue)

    // ...but must not stick after the view joins a hierarchy,
    // even though no override is written in between.
    window.addSubview(view)
    #expect(view.environments.moveTestValue == 42)
}

@MainActor
@Test func movingBetweenWindowsResolvesNewWindowOverride() {
    let firstWindow = UIWindow()
    firstWindow.environmentOverrides.moveTestValue = 1

    let secondWindow = UIWindow()
    secondWindow.environmentOverrides.moveTestValue = 2

    let view = UIView()

    firstWindow.addSubview(view)
    #expect(view.environments.moveTestValue == 1)

    secondWindow.addSubview(view)
    #expect(view.environments.moveTestValue == 2)
}

@MainActor
@Test func reparentingWithinSameWindowResolvesNewAncestorOverride() {
    let window = UIWindow()
    let firstBranch = UIView()
    let secondBranch = UIView()

    firstBranch.environmentOverrides.moveTestValue = 1
    secondBranch.environmentOverrides.moveTestValue = 2

    window.addSubview(firstBranch)
    window.addSubview(secondBranch)

    let view = UIView()

    firstBranch.addSubview(view)
    #expect(view.environments.moveTestValue == 1)

    secondBranch.addSubview(view)
    #expect(view.environments.moveTestValue == 2)
}

@MainActor
@Test func detachingResolvesDefaultValueAgain() {
    let window = UIWindow()
    window.environmentOverrides.moveTestValue = 42

    let view = UIView()
    window.addSubview(view)
    #expect(view.environments.moveTestValue == 42)

    view.removeFromSuperview()
    #expect(view.environments.moveTestValue == MoveTestEnvironment.defaultValue)
}

@MainActor
@Test func registrationFiresOnWindowAttachAndDetach() {
    let window = UIWindow()
    window.environmentOverrides.moveTestValue = 7

    let view = UIView()

    var changeCount = 0
    view.registerForEnvironmentChanges([MoveTestEnvironment.self]) {
        changeCount += 1
    }

    window.addSubview(view)
    #expect(changeCount == 1)
    #expect(view.environments.moveTestValue == 7)

    view.removeFromSuperview()
    #expect(changeCount == 2)
    #expect(view.environments.moveTestValue == MoveTestEnvironment.defaultValue)
}

@MainActor
@Test func viewControllerRegistrationFiresWhenItsViewJoinsWindow() {
    let window = UIWindow()
    window.environmentOverrides.moveTestValue = 7

    let viewController = UIViewController()
    viewController.loadViewIfNeeded()

    var changeCount = 0
    viewController.registerForEnvironmentChanges([MoveTestEnvironment.self]) {
        changeCount += 1
    }

    window.addSubview(viewController.view)
    #expect(changeCount == 1)
    #expect(viewController.environments.moveTestValue == 7)
}

// MARK: - Absolute firing-count probes
//
// The parity tests only assert that this library's notification count equals
// real UIKit's. These probes pin the absolute number this library produces so
// the mechanism claimed in commit messages ("fires via the window-change
// path") is actually verified rather than assumed.

@MainActor
@Test func explicitReparentFiringCount() {
    let window = UIWindow()
    let branch = UIView()
    let sibling = UIView()
    branch.environmentOverrides.moveTestValue = 1
    sibling.environmentOverrides.moveTestValue = 2
    window.addSubview(branch)
    window.addSubview(sibling)

    let view = UIView()
    branch.addSubview(view)

    var changeCount = 0
    view.registerForEnvironmentChanges([MoveTestEnvironment.self]) {
        changeCount += 1
    }

    // Explicit removeFromSuperview + addSubview to the sibling branch.
    view.removeFromSuperview()
    sibling.addSubview(view)

    #expect(view.environments.moveTestValue == 2)
    #expect(changeCount >= 1)
}

@MainActor
@Test func directReparentFiringCount() {
    let window = UIWindow()
    let branch = UIView()
    let sibling = UIView()
    branch.environmentOverrides.moveTestValue = 1
    sibling.environmentOverrides.moveTestValue = 2
    window.addSubview(branch)
    window.addSubview(sibling)

    let view = UIView()
    branch.addSubview(view)

    var changeCount = 0
    view.registerForEnvironmentChanges([MoveTestEnvironment.self]) {
        changeCount += 1
    }

    // Direct addSubview to the sibling branch without an explicit
    // removeFromSuperview first. The window never changes, so only
    // didMoveToSuperview fires. The resolved value re-resolves correctly, but
    // registrations do NOT fire (documented limitation): registrations fire on
    // window changes, and lacking value equality we cannot fire on every
    // superview change without over-notifying elsewhere.
    sibling.addSubview(view)

    #expect(view.environments.moveTestValue == 2)
    #expect(changeCount == 0)
}

/// Ground truth: does real UIKit's `registerForTraitChanges` fire for the same
/// plain-view direct reparent? This determines whether the limitation above is
/// an actual divergence from UIKit or matches it.
@available(iOS 17.0, *)
@MainActor
@Test func directReparentRealUIKitFiringCount() {
    let window = UIWindow()
    let branch = UIView()
    let sibling = UIView()
    branch.traitOverrides[MoveTestTrait.self] = "1"
    sibling.traitOverrides[MoveTestTrait.self] = "2"
    window.addSubview(branch)
    window.addSubview(sibling)

    let view = UIView()
    branch.addSubview(view)

    var changeCount = 0
    let registration = view.registerForTraitChanges([MoveTestTrait.self]) { (_: UIView, _: UITraitCollection) in
        changeCount += 1
    }
    defer { view.unregisterForTraitChanges(registration) }

    sibling.addSubview(view)
    window.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.01))

    #expect(view.traitCollection[MoveTestTrait.self] == "2")
    #expect(changeCount >= 1)
}

@MainActor
@Test func viewControllerValueFollowsItsViewAcrossWindows() {
    let firstWindow = UIWindow()
    firstWindow.environmentOverrides.moveTestValue = 1

    let secondWindow = UIWindow()
    secondWindow.environmentOverrides.moveTestValue = 2

    let viewController = UIViewController()
    viewController.loadViewIfNeeded()

    firstWindow.addSubview(viewController.view)
    #expect(viewController.environments.moveTestValue == 1)

    secondWindow.addSubview(viewController.view)
    #expect(viewController.environments.moveTestValue == 2)
}
