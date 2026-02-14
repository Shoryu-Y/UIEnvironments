import Testing
import UIKit
@testable import UIEnvironments

private struct TestIntEnvironment: UIEnvironmentDefinition {
    static let defaultValue = 0
}

private struct TestStringEnvironment: UIEnvironmentDefinition {
    static let defaultValue = "default"
}

private extension UIEnvironments {
    var testInt: Int {
        self[TestIntEnvironment.self]
    }

    var testString: String {
        self[TestStringEnvironment.self]
    }
}

private extension UIMutableEnvironments {
    var testInt: Int {
        get { self[TestIntEnvironment.self] }
        set { self[TestIntEnvironment.self] = newValue }
    }

    var testString: String {
        get { self[TestStringEnvironment.self] }
        set { self[TestStringEnvironment.self] = newValue }
    }
}

/// Hierarchy used by complex tests.
///
/// UIViewController chain:
/// rootViewController
///   -> childViewController
///     -> grandChildViewController
///
/// UIView tree:
/// rootViewController.view
///   -> rootContainerView
///     -> branchView
///       -> childViewController.view
///         -> deepView
///           -> grandChildViewController.view
///     -> siblingBranchView
///       -> siblingLeafView
/// 
private struct ComplexHierarchy {
    let rootViewController: UIViewController
    let rootContainerView: UIView
    let branchView: UIView
    let siblingBranchView: UIView
    let siblingLeafView: UIView
    let childViewController: UIViewController
    let deepView: UIView
    let grandChildViewController: UIViewController
}

@MainActor
private func makeComplexHierarchy() -> ComplexHierarchy {
    let rootViewController = UIViewController()
    let childViewController = UIViewController()
    let grandChildViewController = UIViewController()

    let rootContainerView = UIView()
    let branchView = UIView()
    let siblingBranchView = UIView()
    let siblingLeafView = UIView()
    let deepView = UIView()

    rootViewController.loadViewIfNeeded()
    childViewController.loadViewIfNeeded()
    grandChildViewController.loadViewIfNeeded()

    // Build controller containment: root -> child -> grandChild
    rootViewController.addChild(childViewController)
    childViewController.didMove(toParent: rootViewController)

    childViewController.addChild(grandChildViewController)
    grandChildViewController.didMove(toParent: childViewController)

    // Build view tree:
    // root.view -> rootContainerView
    // rootContainerView -> branchView / siblingBranchView
    // branchView -> child.view -> deepView -> grandChild.view
    // siblingBranchView -> siblingLeafView
    rootViewController.view.addSubview(rootContainerView)
    rootContainerView.addSubview(branchView)
    rootContainerView.addSubview(siblingBranchView)
    siblingBranchView.addSubview(siblingLeafView)

    branchView.addSubview(childViewController.view)
    childViewController.view.addSubview(deepView)
    deepView.addSubview(grandChildViewController.view)

    return ComplexHierarchy(
        rootViewController: rootViewController,
        rootContainerView: rootContainerView,
        branchView: branchView,
        siblingBranchView: siblingBranchView,
        siblingLeafView: siblingLeafView,
        childViewController: childViewController,
        deepView: deepView,
        grandChildViewController: grandChildViewController
    )
}

@MainActor
@Test func cacheIsInvalidatedAfterOverrideChangeWithoutRegistrations() {
    let parent = UIView()
    let child = UIView()

    parent.addSubview(child)

    parent.environmentOverrides.testInt = 1
    #expect(child.environments.testInt == 1)

    _ = child.environments.testInt

    parent.environmentOverrides.testInt = 2
    #expect(child.environments.testInt == 2)
}

@MainActor
@Test func cacheIsInvalidatedWithViewControllerHierarchyAfterAttachingChildView() {
    let parent = UIViewController()
    let child = UIViewController()

    parent.loadViewIfNeeded()
    child.loadViewIfNeeded()

    parent.addChild(child)
    parent.view.addSubview(child.view)
    child.didMove(toParent: parent)

    parent.environmentOverrides.testInt = 1
    #expect(child.view.environments.testInt == 1)

    _ = child.view.environments.testInt

    parent.environmentOverrides.testInt = 2
    #expect(child.view.environments.testInt == 2)
}

