import Testing
@testable import UIEnvironments
import UIKit

private struct TestFallbackEnvironment: UIEnvironmentDefinition {
    static let defaultValue = 0
}

@available(iOS 17.0, *)
private struct TestStringTrait: UITraitDefinition {
    static let defaultValue = "default"
}

@available(iOS 17.0, *)
private struct TestBridgedStringEnvironment: UIEnvironmentDefinition, UITraitDefinition {
    static let defaultValue = "default"
}

@MainActor
@Test func traitCollectionCanBeReadWithoutLoadingView() {
    let viewController = UIViewController()
    #expect(viewController.isViewLoaded == false)

    _ = viewController.traitCollection

    #expect(viewController.isViewLoaded == false)
}

@MainActor
@Test func childTraitOverrideWorksWithoutLoadingChildView() {
    let parent = UIViewController()
    let child = UIViewController()

    parent.addChild(child)
    child.didMove(toParent: parent)

    #expect(child.isViewLoaded == false)

    parent.setOverrideTraitCollection(
        UITraitCollection(horizontalSizeClass: .compact),
        forChild: child
    )

    #expect(child.traitCollection.horizontalSizeClass == .compact)
    #expect(child.isViewLoaded == false)
}

@available(iOS 17.0, *)
@MainActor @Test func detachedChildTraitCanRemainUnspecifiedAfterParentTraitOverrideChanges() {
    let parent = UIViewController()
    let child = UIViewController()

    parent.addChild(child)
    child.didMove(toParent: parent)

    parent.traitOverrides.horizontalSizeClass = .compact
    #expect(parent.traitCollection.horizontalSizeClass == .compact)
    #expect(child.traitCollection.horizontalSizeClass == .unspecified)

    parent.traitOverrides.horizontalSizeClass = .regular

    #expect(child.traitCollection.horizontalSizeClass == .unspecified)
    #expect(child.isViewLoaded == false)
}

@MainActor
@Test func traitCollection_unloadedChildViewControllerReflectsLatestOverride() {
    let parent = UIViewController()
    let child = UIViewController()

    parent.loadViewIfNeeded()
    child.loadViewIfNeeded()

    parent.addChild(child)
    parent.view.addSubview(child.view)
    child.didMove(toParent: parent)

    parent.setOverrideTraitCollection(
        UITraitCollection(horizontalSizeClass: .compact),
        forChild: child
    )
    #expect(child.traitCollection.horizontalSizeClass == .compact)

    child.view = nil
    #expect(child.isViewLoaded == false)

    parent.setOverrideTraitCollection(
        UITraitCollection(horizontalSizeClass: .regular),
        forChild: child
    )

    #expect(child.traitCollection.horizontalSizeClass == .regular)
}

@available(iOS 17.0, *)
@MainActor
@Test func traitDefinition_unloadedChildViewControllerUsesDefaultWithoutResolvedContext() {
    let parent = UIViewController()
    let child = UIViewController()

    parent.loadViewIfNeeded()
    child.loadViewIfNeeded()

    parent.addChild(child)
    parent.view.addSubview(child.view)
    child.didMove(toParent: parent)

    parent.traitOverrides[TestStringTrait.self] = "v1"
    #expect(child.traitCollection[TestStringTrait.self] == TestStringTrait.defaultValue)

    child.view = nil
    #expect(child.isViewLoaded == false)

    parent.traitOverrides[TestStringTrait.self] = "v2"

    #expect(child.traitCollection[TestStringTrait.self] == TestStringTrait.defaultValue)
}

@available(iOS 17.0, *)
@MainActor
@Test func environmentOverrideWriteSyncsToNativeTraitOverrides() {
    let view = UIView()

    view.environmentOverrides[TestBridgedStringEnvironment.self] = "from-environment"

    if UIEnvironments.isNativeTraitBridgeEnabled {
        #expect(view.traitOverrides[TestBridgedStringEnvironment.self] == "from-environment")
    } else {
        // In the fallback path the environment write is not mirrored into the
        // native trait overrides. Reading `traitOverrides` for an unset trait
        // traps, so assert the absence via `contains` instead of reading it.
        #expect(view.traitOverrides.contains(TestBridgedStringEnvironment.self) == false)
    }

    #expect(view.environments[TestBridgedStringEnvironment.self] == "from-environment")
}

