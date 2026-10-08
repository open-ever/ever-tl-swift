import EverTLCodegen
import Foundation

private enum CommandError: Error, CustomStringConvertible {
    case usage(String)

    var description: String {
        switch self { case .usage(let message): return message }
    }
}

private let usage = """
Usage: ever-tl-codegen [--output FILE] [--config FILE] [--ids] SCHEMA...

SCHEMA may be a .tl file or a directory containing .tl files.
Files are processed in the given order; directory entries are sorted.
--output FILE  Write generated Swift source atomically (default: stdout).
--config FILE  Read an ever-tl compatible JSON generator configuration.
--ids          Print constructor names and hexadecimal IDs instead of Swift.
--help         Show this help.
"""

private func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.contains("--help") || arguments.contains("-h") {
        print(usage)
        return
    }

    var output: String?
    var config: String?
    var idsOnly = false
    var paths: [String] = []
    var index = 0
    var optionsEnded = false
    while index < arguments.count {
        let argument = arguments[index]
        if !optionsEnded && (argument == "--output" || argument == "--config") {
            guard index + 1 < arguments.count else {
                throw CommandError.usage("Missing value for \(argument).")
            }
            index += 1
            if argument == "--output" { output = arguments[index] }
            else { config = arguments[index] }
        } else if !optionsEnded && argument == "--ids" {
            idsOnly = true
        } else if !optionsEnded && argument == "--" {
            optionsEnded = true
        } else if !optionsEnded && argument.hasPrefix("-") {
            throw CommandError.usage("Unknown option: \(argument).")
        } else {
            paths.append(argument)
        }
        index += 1
    }
    guard !paths.isEmpty else { throw CommandError.usage(usage) }

    let manager = FileManager.default
    var files: [URL] = []
    for path in paths {
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CommandError.usage("Schema path does not exist: \(path).")
        }
        if isDirectory.boolValue {
            let children = try manager.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
            ).filter {
                $0.pathExtension == "tl" && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard !children.isEmpty else {
                throw CommandError.usage("No .tl files in directory: \(path).")
            }
            files.append(contentsOf: children)
        } else {
            files.append(url)
        }
    }

    var constructors: [EverTLCodegen.TLConstructor] = []
    var layer: UInt32?
    for file in files {
        do {
            let schema = try TLParser.parse(String(contentsOf: file, encoding: .utf8))
            constructors.append(contentsOf: schema.constructors)
            if let value = schema.layer { layer = value }
        } catch {
            throw CommandError.usage("\(file.path): \(error)")
        }
    }

    let content: String
    if idsOnly {
        content = constructors.map { "\($0.name)\t\(String(format: "%08x", $0.id))\n" }.joined()
    } else {
        let configuration: TLGeneratorConfiguration
        if let config {
            configuration = try JSONDecoder().decode(
                TLGeneratorConfiguration.self, from: Data(contentsOf: URL(fileURLWithPath: config))
            )
        } else {
            configuration = .init()
        }
        content = try TLSwiftGenerator.generate(
            schema: TLSchema(constructors: constructors, layer: layer), configuration: configuration
        )
    }
    if let output {
        let outputURL = URL(fileURLWithPath: output).standardizedFileURL
        guard !files.contains(where: { $0.standardizedFileURL == outputURL }) else {
            throw CommandError.usage("Output must not overwrite an input schema.")
        }
        try content.write(to: outputURL, atomically: true, encoding: .utf8)
    } else {
        FileHandle.standardOutput.write(Data(content.utf8))
    }
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("ever-tl-codegen: \(error)\n".utf8))
    exit(1)
}
