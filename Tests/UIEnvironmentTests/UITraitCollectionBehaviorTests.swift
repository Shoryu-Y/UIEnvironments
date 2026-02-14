import Testing
import UIKit

@available(iOS 17.0, *)
private struct TestStringTrait: UITraitDefinition {
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
