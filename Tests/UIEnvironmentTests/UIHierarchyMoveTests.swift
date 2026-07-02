import Testing
@testable import UIEnvironments
import UIKit

private struct MoveTestEnvironment: UIEnvironmentDefinition {
    static let defaultValue = 0
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
