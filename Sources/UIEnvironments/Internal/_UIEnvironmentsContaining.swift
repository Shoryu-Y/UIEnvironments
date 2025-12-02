import UIKit

@MainActor
protocol _UIEnvironmentsContaining: UIResponder {
    var _environments: UIEnvironments { get }

    func _propagate(_ overrides: UIEnvironmentOverrides)
}

extension _UIEnvironmentsContaining {
    var _environmentOverrides: UIEnvironmentOverrides? {
        get { _environments.overrides }
        set {
            guard let newValue else { return }
            _environments.overrides = newValue
            _propagate(newValue)
        }
    }

    var _inheritedEnvironmentOverrides: [ObjectIdentifier: Sendable] {
        let overrides = _environmentOverrides?.storage ?? [:]

        return sequence(first: next, next: { $0?.next })
            .compactMap { next in
                let containable = next as? _UIEnvironmentsContaining
                return containable?._environmentOverrides
            }
            .reduce(overrides) { result, overrides in
                result.merging(
                    overrides.storage,
                    uniquingKeysWith: { current, _ in current }
                )
            }
    }
}
