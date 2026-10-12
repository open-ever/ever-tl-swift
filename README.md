# ever-tl-swift

TL schema parser, Swift code generator, and binary codec for Everscale messages and requests.

- `EverTL`: serialization, deserialization, and dynamic constructor registry.
- `EverTLCodegen`: schema parser and Swift generator API.
- `ever-tl-codegen`: command-line generator.

## Generate Swift types

```tl
// demo.tl
demo.empty = demo.Message;
demo.text id:long text:string = demo.Message;

---functions---
demo.getMessage id:long = demo.Message;
```

```sh
ever-tl-codegen --output DemoSchema.swift demo.tl
```

Include the generated source in your target with an `EverTL` dependency. Constructors become structs, result types become enums, and functions become requests with a typed `Reply`.

```text
ever-tl-codegen [--output FILE] [--config FILE] [--ids] SCHEMA...
```

Input accepts files or directories of `.tl` files. Generate related schemas together: each output declares `EverTLSchema`. Without `--output`, source is written to stdout; `--ids` prints constructor IDs.

## Encode and decode

```swift
import EverTL

let message = DemoMessage.demoText(
    DemoTextConstructor(id: 42, text: "Hello")
)
let bytes = try TLCodec.encode(message)
let decoded = try TLCodec.decode(DemoMessage.self, from: bytes)
```

Encoding and decoding are boxed by default. Pass `boxed: false` for a bare constructor payload.

For dynamic objects, use the generated registry:

```swift
let registry = try EverTLSchema.makeRegistry()
let object = try TLCodec.decode(TLObject.self, from: bytes, registry: registry)
let text = object.cast(to: DemoTextConstructor.self)
```

## Requests

```swift
let request = DemoGetMessageRequest(id: 42)
let requestBytes = try TLCodec.encode(request)

// Send requestBytes through your transport and receive replyBytes.
let reply = try TLCodec.decode(
    DemoGetMessageRequest.Reply.self,
    from: replyBytes,
    boxed: DemoGetMessageRequest.replyBoxed
)
```

## Generator API

```swift
import EverTLCodegen

let schema = try TLParser.parse("demo.text id:long text:string = demo.Message;")
let source = try TLSwiftGenerator.generate(schema: schema)
```

Configuration is available via `TLGeneratorConfiguration` or `--config FILE`: `exclude_types` omits named constructors; `replace_with_bytes` maps their direct `string` fields to `Data`.
