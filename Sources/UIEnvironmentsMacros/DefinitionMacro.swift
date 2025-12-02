import UIEnvironments
import UIKit

@attached(
    extension,
    conformances: UITraitDefinition, UIEnvironmentDefinition
)
public macro Definition() = #externalMacro(
    module: "_UIEnvironmentsMacros",
    type: "Definition"
)
