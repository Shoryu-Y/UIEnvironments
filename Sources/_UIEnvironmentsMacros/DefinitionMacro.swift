import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct Definition: ExtensionMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDeclSyntax = declaration.as(StructDeclSyntax.self) else {
            context.addDiagnostics(
                from: MessageError(description: "error"),
                node: declaration
            )
            return []
        }

        guard let member = structDeclSyntax.memberBlock.members.first(where: { item in
            guard let decl = item.decl.as(VariableDeclSyntax.self) else {
                return false
            }

            guard decl.modifiers.contains(where:{
                $0.name.text == "static"
            }) else {
                return false
            }

            return decl.bindings.contains(where: {
                $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "defaultValue"
            })
        }) else {
            return []
        }

        let declSyntax: DeclSyntax =
          """
          extension \(type.trimmed): UIEnvironmentDefinition {}
          
          @available(iOS 17.0, *)
          extension \(type.trimmed): UITraitDefinition {}
          """

        guard let extensionDecl = declSyntax.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [
            extensionDecl
        ]
    }
    
    static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDeclSyntax = declaration.as(StructDeclSyntax.self) else {
            context.addDiagnostics(
                from: MessageError(description: "error"),
                node: declaration
            )
            return []
        }

        guard let member = structDeclSyntax.memberBlock.members.first(where: { item in
            guard let decl = item.decl.as(VariableDeclSyntax.self) else {
                return false
            }

            guard decl.modifiers.contains(where:{
                $0.name.text == "static"
            }) else {
                return false
            }

            return decl.bindings.contains(where: {
                $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "defaultValue"
            })
        }) else {
            return []
        }

        let debug = structDeclSyntax.memberBlock.members.first?.decl.as(VariableDeclSyntax.self)?.modifiers.first

        return [
            """
            extension \(structDeclSyntax.name) {
            }
            """
        ]
    }
}

struct MessageError: Error, CustomStringConvertible {
    var description: String
}
