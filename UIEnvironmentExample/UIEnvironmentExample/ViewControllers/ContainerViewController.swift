import SwiftUI
import UIEnvironments
import UIKit

struct RootView: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> some UIViewController {
        UINavigationController(rootViewController: ContainerViewController())
    }

    func updateUIViewController(_: UIViewControllerType, context _: Context) {}
}

final class ContainerViewController: UIViewController {
    let childViewController1 = ChildViewController1()
    let childViewController2 = ChildViewController2()

    // Themes cycled through on tap to drive the change-notification demo.
    private let cycledThemes: [Theme] = [.blue, .mint, .orange]
    private var cycledThemeIndex = 0

    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Tap to change theme"
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        environmentOverrides.theme = .blue
        view.backgroundColor = environments.theme.backgroundColor
        view.window?.environmentOverrides.theme = .mint

        addChild(childViewController1)
        childViewController1.didMove(toParent: self)

        addChild(childViewController2)
        childViewController2.didMove(toParent: self)

        childViewController1.view.translatesAutoresizingMaskIntoConstraints = false
        childViewController1.view.environmentOverrides.theme = .orange

        childViewController2.view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(childViewController1.view)
        childViewController1.view.addSubview(childViewController2.view)
        childViewController2.view.addSubview(label)

        NSLayoutConstraint.activate([
            childViewController1.view.topAnchor.constraint(equalTo: view.topAnchor),
            childViewController1.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childViewController1.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childViewController1.view.heightAnchor.constraint(equalToConstant: 200),

            childViewController2.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childViewController2.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childViewController2.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            childViewController2.view.heightAnchor.constraint(equalToConstant: 200),

            label.centerXAnchor.constraint(equalTo: childViewController2.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: childViewController2.view.centerYAnchor),
        ])

        // Tapping cycles the override nearest to childViewController2, so its
        // registered change observer (see ChildViewController2) fires.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cycleChildTheme))
        view.addGestureRecognizer(tapGesture)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @objc private func cycleChildTheme() {
        cycledThemeIndex = (cycledThemeIndex + 1) % cycledThemes.count
        childViewController2.view.environmentOverrides.theme = cycledThemes[cycledThemeIndex]
    }
}

final class ChildViewController1: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewIsAppearing(_: Bool) {
        view.backgroundColor = environments.theme.backgroundColor
    }
}

final class ChildViewController2: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Observe Theme changes with the notification API. The callback hands
        // back the environment whose values changed, mirroring how
        // registerForTraitChanges hands back the object; read the new value
        // from it. The registration lives as long as this view controller, so
        // there is no need to unregister it manually.
        registerForEnvironmentChanges([ThemeEnvironment.self]) { environment in
            let currentTheme = environment.environments.theme
            environment.view.backgroundColor = currentTheme.backgroundColor
            print("Theme changed to \(currentTheme.name)")
        }
    }

    override func viewIsAppearing(_: Bool) {
        view.backgroundColor = environments.theme.backgroundColor
    }
}
