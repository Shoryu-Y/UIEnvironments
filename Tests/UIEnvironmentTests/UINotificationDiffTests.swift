import Testing
@testable import UIEnvironments
import UIKit

private struct DiffIntEnvironment: UIEnvironmentDefinition {
    static let defaultValue = 0
}

@available(iOS 17.0, *)
private struct DiffIntTrait: UITraitDefinition {
    static let defaultValue = 0
}

private final class DiffNonEquatableBox: @unchecked Sendable {
    let id: Int
    init(_ id: Int) { self.id = id }
}

private struct DiffNonEquatableEnvironment: UIEnvironmentDefinition {
    static let defaultValue = DiffNonEquatableBox(0)
}

private extension UIEnvironments {
    var diffInt: Int {
        self[DiffIntEnvironment.self]
    }
}

private extension UIMutableEnvironments {
    var diffInt: Int {
        get { self[DiffIntEnvironment.self] }
        set { self[DiffIntEnvironment.self] = newValue }
    }
}

// A window-to-window move that leaves the resolved value unchanged must not
// notify, mirroring UITraitCollection's value-difference suppression.
@MainActor
@Test func windowMoveWithUnchangedValueDoesNotNotify() {
    let firstWindow = UIWindow()
    firstWindow.environmentOverrides.diffInt = 5

    let secondWindow = UIWindow()
    secondWindow.environmentOverrides.diffInt = 5

    let view = UIView()
    firstWindow.addSubview(view)

    var changeCount = 0
    view.registerForEnvironmentChanges([DiffIntEnvironment.self]) {
        changeCount += 1
    }

    secondWindow.addSubview(view)

    #expect(view.environments.diffInt == 5)
    #expect(changeCount == 0)
}

/// Ground truth: real UIKit does not fire when a view moves between windows that
/// resolve the same trait value.
@available(iOS 17.0, *)
@MainActor
@Test func windowMoveWithUnchangedValueDoesNotNotifyInRealUIKit() {
    let firstWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
    firstWindow.traitOverrides[DiffIntTrait.self] = 5
    firstWindow.makeKeyAndVisible()

    let secondWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
    secondWindow.traitOverrides[DiffIntTrait.self] = 5
    secondWindow.makeKeyAndVisible()

    let view = UIView()
    firstWindow.addSubview(view)
    firstWindow.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))

    var changeCount = 0
    let registration = view.registerForTraitChanges([DiffIntTrait.self]) { (_: UIView, _: UITraitCollection) in
        changeCount += 1
    }
    defer { view.unregisterForTraitChanges(registration) }

    secondWindow.addSubview(view)
    secondWindow.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))

    #expect(view.traitCollection[DiffIntTrait.self] == 5)
    #expect(changeCount == 0)
}

// An explicit reparent (removeFromSuperview + addSubview) that changes the
// resolved value fires exactly once, not once per hook and not for the
// transient detached state.
@MainActor
@Test func explicitReparentChangingValueFiresExactlyOnce() {
    let window = UIWindow()
    let branch = UIView()
    let sibling = UIView()
    branch.environmentOverrides.diffInt = 1
    sibling.environmentOverrides.diffInt = 2
    window.addSubview(branch)
    window.addSubview(sibling)

    let view = UIView()
    branch.addSubview(view)

    var changeCount = 0
    view.registerForEnvironmentChanges([DiffIntEnvironment.self]) {
        changeCount += 1
    }

    view.removeFromSuperview()
    sibling.addSubview(view)

    #expect(view.environments.diffInt == 2)
    #expect(changeCount == 1)
}

// A definition whose value type is not Equatable is treated as changing on
// every re-evaluation, mirroring how UITraitCollection falls back to identity
// comparison for class-based trait values.
@MainActor
@Test func nonEquatableValueFiresOnEveryTrigger() {
    let view = UIView()

    var changeCount = 0
    view.registerForEnvironmentChanges([DiffNonEquatableEnvironment.self]) {
        changeCount += 1
    }

    let box = DiffNonEquatableBox(1)
    view.environmentOverrides[DiffNonEquatableEnvironment.self] = box
    #expect(changeCount == 1)

    // Writing the very same instance again still fires: the value cannot be
    // compared for equality, so it always counts as changed.
    view.environmentOverrides[DiffNonEquatableEnvironment.self] = box
    #expect(changeCount == 2)
}

// environmentValues merges the responder chain with the nearest override winning.
@MainActor
@Test func environmentValuesMergeResponderChainNearestWins() {
    let parent = UIView()
    let child = UIView()
    parent.addSubview(child)

    parent.environmentOverrides[DiffIntEnvironment.self] = 1
    parent.environmentOverrides[DiffNonEquatableEnvironment.self] = DiffNonEquatableBox(9)
    child.environmentOverrides[DiffIntEnvironment.self] = 2

    let resolved = child.environments.environmentValues

    // Nearest override wins for a key defined at both levels...
    #expect(resolved[DiffIntEnvironment.self] == 2)
    // ...while a key only defined higher up is still inherited.
    #expect((resolved[DiffNonEquatableEnvironment.self]).id == 9)
    #expect(
        Set(resolved.specifiedDefinitions.map { ObjectIdentifier($0) }) == [
            ObjectIdentifier(DiffIntEnvironment.self),
            ObjectIdentifier(DiffNonEquatableEnvironment.self),
        ]
    )
}

// The previous-values overload receives the values resolved before the change.
@MainActor
@Test func previousValuesOverloadReceivesPriorValues() {
    let view = UIView()

    var observedPrevious: [Int] = []
    view.registerForEnvironmentChanges([DiffIntEnvironment.self]) { (_: UIView, previousValues: UIEnvironmentValues) in
        observedPrevious.append(previousValues[DiffIntEnvironment.self])
    }

    view.environmentOverrides.diffInt = 1
    view.environmentOverrides.diffInt = 2

    #expect(observedPrevious == [DiffIntEnvironment.defaultValue, 1])
    #expect(view.environments.diffInt == 2)
}
