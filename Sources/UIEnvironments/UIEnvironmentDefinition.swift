import UIKit

public protocol UIEnvironmentDefinition: Sendable {
    associatedtype Value: Sendable

    static var defaultValue: Value { get }
}
