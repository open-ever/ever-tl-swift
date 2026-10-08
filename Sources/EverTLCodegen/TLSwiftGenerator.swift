import Foundation

public struct TLGeneratorConfiguration: Codable, Equatable, Sendable {
    public var excludeTypes: Set<String>
    public var needBox: Set<String>
    public var needDeterminer: Set<String>
    public var replaceWithBytes: Set<String>
    public var additionalDerives: [String: [String]]
    public var moduleName: String

    public init(
        excludeTypes: Set<String> = [],
        needBox: Set<String> = [],
        needDeterminer: Set<String> = [],
        replaceWithBytes: Set<String> = [],
        additionalDerives: [String: [String]] = [:],
        moduleName: String = "EverTL"
    ) {
        self.excludeTypes = excludeTypes
        self.needBox = needBox
        self.needDeterminer = needDeterminer
        self.replaceWithBytes = replaceWithBytes
        self.additionalDerives = additionalDerives
        self.moduleName = moduleName
    }

    private enum CodingKeys: String, CodingKey {
        case excludeTypes = "exclude_types"
        case needBox = "need_box"
        case needDeterminer = "need_determiner"
        case replaceWithBytes = "replace_with_bytes"
        case additionalDerives = "additional_derives"
        case moduleName = "module_name"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        excludeTypes = try container.decodeIfPresent(Set<String>.self, forKey: .excludeTypes) ?? []
        needBox = try container.decodeIfPresent(Set<String>.self, forKey: .needBox) ?? []
        needDeterminer = try container.decodeIfPresent(Set<String>.self, forKey: .needDeterminer) ?? []
        replaceWithBytes = try container.decodeIfPresent(Set<String>.self, forKey: .replaceWithBytes) ?? []
        additionalDerives = try container.decodeIfPresent([String: [String]].self, forKey: .additionalDerives) ?? [:]
        moduleName = try container.decodeIfPresent(String.self, forKey: .moduleName) ?? "EverTL"
    }
}

public enum TLGeneratorError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidConfiguration(String)
    case conflictingConstructor(String)
    case constructorIDCollision(UInt32, String, String)
    case swiftNameCollision(String, String, String)
    case unsupported(String)
    case unknownType(String)
    case invalidFlags(String)

    public var description: String {
        switch self {
        case .invalidConfiguration(let message): return "Invalid generator configuration: \(message)"
        case .conflictingConstructor(let name): return "Conflicting declarations for TL constructor \(name)"
        case .constructorIDCollision(let id, let first, let second):
            return "Constructor ID \(String(format: "%08x", id)) is shared by \(first) and \(second)"
        case .swiftNameCollision(let name, let first, let second):
            return "Swift name \(name) is shared by \(first) and \(second)"
        case .unsupported(let message): return "Unsupported TL declaration: \(message)"
        case .unknownType(let message): return "Unknown TL type: \(message)"
        case .invalidFlags(let message): return "Invalid TL flags: \(message)"
        }
    }
}

public enum TLSwiftGenerator {
    public static func generate(
        schema: TLSchema,
        configuration: TLGeneratorConfiguration = .init()
    ) throws -> String {
        var generator = Generator(schema: schema, configuration: configuration)
        return try generator.generate()
    }
}

private struct Generator {
    let schema: TLSchema
    let configuration: TLGeneratorConfiguration
    var constructors: [TLConstructor] = []
    var byName: [String: [TLConstructor]] = [:]
    var results: [String: [TLConstructor]] = [:]
    var resultNames: [String: String] = [:]
    var constructorNames: [UInt32: String] = [:]

    private static let builtins: Set<String> = [
        "int", "int32", "int53", "int64", "int128", "int256", "int512", "long", "double",
        "bytes", "vector", "string", "object", "function", "Object", "Function",
        "secureString", "secureBytes", "true", "false", "boolTrue", "boolFalse"
    ]

    private static let reservedNames: Set<String> = [
        "EverTLSchema", "TLReader", "TLWriter", "TLRegistry", "TLObject", "TLSerializable", "TLBoxedSerializable", "TLConstructor",
        "TLFunction", "TLCodecError", "TLBytes128", "TLBytes256", "TLBytes512", "TLTrue", "TLLengthPrefixed",
        "TLBareVector", "TLBoxedVector", "Swift", "Foundation", "Sendable", "Equatable", "Self", "Any"
    ]

