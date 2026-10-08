# ever-tl-swift

Parse TL schemas and generate Swift types for Everscale TL messages and requests. You provide a `.tl` file; the generator produces ordinary Swift source with constructors, result enums, typed requests, and a constructor registry. Generated code uses the `EverTL` runtime for binary encoding and decoding. No Swift macros are required.

The package provides three products:

| Product | Purpose |
| --- | --- |
| `ever-tl-codegen` | Command-line executable that reads `.tl` files and writes Swift source. |
| `EverTLCodegen` | Parser and generator APIs for generating code from Swift. |
| `EverTL` | Binary codec used by the generated source in your application or library. |

Requires Swift 6.0 or later. The package declares macOS 13 and iOS 13 as its minimum Apple platform versions.

## Generate code from a TL file

Run the following commands from the root of this repository.

1. Save your schema as a `.tl` file. For example, create `demo.tl` with this content:

   ```tl
   demo.empty = demo.Message;
   demo.text id:long text:string = demo.Message;
   demo.options flags:# label:flags.0?string urgent:flags.1?true = demo.Options;

   ---functions---
   demo.getMessage id:long = demo.Message;
   ```

2. Build the generator:

   ```sh
   swift build -c release --product ever-tl-codegen
   ```

3. Pass the schema path to the executable and choose the output file:

   ```sh
   .build/release/ever-tl-codegen --output ./DemoSchema.swift ./demo.tl
   ```

   The last argument is the input TL file. `--output` specifies the generated Swift file. Its parent directory must already exist. Running the command again replaces the generated file, so keep your edits in the schema and regenerate when it changes.

4. Include `DemoSchema.swift` in your application or library target and add the `EverTL` library product to that target's dependencies. The generated file already contains `import EverTL`. Your application only needs `EverTL` unless it also runs the parser or generator itself.

You can also build and run the generator in one command:

```sh
swift run ever-tl-codegen --output ./DemoSchema.swift ./demo.tl
```

All paths are relative to the directory where you run the command; absolute paths also work. Your schemas can live in your own project, wherever you choose. The `.tl` files under this repository's `Tests` directories are test fixtures.

## CLI options

```text
ever-tl-codegen [--output FILE] [--config FILE] [--ids] SCHEMA...
```

Pass several schemas together to generate one Swift file:

```sh
.build/release/ever-tl-codegen --output ./Protocol.swift ./types.tl ./requests.tl
```

You can pass a directory containing `.tl` files instead:

```sh
.build/release/ever-tl-codegen --output ./Protocol.swift ./schemas
```

Directory input reads the immediate `.tl` files in filename order; it does not search subdirectories. Use one generation command for related schemas in the same Swift module: every generated file declares an `EverTLSchema` registry, so generating each schema separately would duplicate that name.

Without `--output`, the executable prints generated Swift source to stdout. Use `--ids` to print constructor names and hexadecimal IDs, or `--help` to display usage:

```sh
.build/release/ever-tl-codegen --ids ./demo.tl
.build/release/ever-tl-codegen --help
```

Explicit IDs such as `demo.text#12345678` are preserved. When an ID is omitted, the parser computes it from the constructor's TL signature.

## Use the generated code

The example schema generates these types:

| TL declaration | Generated Swift type |
| --- | --- |
| `demo.empty` | `DemoEmptyConstructor` |
| `demo.text` | `DemoTextConstructor` with `id: Int64` and `text: String` |
| `demo.Message` | `DemoMessage` enum with `.demoEmpty` and `.demoText` cases |
| `demo.options` | `DemoOptionsConstructor` with a flag mask and optional fields |
| `demo.getMessage` | `DemoGetMessageRequest`, whose `Reply` is `DemoMessage` |

### Encode and decode a message

```swift
import EverTL
import Foundation

let text = DemoTextConstructor(id: 42, text: "Hello")
let message = DemoMessage.demoText(text)

let bytes: Data = try TLCodec.encode(message)
let decoded = try TLCodec.decode(DemoMessage.self, from: bytes)

switch decoded {
case .demoEmpty:
    print("Empty message")
case .demoText(let value):
    print(value.id, value.text)
}
```

A constructor struct represents one specific payload. A result enum represents any constructor returning that TL result type. Use the enum when a message can have several variants.

By default, encoding includes the 32-bit constructor ID (the boxed representation). To encode or decode only a known constructor's fields, use `boxed: false`:

