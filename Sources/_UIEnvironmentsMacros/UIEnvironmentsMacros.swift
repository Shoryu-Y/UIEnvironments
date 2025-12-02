import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct UIEnvironmentsMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        Definition.self,
    ]
}