    init(schema: TLSchema, configuration: TLGeneratorConfiguration) {
        self.schema = schema
        self.configuration = configuration
    }

    mutating func generate() throws -> String {
        try validateConfiguration()
        try collectConstructors()
        allocateNames()
        try validateNames()
        try validateBareRecursion()
        var chunks = ["// Generated from a TL schema. Do not edit manually.", "import Foundation", "import \(configuration.moduleName)"]
        for constructor in constructors {
            chunks.append(try generateConstructor(constructor))
        }
        for result in results.keys.sorted() {
            chunks.append(try generateResult(result, variants: results[result]!))
        }
        chunks.append(try generateRegistry())
        return chunks.joined(separator: "\n\n") + "\n"
    }

    private func validateConfiguration() throws {
        guard isIdentifier(configuration.moduleName) else {
            throw TLGeneratorError.invalidConfiguration("module_name must be a Swift module identifier")
        }
        let unsupportedDeterminers = configuration.needDeterminer.subtracting(["vector", "Vector"])
        guard unsupportedDeterminers.isEmpty else {
            throw TLGeneratorError.invalidConfiguration("need_determiner supports only vector and Vector: \(unsupportedDeterminers.sorted().joined(separator: ", "))")
        }
        let derives = configuration.additionalDerives.filter { !$0.value.isEmpty }
        guard derives.isEmpty else {
            throw TLGeneratorError.invalidConfiguration("additional_derives contains Rust traits; generated Swift types already conform to Equatable and Sendable")
        }
    }

    private mutating func collectConstructors() throws {
        var ids: [UInt32: String] = [:]
        for constructor in schema.constructors {
            guard !Self.builtins.contains(constructor.name), !configuration.excludeTypes.contains(constructor.name) else { continue }
            if let existing = byName[constructor.name]?.first(where: { $0.result == constructor.result }) {
                guard existing.id == constructor.id,
                      existing.typeParameters == constructor.typeParameters,
                      existing.fields == constructor.fields,
                      existing.result == constructor.result,
                      existing.isFunction == constructor.isFunction else {
                    throw TLGeneratorError.conflictingConstructor(constructor.name)
                }
                continue
            }
            if let existing = ids[constructor.id] {
                throw TLGeneratorError.constructorIDCollision(constructor.id, existing, constructor.name)
            }
            byName[constructor.name, default: []].append(constructor)
            ids[constructor.id] = constructor.name
            if !constructor.isFunction {
                guard case .named(let result) = constructor.result else {
                    throw TLGeneratorError.unsupported("\(constructor.name): generic constructor results are not supported")
                }
                guard result != "Bool", result != "True", result != "Object", result != "Function" else {
                    throw TLGeneratorError.unsupported("\(constructor.name): custom constructors for builtin \(result) are not supported")
                }
                results[normalizedResultIdentity(result), default: []].append(constructor)
            }
        }
        constructors = byName.values.flatMap { $0 }.sorted {
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.result.schemaName < $1.result.schemaName
        }
        for key in results.keys { results[key]!.sort { $0.name < $1.name } }
    }

    private mutating func allocateNames() {
        let resultGroups = Dictionary(grouping: results.keys, by: pascalCase)
        for (base, keys) in resultGroups {
            for key in keys { resultNames[key] = keys.count == 1 ? base : structuredName(key) }
        }
        let constructorGroups = Dictionary(grouping: constructors, by: { baseConstructorName($0, structured: false) })
        for (base, declarations) in constructorGroups {
            for declaration in declarations {
                constructorNames[declaration.id] = declarations.count == 1 ? base : baseConstructorName(declaration, structured: true)
            }
        }
    }

    private func validateNames() throws {
        var names = Dictionary(uniqueKeysWithValues: Self.reservedNames.map { ($0, "reserved type \($0)") })
        for constructor in constructors {
            let name = constructorName(constructor)
            if let existing = names[name] {
                throw TLGeneratorError.swiftNameCollision(name, existing, constructor.name)
            }
            names[name] = constructor.name
        }
        for result in results.keys.sorted() {
            let name = resultNames[result]!
            guard isIdentifier(name) else { throw TLGeneratorError.unsupported("invalid Swift result name for \(result)") }
            if let existing = names[name] {
                throw TLGeneratorError.swiftNameCollision(name, existing, result)
            }
            names[name] = result
        }
    }

