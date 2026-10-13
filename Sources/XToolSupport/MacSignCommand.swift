import ArgumentParser
import Foundation
import PackLib

struct MacSignCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sign", abstract: "Sign a verified macOS build handoff into a new output directory"
    )

    @Argument(help: "Input .app with its unchanged artifact and deferred signing handoff")
    var app: String

    @Option(help: "New output directory; its parent must exist, and existing output is never replaced")
    var output: String

    @Option(help: "Explicit signing mode: ad-hoc, development, or developer-id")
    var mode: String

    @Option(help: "Exact 40-character certificate SHA-1 fingerprint; required for certificate signing")
    var identity: String?

    @Flag(help: "Verify inputs and print the signing plan without modifying files or invoking signing tools")
    var dryRun = false

    func validate() throws {
        guard let mode = MacSigningMode(rawValue: mode) else { throw ValidationError("Unknown Mac signing mode") }
        try MacSigningPlan.validateIdentity(mode: mode, identity: identity)
    }

    func run() async throws {
        guard let mode = MacSigningMode(rawValue: mode) else { throw ValidationError("Unknown Mac signing mode") }
        try await MacSigningOperation.run(bundle: URL(fileURLWithPath: app), output: URL(fileURLWithPath: output),
                                          mode: mode, identity: identity, dryRun: dryRun)
    }
}
