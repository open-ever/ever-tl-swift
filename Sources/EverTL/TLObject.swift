import Foundation

public struct TLRegistry: Sendable {
    private struct Entry: Sendable {
        let name: String
        let decode: @Sendable (inout TLReader) throws -> TLObject
    }

    private var byID: [UInt32: Entry] = [:]
    private var byName: [String: UInt32] = [:]

    public init() {
        byID[Bool.trueConstructorID] = Entry(name: "boolTrue", decode: { _ in TLObject(true) })
        byID[Bool.falseConstructorID] = Entry(name: "boolFalse", decode: { _ in TLObject(false) })
        byID[TLTrue.constructorID] = Entry(name: "true", decode: { _ in TLObject(TLTrue()) })
        byName["boolTrue"] = Bool.trueConstructorID
        byName["boolFalse"] = Bool.falseConstructorID
        byName["true"] = TLTrue.constructorID
    }

    public var constructorIDs: [UInt32] { byID.keys.sorted() }

    public func name(for id: UInt32) -> String? { byID[id]?.name }
    public func id(named name: String) -> UInt32? { byName[name] }

    public mutating func register<T: TLSerializable>(
        _ type: T.Type,
        id: UInt32,
        name: String
    ) throws {
        guard byID[id] == nil else { throw TLCodecError.duplicateConstructor(id) }
        guard byName[name] == nil else { throw TLCodecError.duplicateName(name) }
        byID[id] = Entry(name: name, decode: { reader in
            TLObject(try reader.read(type, boxed: false), constructorID: id)
        })
        byName[name] = id
    }

    func decode(_ id: UInt32, from reader: inout TLReader) throws -> TLObject {
        guard let entry = byID[id] else { throw TLCodecError.unknownConstructor(id) }
        return try entry.decode(&reader)
    }
}

public struct TLObject: TLFunction, Equatable, Sendable {
    public typealias Reply = TLObject
    public static let replyBoxed = true

    private let value: any TLSerializable
    private let registeredConstructorID: UInt32?
    private let identity: UUID

    public init<T: TLBoxedSerializable>(_ value: T) {
        if let object = value as? TLObject {
            self = object
        } else {
            self.value = value
            registeredConstructorID = nil
            identity = UUID()
        }
    }

    init<T: TLSerializable>(_ value: T, constructorID: UInt32) {
        self.value = value
        registeredConstructorID = constructorID
        identity = UUID()
    }

    public func cast<T: TLSerializable>(to type: T.Type = T.self) -> T? {
        value as? T
    }

    public func constructorID() throws -> UInt32 {
        if let registeredConstructorID { return registeredConstructorID }
        let data = try TLCodec.encode(self)
        var reader = TLReader(data: data)
        return try reader.read(UInt32.self, boxed: false)
    }

    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("bare dynamic Object") }
        let id = try reader.read(UInt32.self, boxed: false)
        let registry = reader.registry
        return try registry.decode(id, from: &reader)
    }

    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("bare dynamic Object") }
        if let registeredConstructorID {
            try writer.write(registeredConstructorID, boxed: false)
            try value.write(to: &writer, boxed: false)
        } else {
            try value.write(to: &writer, boxed: true)
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (try? TLCodec.encode(lhs), try? TLCodec.encode(rhs)) {
        case let (.some(left), .some(right)):
            return left == right
        case (.none, .none):
            return lhs.identity == rhs.identity
        default:
            return false
        }
    }
}