@MainActor
@Test func unloadedChildViewControllerUsesDefaultAfterParentOverrideChange() {
    let parent = UIViewController()
    let child = UIViewController()

    parent.loadViewIfNeeded()
    child.loadViewIfNeeded()

    parent.addChild(child)
    parent.view.addSubview(child.view)
    child.didMove(toParent: parent)

    parent.environmentOverrides.testInt = 1
    #expect(child.environments.testInt == 1)

    // Unload child view while keeping VC containment.
    child.view = nil
    #expect(child.isViewLoaded == false)

    parent.environmentOverrides.testInt = 2

    #expect(child.environments.testInt == TestIntEnvironment.defaultValue)
}

@MainActor
@Test func windowOverrideNotifiesUnloadedRootViewControllerRegistration() {
    let window = UIWindow()
    let rootViewController = UIViewController()
    window.rootViewController = rootViewController

    #expect(rootViewController.isViewLoaded == false)

    var changeCount = 0
    rootViewController.registerForEnvironmentChanges([TestIntEnvironment.self]) {
        changeCount += 1
    }

    window.environmentOverrides.testInt = 123

    #expect(changeCount == 1)
}

@MainActor
@Test func childViewChangeNotificationIsNotDuplicatedInViewControllerHierarchy() {
    let parent = UIViewController()
    let child = UIViewController()

    parent.loadViewIfNeeded()
    child.loadViewIfNeeded()

    parent.addChild(child)
    parent.view.addSubview(child.view)
    child.didMove(toParent: parent)

    var changeCount = 0
    child.view.registerForEnvironmentChanges([TestIntEnvironment.self]) {
        changeCount += 1
    }

    parent.environmentOverrides.testInt = 1
    #expect(changeCount == 1)

    parent.environmentOverrides.testInt = 2
    #expect(changeCount == 2)
}

@MainActor
@Test func valueInheritsFromParentThroughViewAndViewControllerHierarchy() {
    let parent = UIViewController()
    let child = UIViewController()
    let intermediateView = UIView()

    parent.loadViewIfNeeded()
    child.loadViewIfNeeded()

    parent.addChild(child)
    parent.view.addSubview(intermediateView)
    intermediateView.addSubview(child.view)
    child.didMove(toParent: parent)

    parent.environmentOverrides.testInt = 42

    #expect(parent.view.environments.testInt == 42)
    #expect(intermediateView.environments.testInt == 42)
    #expect(child.environments.testInt == 42)
    #expect(child.view.environments.testInt == 42)
}

@MainActor
@Test func childOverrideTakesPrecedenceOverParentInHierarchy() {
    let parent = UIViewController()
    let child = UIViewController()
    let intermediateView = UIView()

    parent.loadViewIfNeeded()
    child.loadViewIfNeeded()

    parent.addChild(child)
    parent.view.addSubview(intermediateView)
    intermediateView.addSubview(child.view)
    child.didMove(toParent: parent)

    parent.environmentOverrides.testInt = 1
    child.environmentOverrides.testInt = 2

    #expect(parent.view.environments.testInt == 1)
    #expect(intermediateView.environments.testInt == 1)
    #expect(child.environments.testInt == 2)
    #expect(child.view.environments.testInt == 2)
}

@MainActor
@Test func complexHierarchyResolvesNearestOverrideAcrossViewsAndViewControllers() {
    let hierarchy = makeComplexHierarchy()

    hierarchy.rootViewController.environmentOverrides.testInt = 100
    hierarchy.branchView.environmentOverrides.testInt = 200
    hierarchy.childViewController.environmentOverrides.testInt = 300
    hierarchy.deepView.environmentOverrides.testInt = 400
    hierarchy.grandChildViewController.environmentOverrides.testInt = 500
    hierarchy.siblingBranchView.environmentOverrides.testInt = 600

    #expect(hierarchy.rootViewController.view.environments.testInt == 100)
    #expect(hierarchy.rootContainerView.environments.testInt == 100)
    #expect(hierarchy.branchView.environments.testInt == 200)
    #expect(hierarchy.childViewController.view.environments.testInt == 300)
    #expect(hierarchy.deepView.environments.testInt == 400)
    #expect(hierarchy.grandChildViewController.environments.testInt == 500)
    #expect(hierarchy.grandChildViewController.view.environments.testInt == 500)
    #expect(hierarchy.siblingLeafView.environments.testInt == 600)
}

