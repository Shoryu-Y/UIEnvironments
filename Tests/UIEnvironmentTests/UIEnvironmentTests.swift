import Testing
import UIKit
@testable import UIEnvironments

private struct TestIntEnvironment: UIEnvironmentDefinition {
    static let defaultValue = 0
}

private extension UIEnvironments {
    var testInt: Int {
        self[TestIntEnvironment.self]
    }
}

private extension UIMutableEnvironments {
    var testInt: Int {
        get { self[TestIntEnvironment.self] }
        set { self[TestIntEnvironment.self] = newValue }
    }
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
