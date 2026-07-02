import Testing
@testable import UIEnvironments
import UIKit

private struct ValuesIntEnvironment: UIEnvironmentDefinition {
    static let defaultValue = 0
}

private struct ValuesStringEnvironment: UIEnvironmentDefinition {
    static let defaultValue = "default"
}

private final class NonEquatableBox: @unchecked Sendable {
    let id: Int
    init(_ id: Int) { self.id = id }
}

private struct ValuesNonEquatableEnvironment: UIEnvironmentDefinition {
    static let defaultValue = NonEquatableBox(0)
}

@MainActor
private func makeValues(_ build: (inout UIEnvironmentOverrides) -> Void) -> UIEnvironmentValues {
    var overrides = UIEnvironmentOverrides()
    build(&overrides)
    return UIEnvironmentValues(entries: overrides.entries)
}

@MainActor
@Test func environmentValuesSubscriptReturnsSpecifiedValueOrDefault() {
    let values = makeValues { $0[ValuesIntEnvironment.self] = 42 }

    #expect(values[ValuesIntEnvironment.self] == 42)
    #expect(values[ValuesStringEnvironment.self] == "default")
}

@MainActor
@Test func environmentValuesSpecifiedDefinitionsListsSpecifiedKeys() {
    let values = makeValues {
        $0[ValuesIntEnvironment.self] = 1
        $0[ValuesStringEnvironment.self] = "x"
    }

    let identifiers = Set(values.specifiedDefinitions.map { ObjectIdentifier($0) })
    #expect(identifiers == [
        ObjectIdentifier(ValuesIntEnvironment.self),
        ObjectIdentifier(ValuesStringEnvironment.self),
    ])
}

@MainActor
@Test func environmentValuesIsEqualComparesSpecifiedValues() {
    let a = makeValues { $0[ValuesIntEnvironment.self] = 1 }
    let b = makeValues { $0[ValuesIntEnvironment.self] = 1 }
    let c = makeValues { $0[ValuesIntEnvironment.self] = 2 }
    let d = makeValues {
        $0[ValuesIntEnvironment.self] = 1
        $0[ValuesStringEnvironment.self] = "x"
    }

    #expect(a.isEqual(to: b))
    #expect(!a.isEqual(to: c))
    #expect(!a.isEqual(to: d))
}

@MainActor
@Test func environmentValuesIsEqualTreatsNonEquatableAsUnequal() {
    let box = NonEquatableBox(1)
    let a = makeValues { $0[ValuesNonEquatableEnvironment.self] = box }
    let b = makeValues { $0[ValuesNonEquatableEnvironment.self] = box }

    // Even the identical instance is reported as unequal because the value type
    // does not conform to Equatable.
    #expect(!a.isEqual(to: b))
}

@MainActor
@Test func environmentValuesChangedDefinitionsUsesEffectiveValues() {
    let base = makeValues { $0[ValuesIntEnvironment.self] = 1 }

    // Specified -> unspecified: effective value falls back to the default, which
    // differs from 1, so it counts as changed.
    let unspecified = makeValues { _ in }
    #expect(
        Set(base.changedDefinitions(from: unspecified).map { ObjectIdentifier($0) })
            == [ObjectIdentifier(ValuesIntEnvironment.self)]
    )

    // Unspecified -> specified with the default value: effective values match,
    // so nothing changed.
    let specifiedDefault = makeValues { $0[ValuesIntEnvironment.self] = ValuesIntEnvironment.defaultValue }
    #expect(specifiedDefault.changedDefinitions(from: unspecified).isEmpty)

    // Specified -> specified with a different value: changed.
    let other = makeValues { $0[ValuesIntEnvironment.self] = 2 }
    #expect(
        Set(base.changedDefinitions(from: other).map { ObjectIdentifier($0) })
            == [ObjectIdentifier(ValuesIntEnvironment.self)]
    )
}

@MainActor
@Test func environmentValuesChangedDefinitionsTreatsNonEquatableAsChanged() {
    let box = NonEquatableBox(1)
    let a = makeValues { $0[ValuesNonEquatableEnvironment.self] = box }
    let b = makeValues { $0[ValuesNonEquatableEnvironment.self] = box }

    #expect(
        Set(a.changedDefinitions(from: b).map { ObjectIdentifier($0) })
            == [ObjectIdentifier(ValuesNonEquatableEnvironment.self)]
    )
}

@MainActor
@Test func environmentValuesContainsChecksOtherIsSubset() {
    let full = makeValues {
        $0[ValuesIntEnvironment.self] = 1
        $0[ValuesStringEnvironment.self] = "x"
    }
    let subset = makeValues { $0[ValuesIntEnvironment.self] = 1 }
    let mismatched = makeValues { $0[ValuesIntEnvironment.self] = 2 }

    #expect(full.containsValues(in: subset))
    #expect(!subset.containsValues(in: full))
    #expect(!full.containsValues(in: mismatched))
}

@MainActor
@Test func environmentValuesMergingPrefersLaterCollections() {
    let first = makeValues {
        $0[ValuesIntEnvironment.self] = 1
        $0[ValuesStringEnvironment.self] = "first"
    }
    let second = makeValues { $0[ValuesStringEnvironment.self] = "second" }

    let merged = UIEnvironmentValues(valuesFrom: [first, second])

    #expect(merged[ValuesIntEnvironment.self] == 1)
    #expect(merged[ValuesStringEnvironment.self] == "second")
}
