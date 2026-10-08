public indirect enum TLType: Equatable, Sendable {
    case number
    case named(String)
    case typeParameter(String)
    case generic(String, TLType)
    case flagged(String, UInt32, TLType)
    case repeated(UInt32?, [TLField])

    public var schemaName: String {
        switch self {
        case .number:
            return "#"
        case .named(let name), .typeParameter(let name):
            return name
        case .generic(let name, let type):
            return "\(name) \(type.schemaName)"
        case .flagged(let name, let bit, let type):
            return "\(name).\(bit)?\(type.schemaName)"
        case .repeated(let count, let fields):
            let prefix = count.map { "\($0) * " } ?? ""
            return prefix + "[ " + fields.map { $0.schemaText + " " }.joined() + "]"
        }
    }
}

public struct TLField: Equatable, Sendable {
    public let name: String?
    public let type: TLType

    public init(name: String?, type: TLType) {
        self.name = name
        self.type = type
    }

    public var schemaText: String {
        name.map { "\($0):\(type.schemaName)" } ?? type.schemaName
    }
}

public struct TLConstructor: Equatable, Sendable {
    public let name: String
    public let id: UInt32
    public let typeParameters: [TLField]
    public let fields: [TLField]
    public let result: TLType
    public let isFunction: Bool
    public let source: String

    public init(
        name: String,
        id: UInt32,
        typeParameters: [TLField] = [],
        fields: [TLField] = [],
        result: TLType,
        isFunction: Bool = false,
        source: String = ""
    ) {
        self.name = name
        self.id = id
        self.typeParameters = typeParameters
        self.fields = fields
        self.result = result
        self.isFunction = isFunction
        self.source = source
    }
}

public struct TLSchema: Equatable, Sendable {
    public let constructors: [TLConstructor]
    public let layer: UInt32?

    public init(constructors: [TLConstructor], layer: UInt32? = nil) {
        self.constructors = constructors
        self.layer = layer
    }
}