@available(iOS 17.0, *)
@MainActor
@Test func environmentsReadPrefersNativeTraitCollectionForBridgedDefinitions() {
    let view = UIView()

    view.traitOverrides[TestBridgedStringEnvironment.self] = "initial"
    if UIEnvironments.isNativeTraitBridgeEnabled {
        #expect(view.environments[TestBridgedStringEnvironment.self] == "initial")
    } else {
        #expect(view.environments[TestBridgedStringEnvironment.self] == TestBridgedStringEnvironment.defaultValue)
    }

    view.traitOverrides[TestBridgedStringEnvironment.self] = "native-updated"
    if UIEnvironments.isNativeTraitBridgeEnabled {
        #expect(view.environments[TestBridgedStringEnvironment.self] == "native-updated")
    } else {
        #expect(view.environments[TestBridgedStringEnvironment.self] == TestBridgedStringEnvironment.defaultValue)
    }
}

@MainActor
@Test func environmentOverridesContainsReflectsExplicitSpecification() {
    var overrides = UIEnvironmentOverrides()
    #expect(overrides.contains(TestFallbackEnvironment.self) == false)

    overrides[TestFallbackEnvironment.self] = 42
    #expect(overrides.contains(TestFallbackEnvironment.self))

    // Assigning the default value still counts as an explicit override.
    overrides[TestFallbackEnvironment.self] = TestFallbackEnvironment.defaultValue
    #expect(overrides.contains(TestFallbackEnvironment.self))

    overrides.remove(TestFallbackEnvironment.self)
    #expect(overrides.contains(TestFallbackEnvironment.self) == false)
    // After removal the definition resolves to its default again.
    #expect(overrides[TestFallbackEnvironment.self] == TestFallbackEnvironment.defaultValue)
}

@available(iOS 17.0, *)
@MainActor
@Test func environmentOverrideRemoveClearsResolutionAndNativeTrait() {
    let view = UIView()
    view.environmentOverrides[TestBridgedStringEnvironment.self] = "set"
    #expect(view.environments[TestBridgedStringEnvironment.self] == "set")

    view.environmentOverrides.remove(TestBridgedStringEnvironment.self)

    #expect(view.environmentOverrides.contains(TestBridgedStringEnvironment.self) == false)
    #expect(view.environments[TestBridgedStringEnvironment.self] == TestBridgedStringEnvironment.defaultValue)
    // The removal is mirrored out of the native trait overrides as well.
    #expect(view.traitOverrides.contains(TestBridgedStringEnvironment.self) == false)
}

@available(iOS 17.0, *)
@MainActor
@Test func registerForEnvironmentChangesCanRegisterAndUnregisterBridgedDefinitions() {
    let view = UIView()

    let registration = view.registerForEnvironmentChanges([TestBridgedStringEnvironment.self]) {}
    view.unregisterFromEnvironmentChanges(registration)
}

@available(iOS 17.0, *)
@MainActor
@Test func registerForEnvironmentChangesReportsPreviousValueForBridgedDefinition() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
    let view = UIView()
    window.addSubview(view)
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))

    var observedPrevious: [String] = []
    view.registerForEnvironmentChanges([TestBridgedStringEnvironment.self]) { _, previousEnvironments in
        observedPrevious.append(previousEnvironments[TestBridgedStringEnvironment.self])
    }

    if UIEnvironments.isNativeTraitBridgeEnabled {
        view.traitOverrides[TestBridgedStringEnvironment.self] = "first"
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        view.traitOverrides[TestBridgedStringEnvironment.self] = "second"
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        #expect(observedPrevious == [TestBridgedStringEnvironment.defaultValue, "first"])
    } else {
        view.environmentOverrides[TestBridgedStringEnvironment.self] = "first"
        view.environmentOverrides[TestBridgedStringEnvironment.self] = "second"

        #expect(observedPrevious == [TestBridgedStringEnvironment.defaultValue, "first"])
    }
}

@available(iOS 17.0, *)
@MainActor
@Test func mixedNativeAndFallbackDefinitionsDoNotDuplicateCallbacks() {
    let view = UIView()
    var changeCount = 0

    _ = view.registerForEnvironmentChanges(
        [TestBridgedStringEnvironment.self, TestFallbackEnvironment.self]
    ) {
        changeCount += 1
    }

    view.traitOverrides[TestBridgedStringEnvironment.self] = "native"
    #expect(changeCount == 0)

    view.environmentOverrides[TestFallbackEnvironment.self] = 1
    #expect(changeCount == 1)
}