```swift
let payload = try TLCodec.encode(text, boxed: false)
let restored = try TLCodec.decode(DemoTextConstructor.self, from: payload, boxed: false)
```

Result enums require a constructor ID. Generated code automatically chooses the correct representation for fields and vector elements according to their TL types.

### Optional fields and flags

For the example's `demo.options`, `label` becomes `String?`, and `urgent` becomes a `Bool` with no separate payload bytes:

```swift
let options = DemoOptionsConstructor(label: "Preview", urgent: true)
let optionsBytes = try TLCodec.encode(options)
let decodedOptions = try TLCodec.decode(DemoOptionsConstructor.self, from: optionsBytes)
```

The encoder derives the declared flag bits from field values and preserves unknown bits supplied in `flags`. It does not mutate the original struct; decoding exposes the mask actually written. Fields sharing a flag bit must be present together, otherwise encoding throws `TLCodecError.inconsistentFlags`.

### Typed requests and replies

```swift
let request = DemoGetMessageRequest(id: 42)
let requestBytes = try TLCodec.encode(request)

// Send requestBytes through your transport and receive reply bytes.
// This example uses a locally encoded reply.
let replyBytes = try TLCodec.encode(DemoMessage.demoText(text))
let reply = try TLCodec.decode(
    DemoGetMessageRequest.Reply.self,
    from: replyBytes,
    boxed: DemoGetMessageRequest.replyBoxed
)
```

The request type defines serialization and the expected reply type. Your application supplies the network transport, framing, and request/response handling.

### Decode a dynamic object

When the concrete message type is determined by its constructor ID, use the generated registry:

```swift
let registry = try EverTLSchema.makeRegistry()
let object = try TLCodec.decode(TLObject.self, from: bytes, registry: registry)

if let value = object.cast(to: DemoTextConstructor.self) {
    print(value.text)
}
```

Dynamic decoding returns the registered constructor payload. Also pass this registry when decoding generated types containing `Object` or other dynamic object fields. Decoding a known result enum such as `DemoMessage` does not require a registry.

## Generate code from Swift

Use `EverTLCodegen` when generation needs to run inside a Swift tool. Pass the TL text to `TLParser.parse`, then pass the resulting schema to `TLSwiftGenerator.generate`:

```swift
import EverTLCodegen
import Foundation

let tl = try String(contentsOfFile: "demo.tl", encoding: .utf8)
let schema = try TLParser.parse(tl)
let swiftSource = try TLSwiftGenerator.generate(schema: schema)
try swiftSource.write(toFile: "DemoSchema.swift", atomically: true, encoding: .utf8)
```

`parse` accepts a string, so you can also supply TL text directly without creating an input file. The output is Swift source; include and compile it in your target before using its types.

## Optional generator configuration

Defaults work for the example above. To customize generation, save a JSON file such as `codegen.json`:

```json
{
  "exclude_types": [],
  "replace_with_bytes": ["demo.text"]
}
```

```sh
.build/release/ever-tl-codegen --config ./codegen.json --output ./DemoSchema.swift ./demo.tl
```

`exclude_types` contains constructor names to omit. `replace_with_bytes` contains constructor names whose direct `string` fields should become `Data`; in this configuration, `DemoTextConstructor.text` becomes `Data` instead of `String`. Nested vector strings are unaffected.

The same configuration is available through `TLGeneratorConfiguration` when calling `TLSwiftGenerator.generate(schema:configuration:)`.

## Supported schemas

Generation supports numeric primitives, strings, bytes, fixed-width byte values (`int128`, `int256`, `int512`), bare and boxed constructor references, result variants, nested vectors, flag-controlled fields, dynamic objects, length-prefixed objects, and typed requests. Generic query wrappers such as `{X:Type} query:!X = X` are supported for functions.

The parser also recognizes repeated-field syntax, but generating repeated fields or generic data constructors is currently unsupported. Invalid schemas and unsupported generation features throw errors rather than producing a partial output file.

## Tests

```sh
swift test
```

Tests cover parsing, constructor IDs, generated Swift compilation, binary encoding and decoding, flags, vectors, typed requests, and dynamic objects. Synthetic schemas live in `Tests/EverTLCodegenTests/Fixtures` and `Tests/EverTLGeneratedTests/Fixtures`.