@MainActor
@Test func cacheUpdatesAcrossComplexHierarchyAfterMultipleOverrideChanges() {
    let hierarchy = makeComplexHierarchy()

    hierarchy.rootViewController.environmentOverrides.testInt = 1
    hierarchy.rootViewController.environmentOverrides.testString = "root-a"
    hierarchy.branchView.environmentOverrides.testInt = 10
    hierarchy.childViewController.environmentOverrides.testString = "child-a"
    hierarchy.deepView.environmentOverrides.testInt = 20

    _ = hierarchy.rootContainerView.environments.testInt
    _ = hierarchy.rootContainerView.environments.testString
    _ = hierarchy.childViewController.view.environments.testInt
    _ = hierarchy.childViewController.view.environments.testString
    _ = hierarchy.grandChildViewController.view.environments.testInt
    _ = hierarchy.grandChildViewController.view.environments.testString
    _ = hierarchy.siblingLeafView.environments.testInt
    _ = hierarchy.siblingLeafView.environments.testString

    hierarchy.rootViewController.environmentOverrides.testInt = 2
    hierarchy.rootViewController.environmentOverrides.testString = "root-b"
    hierarchy.branchView.environmentOverrides.testInt = 11
    hierarchy.childViewController.environmentOverrides.testString = "child-b"
    hierarchy.deepView.environmentOverrides.testInt = 21

    #expect(hierarchy.rootContainerView.environments.testInt == 2)
    #expect(hierarchy.rootContainerView.environments.testString == "root-b")
    #expect(hierarchy.childViewController.view.environments.testInt == 11)
    #expect(hierarchy.childViewController.view.environments.testString == "child-b")
    #expect(hierarchy.grandChildViewController.view.environments.testInt == 21)
    #expect(hierarchy.grandChildViewController.view.environments.testString == "child-b")
    #expect(hierarchy.siblingLeafView.environments.testInt == 2)
    #expect(hierarchy.siblingLeafView.environments.testString == "root-b")
}


@MainActor
@Test func cacheUpdatesAcrossComplexHierarchyAfterMultipleOverrideChanges2() {
    let hierarchy = makeComplexHierarchy()
    var environmentChangeCount: Int = 0

    hierarchy.childViewController.view.registerForEnvironmentChanges([TestStringEnvironment.self]) {
        environmentChangeCount += 1

        switch environmentChangeCount {
        case 1:
            #expect(hierarchy.rootViewController.environments.testString == "root-view-controller")
            #expect(hierarchy.rootViewController.view.environments.testString == "root-view-controller")
            #expect(hierarchy.rootContainerView.environments.testString == "root-view-controller")
            #expect(hierarchy.siblingBranchView.environments.testString == "root-view-controller")
            #expect(hierarchy.childViewController.environments.testString == "root-view-controller")
            #expect(hierarchy.childViewController.view.environments.testString == "root-view-controller")

        case 2:
            #expect(hierarchy.rootViewController.environments.testString == "root-view-controller")
            #expect(hierarchy.rootViewController.view.environments.testString == "root-view")
            #expect(hierarchy.rootContainerView.environments.testString == "root-view")
            #expect(hierarchy.branchView.environments.testString == "root-view")
            #expect(hierarchy.childViewController.environments.testString == "root-view")
            #expect(hierarchy.childViewController.view.environments.testString == "root-view")

//        case 3:
//            #expect(hierarchy.rootViewController.environments.testString == "root-view-controller")
//            #expect(hierarchy.rootViewController.view.environments.testString == "root-view")
//            #expect(hierarchy.rootContainerView.environments.testString == "root-view")
//            #expect(hierarchy.siblingBranchView.environments.testString == "root-view")
//            #expect(hierarchy.childViewController.environments.testString == "root-view")
//            #expect(hierarchy.childViewController.view.environments.testString == "root-view")

        default:
            break
        }
    }

    hierarchy.rootViewController.environmentOverrides.testString = "root-view-controller"
    _ = hierarchy.rootViewController.environments.testString

    hierarchy.rootViewController.view.environmentOverrides.testString = "root-view"
    _ = hierarchy.rootViewController.view.environments.testString

//    hierarchy.childViewController.environmentOverrides.testString = "child-a"
//
//    _ = hierarchy.childViewController.view.environments.testString
//
//    hierarchy.rootViewController.environmentOverrides.testString = "root-b"
//    hierarchy.childViewController.environmentOverrides.testString = "child-b"
//
//    #expect(environmentChangeCount == 4)
}