    private func validateBareRecursion() throws {
        var graph: [UInt32: [UInt32]] = [:]
        func bareName(_ type: TLType) -> String? {
            switch type {
            case .named(let name): return name
            case .flagged(_, _, let inner): return bareName(inner)
            default: return nil
            }
        }
        for constructor in constructors {
            graph[constructor.id] = constructor.fields.compactMap { field in
                guard let name = bareName(field.type), let variants = byName[name], variants.count == 1,
                      !variants[0].isFunction else { return nil }
                return variants[0].id
            }
        }
        var visited: Set<UInt32> = []
        var active: Set<UInt32> = []
        func visit(_ id: UInt32) throws {
            guard !active.contains(id) else {
                let name = constructors.first { $0.id == id }!.name
                throw TLGeneratorError.unsupported("\(name): recursive bare value types require a boxed result reference or a vector")
            }
            guard !visited.contains(id) else { return }
            active.insert(id)
            for child in graph[id] ?? [] { try visit(child) }
            active.remove(id)
            visited.insert(id)
        }
        for constructor in constructors { try visit(constructor.id) }
    }

    private func generateConstructor(_ constructor: TLConstructor) throws -> String {
        let genericParameters = try genericParameters(constructor)
        let fields = try resolvedFields(constructor, generics: genericParameters)
        let masks = try flagMasks(constructor, fields: fields)
        let name = constructorName(constructor)
        let generics = genericParameters.isEmpty ? "" : "<" + genericParameters.map { "\($0.swift): TLFunction" }.joined(separator: ", ") + ">"
        let conformances = constructor.isFunction ? "TLConstructor, TLFunction" : "TLConstructor"
        let equality = genericParameters.isEmpty ? ", Equatable" : ""
        var lines = ["public struct \(name)\(generics): \(conformances)\(equality), Sendable {"]
        lines.append("    public static var constructorID: Swift.UInt32 { 0x\(hex(constructor.id)) }")
        if constructor.isFunction {
            let reply = try resolvedReply(constructor, generics: genericParameters)
            lines.append("    public typealias Reply = \(reply.type)")
            lines.append("    public static var replyBoxed: Swift.Bool { \(reply.boxed) }")
        }
        for field in fields { lines.append("    public var \(field.identifier): \(field.swiftType)") }
        lines.append("")
        let parameters = fields.map { field in
            let defaultValue: String
            if field.flag != nil { defaultValue = field.isFlaggedTrue ? " = false" : " = nil" }
            else if masks[field.index] != nil { defaultValue = " = 0" }
            else { defaultValue = "" }
            return "\(field.identifier) _tlArgument\(field.index): \(field.swiftType)\(defaultValue)"
        }.joined(separator: ", ")
        lines.append("    public init(\(parameters)) {")
        for field in fields { lines.append("        self.\(field.identifier) = _tlArgument\(field.index)") }
        lines.append("    }")
        lines.append("")
        lines.append("    public static func readBare(from reader: inout TLReader) throws -> Self {")
        for field in fields {
            if let flag = field.flag {
                let maskIndex = fields.first { $0.originalName == flag.mask }!.index
                let mask = masks[maskIndex]!
                let condition = "(\(mask.unsignedExpression("_tlField\(maskIndex)")) & (\(mask.unsignedType)(1) << \(flag.bit))) != 0"
                if field.isFlaggedTrue {
                    lines.append("        let _tlField\(field.index) = \(condition)")
                } else {
                    lines.append("        let _tlField\(field.index): \(field.swiftType) = \(condition) ? \(field.resolved.readExpression) : nil")
                }
            } else {
                lines.append("        let _tlField\(field.index) = \(field.resolved.readExpression)")
            }
        }
        let arguments = fields.map {
            let label = $0.originalName == "_" ? $0.identifier : $0.originalName
            return "\(label): _tlField\($0.index)"
        }.joined(separator: ", ")
        lines.append("        return Self(\(arguments))")
        lines.append("    }")
        lines.append("")
        lines.append("    public func writeBare(to writer: inout TLWriter) throws {")
        for index in masks.keys.sorted() {
            let field = fields[index]
            let mask = masks[index]!
            lines.append("        var _tlMask\(index) = \(mask.unsignedExpression("self.\(field.identifier)"))")
            let flags = fields.filter { $0.flag?.mask == field.originalName }
            for bit in Set(flags.map { $0.flag!.bit }).sorted() {
                let controlled = flags.filter { $0.flag!.bit == bit }
                let first = controlled[0].presenceExpression
                for sibling in controlled.dropFirst() {
                    lines.append("        guard (\(first)) == (\(sibling.presenceExpression)) else {")
                    lines.append("            throw TLCodecError.inconsistentFlags(\(literal("\(constructor.name): \(field.originalName).\(bit) requires \(controlled.map(\.originalName).joined(separator: ", ")) to be present together")))")
                    lines.append("        }")
                }
                let bitExpression = "(\(mask.unsignedType)(1) << \(bit))"
                lines.append("        if \(first) { _tlMask\(index) |= \(bitExpression) } else { _tlMask\(index) &= ~\(bitExpression) }")
            }
        }
        for field in fields {
            if let mask = masks[field.index] {
                lines.append("        try writer.write(\(mask.storedExpression("_tlMask\(field.index)")), boxed: false)")
            } else if field.isFlaggedTrue {
                continue
            } else if field.flag != nil {
                lines.append("        if let _tlValue\(field.index) = self.\(field.identifier) {")
                lines.append("            \(field.resolved.writeExpression("_tlValue\(field.index)"))")
                lines.append("        }")
            } else {
                lines.append("        \(field.resolved.writeExpression("self.\(field.identifier)"))")
            }
        }
        lines.append("    }")
        lines.append("}")
        if !genericParameters.isEmpty {
            lines.append("")
            lines.append("extension \(name): Equatable where " + genericParameters.map { "\($0.swift): Equatable" }.joined(separator: ", ") + " {}")
        }
        return lines.joined(separator: "\n")
    }

