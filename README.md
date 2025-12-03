# UIEnvironments

Backport of iOS 17’s `UITraitDefinition` / `UITraitOverrides`–style APIs  
to **iOS 13+**, with a similar developer experience.

`UIEnvironments` lets you define, override, and observe arbitrary “environment
values” flowing through your UIKit hierarchy (UIView, UIViewController, UIWindow, and UIWindowScene
scenes), just like traits.

## Motivation

`UITraitCollection` is a powerful mechanism for propagating values such as
`horizontalSizeClass` from parents to children in a UIKit hierarchy.  
Before iOS 17, it was limited to a fixed set of Apple‑defined traits, and you
could not use the same mechanism for your own app‑specific values.

In iOS 17, `UITraitDefinition` enables developers to define custom traits and
exchange them through `UITraitCollection`. However, this is only available on
devices running iOS 17 or later.

`UIEnvironments` brings a similar experience to **iOS 13 and later**, so you
can:

- Define your own environment values today.
- Use them consistently across UIView / UIViewController / UIWindow / UIWindowScene hierarchies.
- Later migrate to the native `UITraitCollection` + `UITraitDefinition` APIs
  once you drop support for iOS 16 and earlier.

## Features

| Capability                         | UITraitCollection (iOS 17+) | UIEnvironments (iOS 13+) | UITraitCollection (iOS 13+) |
| ---------------------------------- | --------------------------- | ------------------------ | ---------------------------- |
| Propagate values through UIKit     | ✅                          | ✅                       | ✅                           |
| Define custom values               | ✅                          | ✅                       | ❌                           |
| Bridge to SwiftUI `Environment`    | ✅                          | ❌                       | ❌                           |

> The feature set may grow over time as needed.

## Requirements

- iOS 13+
- Swift 5.9+

## Quick Start

### 1. Define an environment value

First, define a value type and a `UIEnvironmentDefinition` that describes how
it is stored and what its default is.

```swift
struct Theme {
    var titleFont: UIFont
    var backgroundColor: UIColor
}

struct ThemeEnvironment: UIEnvironmentDefinition {
    static let defaultValue = Theme(
        titleFont: .systemFont(ofSize: 12),
        backgroundColor: .systemBackground
    )
}

extension UIEnvironments {
    var theme: Theme {
        self[ThemeEnvironment.self]
    }
}

extension UIMutableEnvironments {
    var theme: Theme {
        get { self[ThemeEnvironment.self] }
        set { self[ThemeEnvironment.self] = newValue }
    }
}
```

### 2. Provide a value in a parent

In a parent `UIViewController`, set a value on `environmentOverrides`.  
The value is propagated down to descendants in the view / view controller
hierarchy.

```swift
final class ParentViewController: UIViewController {
    let childViewController = ChildViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        environmentOverrides.theme = Theme(
            titleFont: .systemFont(ofSize: 16),
            backgroundColor: .systemBlue
        )

        addChild(childViewController)
        childViewController.didMove(toParent: self)
        view.addSubview(childViewController.view)

        // ...
    }
}
```

### 3. Read & observe in a child

In a child `UIViewController`, you can read the current value via
`environments`. You can also call `registerForEnvironmentChanges(_:action:)`
to observe changes and update your UI accordingly.

```swift
final class ChildViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Respond when ThemeEnvironment changes.
        registerForEnvironmentChanges([ThemeEnvironment.self]) { [weak self] in
            guard let self else { return }

            view.backgroundColor = environments.theme.backgroundColor
        }

        // ...
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        // Just like UITraitCollection, it is appropriate to apply UIEnvironments in `viewIsAppearing`.
        view.backgroundColor = environments.theme.backgroundColor
    }
}
```

### Migrating to UITraitCollection (iOS 17+)

```diff
  struct Theme {
      var titleFont: UIFont
      var backgroundColor: UIColor
  }

- struct ThemeEnvironment: UIEnvironmentDefinition {
+ struct ThemeEnvironment: UITraitDefinition {
      static let defaultValue = Theme(
          titleFont: .systemFont(ofSize: 12),
          backgroundColor: .systemBackground
      )
  }

- extension UIEnvironments {
+ extension UITraitCollection {
      var theme: Theme {
          self[ThemeEnvironment.self]
      }
  }

- extension UIMutableEnvironments {
+ extension UIMutableTraits {
      var theme: Theme {
          get { self[ThemeEnvironment.self] }
          set { self[ThemeEnvironment.self] = newValue }
      }
  }
```

```diff
  final class ParentViewController: UIViewController {
      let childViewController = ChildViewController()

      override func viewDidLoad() {
          super.viewDidLoad()

-        environmentOverrides.theme = Theme(
+        traitOverrides.theme = Theme(
              titleFont: .systemFont(ofSize: 16),
              backgroundColor: .systemBlue
          )

          addChild(childViewController)
          childViewController.didMove(toParent: self)
          view.addSubview(childViewController.view)

          // ...
      }
  }
    
  final class ChildViewController: UIViewController {
      override func viewDidLoad() {
          super.viewDidLoad()

-         registerForEnvironmentChanges([ThemeEnvironment.self]) { [weak self] in
-             guard let self else { return }
-         
-             view.backgroundColor = environments.theme.backgroundColor
-         }
+         registerForTraitChanges(
+             [ThemeEnvironment.self],
+             action: #selector(handleTraitChange(view:previousTraitCollection:))
+         )

          // ...
      }

      override func viewIsAppearing(_ animated: Bool) {
          super.viewIsAppearing(animated)
          view.backgroundColor = environments.theme.backgroundColor
      }

+     @objc func handleTraitChange(view: UIView, previousTraitCollection: UITraitCollection) {
+         view.backgroundColor = environments.theme.backgroundColor
+     }
  }
```

## Example project

This repository includes a sample app, `UIEnvironmentExample`, which combines
UIKit and SwiftUI.  
It demonstrates how environment values are propagated and overridden across
multiple view hierarchies—build and run it to see the behavior in action.