    private func generateResult(_ result: String, variants: [TLConstructor]) throws -> String {
        let name = resultNames[result]!
        var caseNames: Set<String> = []
        var lines = ["public indirect enum \(name): TLBoxedSerializable, Equatable, Sendable {"]
        for variant in variants {
            let caseName = caseIdentifier(variant.name)
            guard caseNames.insert(caseName).inserted else {
                throw TLGeneratorError.swiftNameCollision(caseName, result, variant.name)
            }
            lines.append("    case \(caseName)(\(constructorName(variant)))")
        }
        lines.append("")
        lines.append("    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {")
        lines.append("        guard boxed else { throw TLCodecError.unsupported(\(literal("\(result) requires a constructor identifier"))) }")
        lines.append("        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)")
        lines.append("        switch _tlID {")
        for variant in variants {
            lines.append("        case 0x\(hex(variant.id)): return .\(caseIdentifier(variant.name))(try \(constructorName(variant)).readBare(from: &reader))")
        }
        lines.append("        default: throw TLCodecError.unknownConstructor(_tlID)")
        lines.append("        }")
        lines.append("    }")
        lines.append("")
        lines.append("    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {")
        lines.append("        guard boxed else { throw TLCodecError.unsupported(\(literal("\(result) requires a constructor identifier"))) }")
        lines.append("        switch self {")
        for variant in variants {
            lines.append("        case .\(caseIdentifier(variant.name))(let _tlValue): try _tlValue.write(to: &writer, boxed: true)")
        }
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private func generateRegistry() throws -> String {
        var lines = ["public enum EverTLSchema {"]
        lines.append("    public static let layer: Swift.UInt32? = \(schema.layer.map(String.init) ?? "nil")")
        lines.append("    public static let constructorCount: Swift.Int = \(constructors.count)")
        lines.append("    public static func makeRegistry() throws -> TLRegistry {")
        lines.append("        var registry = TLRegistry()")
        for constructor in constructors {
            let parameters = try genericParameters(constructor)
            let specialization = parameters.isEmpty ? "" : "<" + parameters.map { _ in "TLObject" }.joined(separator: ", ") + ">"
            let registryName = (byName[constructor.name]?.count ?? 0) > 1 ? "\(constructor.name) as \(constructor.result.schemaName)" : constructor.name
            lines.append("        try registry.register(\(constructorName(constructor))\(specialization).self, id: 0x\(hex(constructor.id)), name: \(literal(registryName)))")
        }
        lines.append("        return registry")
        lines.append("    }")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private struct GenericParameter {
        let original: String
        let swift: String
    }

    private func genericParameters(_ constructor: TLConstructor) throws -> [GenericParameter] {
        guard constructor.typeParameters.isEmpty || constructor.isFunction else {
            throw TLGeneratorError.unsupported("\(constructor.name): generic data constructors are not supported; only RPC query type parameters are supported")
        }
        var names: Set<String> = []
        return try constructor.typeParameters.map { parameter in
            guard let name = parameter.name, parameter.type == .named("Type") else {
                throw TLGeneratorError.unsupported("\(constructor.name): type parameters must have the form {X:Type}")
            }
            let swift = pascalCase(name)
            guard isIdentifier(swift), !Self.reservedNames.contains(swift) else {
                throw TLGeneratorError.unsupported("\(constructor.name): type parameter \(name) conflicts with a reserved Swift name")
            }
            guard names.insert(swift).inserted else {
                throw TLGeneratorError.swiftNameCollision(swift, constructor.name, name)
            }
            guard constructor.fields.contains(where: { referencesParameter($0.type, name: name) }) else {
                throw TLGeneratorError.unsupported("\(constructor.name): unused type parameter \(name)")
            }
            return GenericParameter(original: name, swift: swift)
        }
    }

    private func referencesParameter(_ type: TLType, name: String) -> Bool {
        switch type {
        case .typeParameter(let value): return value == name
        case .generic(_, let inner), .flagged(_, _, let inner): return referencesParameter(inner, name: name)
        default: return false
        }
    }

    private func resolvedReply(_ constructor: TLConstructor, generics: [GenericParameter]) throws -> (type: String, boxed: String) {
        switch constructor.result {
        case .named(let name), .typeParameter(let name):
            if let generic = generics.first(where: { $0.original == name }) {
                return ("\(generic.swift).Reply", "\(generic.swift).replyBoxed")
            }
        default: break
        }
        let resolved = try resolve(constructor.result, constructor: constructor, generics: generics)
        return (resolved.serialType, String(resolved.boxed))
    }

    private indirect enum ResolvedType {
        case value(String, Bool)
        case vector(ResolvedType, Bool)

        var swiftType: String {
            switch self {
            case .value(let type, _): return type
            case .vector(let element, _): return "[\(element.serialType)]"
            }
        }

        var serialType: String {
            switch self {
            case .value(let type, _): return type
            case .vector(let element, _):
                return "\(element.boxed ? "TLBoxedVector" : "TLBareVector")<\(element.serialType)>"
            }
        }

        var boxed: Bool {
            switch self {
            case .value(_, let value), .vector(_, let value): return value
            }
        }

        var readExpression: String {
            switch self {
            case .value(let type, let boxed): return "try reader.read(\(type).self, boxed: \(boxed))"
            case .vector(let element, _): return "try reader.readVector(\(element.serialType).self, elementBoxed: \(element.boxed))"
            }
        }

        func writeExpression(_ value: String) -> String {
            switch self {
            case .value(_, let boxed): return "try writer.write(\(value), boxed: \(boxed))"
            case .vector(let element, _): return "try writer.writeVector(\(value), elementBoxed: \(element.boxed))"
            }
        }
    }

    private func resolve(_ type: TLType, constructor: TLConstructor, generics: [GenericParameter]) throws -> ResolvedType {
        switch type {
        case .number: return .value("Swift.UInt32", false)
        case .named(let name):
            let primitives: [String: String] = [
                "int": "Swift.Int32", "int32": "Swift.Int32", "Int": "Swift.Int32", "Int32": "Swift.Int32",
                "int53": "Swift.Int64", "int64": "Swift.Int64", "long": "Swift.Int64", "Int53": "Swift.Int64", "Int64": "Swift.Int64", "Long": "Swift.Int64",
                "byte": "Swift.UInt8", "uint8": "Swift.UInt8", "uint": "Swift.UInt32", "uint32": "Swift.UInt32",
                "ulong": "Swift.UInt64", "uint64": "Swift.UInt64", "flags": "Swift.UInt32", "Flags": "Swift.UInt32",
                "double": "Swift.Double", "Double": "Swift.Double", "bytes": "Foundation.Data", "Bytes": "Foundation.Data",
                "string": "Swift.String", "String": "Swift.String", "secureString": "Foundation.Data", "secureBytes": "Foundation.Data",
                "SecureString": "Foundation.Data", "SecureBytes": "Foundation.Data", "int128": "TLBytes128", "Int128": "TLBytes128",
                "int256": "TLBytes256", "Int256": "TLBytes256", "int512": "TLBytes512", "Int512": "TLBytes512",
                "Bool": "Swift.Bool", "true": "TLTrue", "True": "Swift.Bool"
            ]
            if let primitive = primitives[name] {
                return .value(primitive, name == "Bool" || name == "True")
            }
            if ["object", "Object", "function", "Function", "TypedObject"].contains(name) { return .value("TLObject", true) }
            if name == "lengthPrefixedTypedObject" { return .value("TLLengthPrefixed<TLObject>", false) }
            if let candidates = byName[name], !candidates.contains(where: { $0.isFunction }) {
                guard candidates.count == 1 else {
                    throw TLGeneratorError.unsupported("\(constructor.name): bare type \(name) is ambiguous between \(candidates.map { $0.result.schemaName }.sorted().joined(separator: ", "))")
                }
                let boxed = name.split(separator: ".").last?.first?.isUppercase == true
                return .value(constructorName(candidates[0]), boxed)
            }
            if let resolvedName = resultNames[normalizedResultIdentity(name)] { return .value(resolvedName, true) }
            throw TLGeneratorError.unknownType("\(name) in \(constructor.name)")
        case .typeParameter(let name):
            guard let parameter = generics.first(where: { $0.original == name }) else {
                throw TLGeneratorError.unknownType("type parameter !\(name) in \(constructor.name)")
            }
            return .value(parameter.swift, true)
        case .generic(let container, let inner):
            let element = try resolve(inner, constructor: constructor, generics: generics)
            switch container {
            case "vector", "Vector": return .vector(element, false)
            case "lengthPrefixedTypedObject", "LengthPrefixedTypedObject":
                guard element.boxed else {
                    throw TLGeneratorError.unsupported("\(constructor.name): lengthPrefixedTypedObject requires a boxed element type")
                }
                return .value("TLLengthPrefixed<\(element.serialType)>", false)
            default: throw TLGeneratorError.unsupported("\(constructor.name): generic container \(container)")
            }
        case .flagged:
            throw TLGeneratorError.invalidFlags("\(constructor.name): flag conditions must wrap an entire field")
        case .repeated:
            throw TLGeneratorError.unsupported("\(constructor.name): repeated fields are supported only by builtin vector and fixed integers")
        }
    }

    private struct ResolvedField {
        let index: Int
        let originalName: String
        let identifier: String
        let resolved: ResolvedType
        let flag: (mask: String, bit: UInt32)?
        let isFlaggedTrue: Bool

        var swiftType: String {
            if isFlaggedTrue { return "Swift.Bool" }
            return resolved.swiftType + (flag == nil ? "" : "?")
        }

        var presenceExpression: String {
            isFlaggedTrue ? "self.\(identifier)" : "self.\(identifier) != nil"
        }
    }

    private func resolvedFields(_ constructor: TLConstructor, generics: [GenericParameter]) throws -> [ResolvedField] {
        var names: Set<String> = []
        return try constructor.fields.enumerated().map { index, field in
            let name = field.name ?? "field\(index)"
            guard isIdentifier(name) else { throw TLGeneratorError.unsupported("\(constructor.name): invalid field identifier \(name)") }
            guard names.insert(name).inserted else { throw TLGeneratorError.swiftNameCollision(name, constructor.name, "field \(index)") }
            let type: TLType
            let flag: (String, UInt32)?
            if case .flagged(let mask, let bit, let inner) = field.type {
                type = inner
                flag = (mask, bit)
            } else {
                type = configuration.replaceWithBytes.contains(constructor.name) && field.type == .named("string") ? .named("bytes") : field.type
                flag = nil
            }
            return ResolvedField(index: index, originalName: name, identifier: escapedIdentifier(name), resolved: try resolve(type, constructor: constructor, generics: generics), flag: flag, isFlaggedTrue: flag != nil && type == .named("true"))
        }
    }

    private struct Mask {
        let unsignedType: String
        let signedType: String?
        let width: UInt32

        func unsignedExpression(_ value: String) -> String {
            signedType == nil ? value : "\(unsignedType)(bitPattern: \(value))"
        }

        func storedExpression(_ value: String) -> String {
            signedType.map { "\($0)(bitPattern: \(value))" } ?? value
        }
    }

    private func flagMasks(_ constructor: TLConstructor, fields: [ResolvedField]) throws -> [Int: Mask] {
        var result: [Int: Mask] = [:]
        for field in fields {
            guard let flag = field.flag else { continue }
            guard let maskField = fields.first(where: { $0.originalName == flag.mask }), maskField.index < field.index, maskField.flag == nil else {
                throw TLGeneratorError.invalidFlags("\(constructor.name).\(field.originalName): mask \(flag.mask) must be declared earlier")
            }
            let mask: Mask
            switch maskField.swiftType {
            case "Swift.UInt8": mask = Mask(unsignedType: "Swift.UInt8", signedType: nil, width: 8)
            case "Swift.UInt32": mask = Mask(unsignedType: "Swift.UInt32", signedType: nil, width: 32)
            case "Swift.UInt64": mask = Mask(unsignedType: "Swift.UInt64", signedType: nil, width: 64)
            case "Swift.Int32": mask = Mask(unsignedType: "Swift.UInt32", signedType: "Swift.Int32", width: 32)
            case "Swift.Int64": mask = Mask(unsignedType: "Swift.UInt64", signedType: "Swift.Int64", width: 64)
            default: throw TLGeneratorError.invalidFlags("\(constructor.name): \(flag.mask) must have an integer type")
            }
            guard flag.bit < mask.width else {
                throw TLGeneratorError.invalidFlags("\(constructor.name): bit \(flag.bit) is outside the \(mask.width)-bit mask \(flag.mask)")
            }
            result[maskField.index] = mask
        }
        return result
    }

    private func constructorName(_ constructor: TLConstructor) -> String {
        constructorNames[constructor.id] ?? baseConstructorName(constructor, structured: false)
    }

    private func baseConstructorName(_ constructor: TLConstructor, structured: Bool) -> String {
        let suffix = constructor.isFunction ? "Request" : "Constructor"
        let base = structured ? structuredName(constructor.name) : pascalCase(constructor.name)
        if (byName[constructor.name]?.count ?? 0) > 1 {
            let result = resultNames[normalizedResultIdentity(constructor.result.schemaName)] ?? pascalCase(constructor.result.schemaName)
            return base + "As" + result + suffix
        }
        return base + suffix
    }

    private func normalizedResultIdentity(_ name: String) -> String {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard let last = parts.last else { return name }
        let prefix = parts.dropLast().map(String.init).joined(separator: ".")
        let leaf = last.prefix(1).lowercased() + last.dropFirst()
        return prefix.isEmpty ? leaf : prefix + "." + leaf
    }

    private func structuredName(_ name: String) -> String {
        name.split(separator: ".", omittingEmptySubsequences: false).map { pascalCase(String($0)) }.joined(separator: "_")
    }

    private func caseIdentifier(_ name: String) -> String {
        let pascal = pascalCase(name)
        return escapedIdentifier(pascal.prefix(1).lowercased() + pascal.dropFirst())
    }

    private func pascalCase(_ name: String) -> String {
        let value = name.split(whereSeparator: { $0 == "." || $0 == "_" }).map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }.joined()
        return value.first?.isNumber == true ? "TL" + value : value
    }

    private func isIdentifier(_ name: String) -> Bool {
        guard let first = name.utf8.first, (first >= 65 && first <= 90) || (first >= 97 && first <= 122) || first == 95 else { return false }
        return name.utf8.dropFirst().allSatisfy { ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 95 }
    }

    private func escapedIdentifier(_ name: String) -> String {
        let keywords: Set<String> = [
            "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init", "inout", "internal", "let", "open", "operator", "private", "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "catch", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch", "throw", "where", "while", "as", "Any", "false", "is", "nil", "self", "Self", "super", "throws", "true", "try", "_"
        ]
        return keywords.contains(name) ? "`\(name)`" : name
    }

    private func literal(_ value: String) -> String { String(reflecting: value) }
    private func hex(_ value: UInt32) -> String { String(format: "%08x", value) }
}
